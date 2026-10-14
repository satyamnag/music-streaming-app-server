# Environments — Prod and Dev

This repository hosts **two environments** from **one codebase**, separated by
branch. The code is identical; only configuration differs.

| Branch | Environment | Purpose |
|---|---|---|
| `main` | **Prod** | Live. Serves the app and the partner program. |
| `dev` | **Dev** | Integration and testing. Breakage here is expected and harmless. |

---

## The rule

```
feature/* ──PR──► dev ──PR──► main
                  │            │
                  ▼            ▼
                Dev env      Prod env
```

- **Nothing is committed directly to `main`.** Prod changes arrive by pull
  request from `dev`.
- **`dev` is where integration happens.** Feature branches merge into `dev`,
  never straight into `main`.
- **`main` must always be deployable.** If it is broken, Prod is broken.

---

## What actually differs between the environments

The codebase is environment-agnostic by design: the server reads every setting
from environment variables (or Supabase Vault), and the Flutter app reads its
compile-time config from `.env` via `envied`. **No source change is needed to
run either environment.** What differs is configuration and the services behind
it:

| Layer | Prod | Dev |
|---|---|---|
| Render service | production service | separate free service |
| Supabase project | production project | separate project |
| Compile-time `.env` | production values | development values |
| R2 bucket | production bucket | separate bucket *(recommended)* |
| Clerk instance | production | shared *(until isolation is needed)* |
| Public URL | `admin.soulfulbhakti.com` | dev host or the Render URL |

---

## Required repository settings

### Variables

Set under **Settings → Secrets and variables → Actions → Variables**:

| Variable | Purpose |
|---|---|
| `RENDER_HEALTH_URL` | The `/health` URL the keep-alive workflow pings. **Per environment** — if this points at Prod from the `dev` branch, Prod is kept warm and Dev sleeps. |

### Secrets

Set under **Settings → Secrets and variables → Actions**:

| Secret | Purpose |
|---|---|
| `KEYSTORE` | base64 release keystore |
| `KEY_PROPERTIES` | contents of `android/key.properties` |
| `DOTENV_RELEASE` | compile-time `.env` for the **Prod** build |

> **Dev must not use the Prod keystore or the Prod `.env`.** If Dev builds with
> production secrets, a dev APK can read and write production data. Use a
> separate keystore — or none, since debug builds generate an ephemeral one.

### Branch protection (recommended)

Protect **both** branches:

- `main`: require a pull request, require the `Lint` check to pass, disallow
  force-push and deletion.
- `dev`: require the `Lint` check. Direct pushes may be allowed if that suits
  your workflow.

---

## Secrets that must NOT be shared between environments

| Secret | Why |
|---|---|
| Supabase service key | It bypasses RLS entirely. A Dev key that opens Prod is a data-loss path. |
| `PARTNER_KEK` | **Losing this makes every uploaded document permanently unreadable.** Use a different key per environment so a Dev mistake cannot affect Prod documents. |
| SMTP credentials | Use a separate sender, or accept that Dev sends real email. |
| Release keystore | The Prod keystore signs what ships to Play. |

---

## Running the Dev environment

1. Create the Dev Supabase project.
2. Apply every migration in `server/migrations/` **in order**. Note that these
   were written for manual application via the SQL Editor, not `supabase db push`.
3. Create the Dev Render service, pointing it at the `dev` branch.
4. Set the Dev service's environment variables — including a **Dev-specific**
   `PARTNER_KEK`.
5. Set the `RENDER_HEALTH_URL` variable for the Dev environment.

The partner program's own setup is documented in
[`docs/partner-program/README.md`](docs/partner-program/README.md).

---

## Notes on the migration to this repository

Full history was pushed from the previous repository, so `git log` remains
intact. Both `main` and `dev` currently point at the same commit; they will
diverge from the first Dev-only change.

**Production is still deploying from the old repository.** Nothing here changes
that until Render's service is deliberately repointed. That is intentional:
Prod keeps running from a known-good source while Dev is brought up and
verified.
