# Running the admin server on Vercel (optional, in progress)

Status: **code is ready; the Vercel project is not created yet.** Render keeps
serving production in the meantime, unchanged.

## What was changed

`server.js` was split so the same code can run on a long-lived host and as a
serverless function:

| File | Role |
| --- | --- |
| `server/app.js` | Builds the Express app and exports it. Also exports `bootstrap()` (the Vault/AWS secret loads and the Clerk / R2 / Razorpay initialisation) and `startupSummary()`. Holds all 117 routes. |
| `server/server.js` | The long-lived entrypoint (Render today). `bootstrap()`, then `app.listen(PORT)`. Log lines and `global.__SERVER_PORT` unchanged, so the integration tests still work. |
| `server/api/index.js` | The serverless entrypoint. `bootstrap()`, then `app(req, res)` per request. |
| `server/vercel.json` | Sends every path to `api/index.js` and bundles `admin.html` + `partner.html`. |

`bootstrap()` is memoised, so a cold start pays for the secret loads once and a
failed bootstrap is retried rather than latched.

`serveAdminHtml` / `servePartnerHtml` now resolve their file through
`resolveStaticFile()`, which checks the module directory, the working directory
and `<cwd>/server`. On Render the first candidate always wins, so behaviour is
identical; on Vercel it survives a different bundle layout.

## Verified

* Both entrypoints, against real routes: `/api/admin/session` 200, `/admin` and
  `/partner` serve their pages, `/api/admin/tracks` 401, login sets the cookie,
  `/api/admin/trending/tracks` 401 — on Render (`server.js`) **and** through the
  Vercel handler (`api/index.js`), 14/14 checks.
* Repo suites, unmodified in behaviour: `trending-order` 12/12,
  `auto-sync-endpoint` 20/20, `admin-filters` 25/25, `auto-sync-admin-ui` 15/15.
  (`auto-sync-endpoint` read its source assertions from `server.js`; they now
  read whichever file holds the routes, so a future move cannot fake a pass.)

## Known limits that a Vercel deployment inherits

1. **Request bodies are capped at 4.5 MB by Vercel.** `POST /api/admin/upload`
   allows 110 MB (`multer` cap in `app.js`) and partner KYC documents allow
   5 MB (`MAX_DOC_BYTES`). A 3–5 min `.opus` is usually under the cap; longer or
   higher-bitrate files fail with 413 before any code runs. Fix: sign a presigned
   PUT (R2) and upload from the browser so the bytes never touch a function.
2. **Function duration.** `POST /api/admin/tracks/:id/auto-sync` waits on a
   Deepgram transcription. `sync-from-srt` already dispatches a GitHub Actions
   job and returns immediately — auto-sync needs the same treatment.
3. **Rate limiting.** `express-rate-limit` uses the default in-memory store, so
   the 10-attempts/15-minutes admin login guard becomes per-instance. Point it at
   Upstash Redis (`UPSTASH_REDIS_REST_URL` / `_TOKEN` are already in `.env.example`).

## Creating the project (only the account owner can do this)

1. Vercel → **Add New → Project** → import `satyamnag/music-streaming-app-server`.
2. **Root Directory: `server`.** Vercel then builds only that folder; the Flutter
   app is ignored.
3. Framework preset: **Other**. No build command; output is a single function.
4. Environment variables — the bootstrap pair is mandatory, the rest mirror the
   Render environment:
   `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, `ADMIN_TOKEN` (or keep relying on
   Vault/AWS, accepting a Vault/AWS round trip per cold start), `CLERK_SECRET_KEY`,
   `CLERK_PUBLISHABLE_KEY`, `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`,
   `R2_SECRET_ACCESS_KEY`, `R2_BASE_URL`, `DEEPGRAM_API_KEY`,
   `GITHUB_ACTIONS_TOKEN`, `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`,
   `RAZORPAY_WEBHOOK_SECRET`, `RAZORPAY_MODE`, `UPSTASH_REDIS_REST_URL`,
   `UPSTASH_REDIS_REST_TOKEN`, `PARTNER_KEK`, `PARTNER_IP_SALT`,
   `OPENAI_SECOND_OPINION`, `AWS_SECRETS_ENABLED`, `AWS_REGION`.
5. Deploy, then test on the `*.vercel.app` URL **before** touching DNS:
   `/admin` renders, sign-in works with the current token,
   `GET /api/admin/tracks` returns rows, saving one track's `synced_lyrics`
   round-trips, one small `.webp` thumbnail upload succeeds, `/partner` loads.
6. Cut over: point the `admin.soulfulbhakti.com` CNAME from Render to Vercel.
   Keep the Render service running (and its env intact) until the Vercel
   deployment has served a full week without an error.

## Rollback

The DNS record is the only switch. Point it back at Render; nothing in this
change alters the Render deployment, and `server.js` there behaves exactly as
before.
