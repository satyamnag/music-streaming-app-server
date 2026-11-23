# Running the admin server on Vercel (optional, in progress)

Status: **production is live on Vercel** (`admin.soulfulbhakti.com`), built from
this repository's `main` branch.

## ⛔ Root Directory MUST be `server` — never change it

The Vercel project (`soulfulbhakti-admin`) must have **Root Directory =
`server`**. This is the single setting that fails *silently* when it is wrong:

* `vercel.json` + `api/index.js` exist **only** under `server/`. No commit has
  ever had a root-level copy.
* With Root Directory = repository root, Vercel still reports the build as
  **READY** — but it contains **zero functions**. Every route 404s, and
  production keeps serving the *previous* deployment. Nothing else alerts you.
* This is exactly what happened on 2026-11-23: a day of server fixes
  (Superwall Webhooks V2, Play entitlement sync) sat on `main` while the live
  site ran a three-day-old build. "Redeploy" does not help — it rebuilds the
  same old commit with the same wrong root.

**Detect** (one request, no credentials):

```bash
curl -s https://admin.soulfulbhakti.com/health/auth
```

The response must contain `"superwallSync":{...}`. If that key is missing, the
build is not the current `server/` build.

**Repair** (dashboard): Project → Settings → Build & Deployment → **Root
Directory → `server`** → Save → Deployments → *Redeploy* (or push any commit).

**Repair** (API, if you hold a token with project access):

```bash
curl -s -X PATCH \
  "https://api.vercel.com/v9/projects/prj_FVuGu3AMO7kuENA1aEUesk4dmxdS?slug=famerelay" \
  -H "Authorization: Bearer $VERCEL_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"rootDirectory":"server"}'
```

`.github/workflows/vercel-deploy-guard.yml` re-checks this every six hours and on
every push to `main`, and fails loudly if production stops serving the current
build — so a silent regression is caught within minutes instead of days.

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
4. Environment variables — see the complete list below, extracted from the code
   rather than from memory. **You must paste these in the Vercel dashboard**:
   they are the one thing this repository cannot supply, because
   `SUPABASE_SERVICE_KEY` exists only in the Render environment (AWS Secrets
   Manager holds `supabase/url` and `supabase/anon-key`, never the service key).
5. Deploy, then test on the `*.vercel.app` URL **before** touching DNS:
   `node server/tools/vercel-smoke.mjs https://<project>.vercel.app`
   That script asserts the panel renders, both HTML pages serve, the admin and
   partner APIs are guarded, and the login route rejects a wrong token. It needs
   no credentials and writes nothing. 14/14 against production is the expected
   result.
6. Cut over: point the `admin.soulfulbhakti.com` CNAME from Render to Vercel.
   Keep the Render service running (and its env intact) until the Vercel
   deployment has served a full week without an error.

## Environment variables the server actually reads

Extracted from `app.js`, `partner_routes.mjs` and `libs/awsSecrets.mjs` — 37
distinct names. Nothing outside this list is read.

**Mandatory (the deployment is non-functional without them):**

```
SUPABASE_URL              the project URL
SUPABASE_SERVICE_KEY      the service role key — bootstrap credential; also what
                          lets the server read Supabase Vault. Present ONLY in
                          the Render environment, not in AWS Secrets Manager.
ADMIN_TOKEN               or leave unset and rely on Vault/AWS `admin_token`
```

**Required for the features that use them:**

```
CLERK_SECRET_KEY  CLERK_PUBLISHABLE_KEY  CLERK_AUTHORIZED_PARTIES
R2_ACCOUNT_ID  R2_ACCESS_KEY_ID  R2_SECRET_ACCESS_KEY  R2_BASE_URL  R2_BUCKET_NAME
DEEPGRAM_API_KEY  DEEPGRAM_API_URL  GITHUB_ACTIONS_TOKEN  GOOGLE_TRANSLATE_API_KEY
OPENAI_API_KEY  OPENAI_SECOND_OPINION
RAZORPAY_MODE  RAZORPAY_KEY_ID  RAZORPAY_KEY_SECRET  RAZORPAY_WEBHOOK_SECRET
RAZORPAY_KEY_ID_TEST  RAZORPAY_KEY_SECRET_TEST  RAZORPAY_WEBHOOK_SECRET_TEST
RAZORPAY_PLAN_MONTHLY  RAZORPAY_PLAN_YEARLY  RAZORPAY_PLAN_YEARLY_TEST
SUPERWALL_WEBHOOK_SECRET  SUPERWALL_ALLOW_SANDBOX
PARTNER_KEK  PARTNER_IP_SALT  PARTNER_PUBLIC_BASE_URL  PARTNER_BRAND_NAME
PARTNER_CONSENT_VERSION  PARTNER_ADMIN_ALERT_EMAIL
AWS_SECRETS_ENABLED  AWS_REGION
AUTOSYNC_ALLOW_INTERPOLATED
```

Two notes that matter on Vercel specifically:

* `SUPABASE_SERVICE_KEY` and `ADMIN_TOKEN` set as project environment variables
  make every cold start cheap. If you leave them unset and rely on Vault/AWS, a
  cold start pays for a Vault read per secret, and `AWS_SECRETS_ENABLED=1` also
  needs AWS credentials in the project — which is a worse place to keep them than
  Render's environment.
* `PARTNER_IP_SALT` falls back to `ADMIN_TOKEN`. Set it explicitly so rotating
  the admin token does not change the partner audit-log IP hashes.

## Rollback

The DNS record is the only switch. Point it back at Render; nothing in this
change alters the Render deployment, and `server.js` there behaves exactly as
before.
