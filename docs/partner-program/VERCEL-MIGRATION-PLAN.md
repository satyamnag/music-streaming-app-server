# Migration Plan — consolidate the web surface onto Vercel

**Status: PLAN — not yet executed.**
**Objective:** one hosting provider (Vercel) for the web app, admin panel, partner portal and their APIs. Decommission Render.

---

## 1. Corrected facts (verified, not assumed)

| Thing | Actually is | Verified by |
|---|---|---|
| Web app | **Vercel** (Cloudflare proxies it) | `x-vercel-id`, `x-vercel-cache`, `x-powered-by: Next.js` on a live response |
| Admin + partner portal | **Render** (`216.24.57.16`) | DNS + `Server: cloudflare` on `admin.` |
| Audio files (opus) | **Cloudflare R2**, served via `music.soulfulbhakti.com` | `R2_BASE_URL` in the app's `.env` |
| Database / auth / storage | **Supabase** | app + server both connect directly |

> My first reading of the DNS was wrong. `soulfulbhakti.com` resolves to Cloudflare
> edge addresses because Cloudflare **proxies** Vercel. The origin is Vercel.

## 2. The finding that shapes everything

**The Android app has ZERO dependency on the Render server.**

Verified by searching the entire Flutter codebase for the Render host and its API
paths — no matches. Instead:

- the app runs its **own local shelf server** (`lib/provider/server/`), and
- talks to **Supabase directly** (`sb.from(...)`, `sb.rpc(...)`), and
- builds audio URLs itself from `R2_BASE_URL` → `https://music.soulfulbhakti.com/...`

**Consequence: moving or briefly breaking the Render server cannot break the
Android app.** The blast radius of this migration is the web admin panel and the
partner portal only. That is what makes this migration safe to attempt at all,
and it is the single most important fact in this document.

## 3. What has to be solved

### 3.1 The hard blocker — 110 MB uploads

The admin uploads audio up to **110 MB** (`multer`, `fileSize: 110 * 1024 * 1024`)
buffered entirely in memory. Vercel caps request bodies at roughly **4.5 MB**.
This is a platform limit, not a setting.

**Solution (agreed): presigned direct-to-R2 uploads.** The browser PUTs the file
straight to R2 using a short-lived presigned URL; the server never touches the
bytes. This removes the limit entirely, cuts Render/Vercel egress, and is the
standard pattern for large objects on serverless.

Five call sites in `admin.html` use `FormData` → `/api/admin/upload`. All five
must change.

### 3.2 Audio streaming with Range

`/stream/:id/file` and `/api/admin/audio/file` fetch the whole object from R2
into a Buffer, then serve ranges from memory.

**Good news:** this is a plain request/response, not a long-lived stream, so it
runs on Vercel. The concern is **memory**: a full track buffered per request.

**Mitigation:** stream the R2 object body through rather than buffering, using
the Web Streams API (`ReadableStream`), and head the object first to satisfy
Range requests without loading it. Must be measured, not assumed.

### 3.3 Bundling the HTML

`admin.html` (237 KB) and `partner.html` (54 KB) are read with `fs.readFileSync`
and `__dirname`. On Vercel these must be declared as function includes
(`functions.includeFiles`) or imported as strings, or they 404 in production
while working perfectly in local dev.

### 3.4 Runtime characteristics

| Concern | Status |
|---|---|
| Local disk writes | **None** — portable |
| In-memory sessions | **None** — HMAC cookie, stateless |
| `setInterval` / background work | **None** |
| Node APIs used | `crypto`, `fs.readFileSync`, `path` — all supported |
| Webhook raw-body handling | `express.raw` before `express.json` — must be preserved exactly |

That last row matters: the Superwall webhook verifies an HMAC over the **exact
raw bytes**. Any body parsing change breaks commission crediting silently.

## 4. Phasing

Each phase is independently verifiable and independently revertible. **Render
keeps serving production until Phase 4.**

### Phase 1 — Presigned uploads (no hosting change)
1. Add `POST /api/admin/uploads/presign` returning a short-lived presigned PUT.
2. Add `POST /api/admin/uploads/complete` so the server records the object key.
3. Update all five `admin.html` call sites to PUT directly to R2, then call complete.
4. Keep `/api/admin/upload` in place during transition.
5. **Verify on Render** — uploads work identically, files land in R2.

*Why first:* it is the highest-risk code, and doing it while Render is still
production means a failure is trivial to roll back.

### Phase 2 — Vercel entrypoint (additive, not deployed to production)
1. Add `api/server.js` in the web app repo exporting the Express app as a
   Vercel function, with `includeFiles` for the two HTML files.
2. Add a `vercel.json` rewriting the admin host paths to that function.
3. Deploy to a **preview URL only**. Production untouched.
4. **Verify** the whole route inventory against the preview URL with the same
   test harness used for the partner pipeline.

*Why second:* the function can be proven before any DNS moves.

### Phase 3 — Full verification on preview
Run against the preview deployment:
- the 11-step partner pipeline (131 DB assertions, 29 real-DB HTTP tests)
- admin login, session, and every `/api/admin/*` route
- the Superwall webhook with a correctly signed payload
- audio Range requests (206 + `Content-Range`) including seek behaviour
- a real admin upload through the presigned path
- the R2 cover proxy and Google translate/transliterate routes
- the partner portal end to end, including document encryption round-trip

**Gate: no phase-4 cutover until every one of these passes.**

### Phase 4 — Cutover and decommission
1. Add `admin.soulfulbhakti.com` to the Vercel project.
2. Lower DNS TTL **24 h in advance** to make rollback fast.
3. Repoint DNS to Vercel.
4. **Keep Render running, untouched, for at least a week** as hot rollback.
5. Watch error rates, then decommission Render.

## 5. Risk register

| Risk | Severity | Mitigation |
|---|---|---|
| Uploads break | **High** | Presigned path proven on Render in Phase 1 first |
| Audio Range/seek breaks | **High** | Explicit 206 + byte-identity tests, manual seek test |
| Superwall webhook HMAC breaks → lost commissions | **High** | Raw-body test with a real signed payload; keep Render alive |
| HTML 404s in production | Medium | `includeFiles` + a production smoke test on the preview URL |
| Function memory limit on large tracks | Medium | Stream from R2 instead of buffering; measure with real sizes |
| Cold starts on admin login | Low | Acceptable; admin is low-traffic |
| Google Translate routes time out | Low | Verify; these are quick API calls |

## 6. Rollback

Every phase is revertible:
- **Phase 1:** revert the commit; `/api/admin/upload` is untouched throughout
- **Phase 2–3:** nothing in production changed
- **Phase 4:** repoint DNS back to Render; the service stays warm for a week

## 7. Open questions that need answers before Phase 1

1. **Largest real upload size?** Determines whether streaming is strictly
   required or buffering is tolerable.
2. **Vercel plan and function limits** (memory, max duration). The Hobby plan's
   limits may force the streaming approach regardless.
3. **Is Render on a paid plan?** Free-tier spin-down may already be causing the
   reliability problems that motivated this.
4. **Does anything else call Render?** The Android app does not (verified), but
   Play Console, a cron job, or an uptime monitor might.

## 8. What is NOT proposed

- **No changes to the Android app.** It does not depend on Render.
- **No changes to the database.** Supabase is untouched.
- **No changes to R2 object layout.** Existing keys keep working.
- **No big-bang cutover.** Render serves production until Phase 4.

---

## Recommendation

Phase 1 is worth doing **regardless of whether this migration proceeds**: presigned
uploads are better on any platform, and they remove a 110 MB in-memory buffer that
is a latent OOM risk on Render today.

I suggest starting there, verifying it on Render, and only then deciding on the
hosting move with real evidence about upload behaviour.
