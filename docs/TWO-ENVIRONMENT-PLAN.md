# Two-Environment Setup — Prod and Dev

**Status: PLAN — awaiting your GitHub URL.**

**Decisions taken:**
- **One repository**, not two.
- Two environments via **branches**: `main` = Prod, `dev` = Dev.
- Hosted on your second GitHub account.
- You create the repo and share the URL. No credentials on this machine.

---

## 1. What "environment" has to mean here

An environment is not just a branch. For this project it means **four things are
duplicated**, and they are not all equally easy:

| Layer | Prod | Dev | Effort |
|---|---|---|---|
| Git branch | `main` | `dev` | trivial |
| Render service | existing | new free service | low |
| Supabase project | existing | new project | low, but needs migration replay |
| Compile-time env (`.env`) | existing | new | low |
| R2 bucket | existing | **shared or new** | decision needed |
| Play Console | production track | internal testing | manual, yours |
| Clerk | existing instance | new or shared | decision needed |
| Domain | `admin.soulfulbhakti.com` | e.g. `dev-admin.…` | DNS |

**The branch is the easy part.** The work is the four external services.

---

## 2. The problem you need to decide on first

**The existing repository is already deployed and working.** Prod is not
hypothetical — it runs the Partner Program, the admin panel, and serves the
Android app's data.

Two consequences:

1. **You cannot simply rename or move it.** The Play Store listing, DNS, Render
   service and Supabase project all point at what exists today.
2. **A second GitHub account means the Render service must be repointed.**
   Render deploys from a GitHub repo. Moving the repo to another account means
   either connecting Render to the new repo, or leaving the old one intact.

So the question is not "how do we split this" but **"which account owns the
future, and what happens to what is running now?"**

### Three viable shapes

**Shape A — New account is the home; old repo is retired.**
- Push full history to `SB Android App` on the new account
- Branches: `main` (Prod), `dev` (Dev)
- Repoint Render, and any CI, to the new repo
- Old repo archived
- *Risk: a brief window where Render, DNS and the repo disagree. Must be sequenced.*

**Shape B — New account hosts Dev only; old repo stays Prod.**
- Old repo keeps serving Prod, untouched. Zero risk to what works.
- New repo on the new account holds `dev`
- A remote called `dev` is added alongside `origin`
- *Downside: two accounts, which is close to what you said you wanted to avoid.*

**Shape C — New repo mirrors both, old repo stays live until cutover.**
- Push everything to the new account; both branches live there
- Prod on Render keeps deploying from the OLD repo until you deliberately switch
- You get time to verify the new setup before anything is at risk
- *Cleanest migration, and my recommendation.*

---

## 3. Proposed branch model

```
main   ──●───────────────●────────────●──►   Prod  (protected; deploys production)
          \             /            /
dev        ●───●───●───●────●───●───●─────►   Dev   (integration; deploys dev)
                \     /
feature/*        ●───●                        short-lived; PR into dev
```

| Branch | Purpose | Deploys to | Protected |
|---|---|---|---|
| `main` | Production | Prod Render service + Prod Supabase | Yes — PR required |
| `dev` | Integration/testing | Dev Render service + Dev Supabase | Yes |
| `feature/*` | Work in progress | nothing | No |

Rules:
- **Nothing is committed directly to `main`.** Prod changes come via PR from `dev`.
- `dev` is where integration happens. Breakage there is expected and harmless.
- Feature branches merge into `dev`, never into `main`.

---

## 4. What has to change in the code

Good news: the codebase is **already environment-agnostic**. It reads all
configuration from environment variables, and the compile-time Flutter config
comes from `.env` via `envied`. That means:

**Almost nothing needs to change.** Specifically:

| Item | Change needed |
|---|---|
| `server/` | **None.** Already reads everything from env / Vault. |
| `lib/` | **None.** Already reads `R2_BASE_URL` etc. at compile time. |
| `.github/workflows/*` | **Small.** Add `dev` to triggers; make the Render health check env-aware. |
| `.env` | A `dev` variant must be produced. |
| `android-release.yml` | Already supports a `channel` input — verify `dev` is handled. |

**The `keep-alive.yml` workflow is a real issue.** It hard-codes:

```yaml
curl https://music-streaming-app-server.onrender.com/health
```

That is **the Prod URL**. On the `dev` branch it would keep Prod warm and leave
Dev asleep. It must become branch-aware or parameterised.

---

## 5. Sequencing (nothing breaks)

1. **You** create the empty repo on the second account.
2. **I** push the full history from this repo to it, preserving all commits.
3. **I** create the `dev` branch and make the workflow changes described above.
4. **You** create the Dev Supabase project and Dev Render service.
5. **You** apply `server/migrations/*.sql` to the Dev Supabase project.
6. **You** set secrets on both Render services (`PARTNER_KEK`, SMTP, etc.).
7. **You** point Render's Prod service at the new repo — *or* leave it on the old
   one until you are satisfied. This is the only step that touches Prod.
8. **I** verify both environments independently.

Steps 1, 4, 5, 6 and 7 need your credentials. Steps 2, 3 and 8 are mine.

---

## 6. R2 and Clerk: decide before building Dev

**R2 (audio storage).** Options:
- **Share the prod bucket** — Dev reads the same audio. Simple, no extra cost,
  but a Dev bug could damage production objects.
- **Separate bucket** — full isolation, more setup, and you must copy test audio.

Recommendation: **separate bucket**, because the admin panel can delete objects,
and a Dev mistake should not be able to remove production music.

**Clerk (authentication).** Options:
- **Share the instance** — Dev signs in the same users. Less setup; test accounts
  are real accounts.
- **Separate instance** — isolation; more config.

Recommendation: **share for now**, since Clerk is only used for admin login and
the app's sign-in. Revisit if Dev needs to simulate users Prod does not have.

---

## 7. What I need from you

To begin, only this:

```
New GitHub repo URL:  https://github.com/<account>/<repo>
```

Then, when you are ready for Dev to actually run:

```
Dev Supabase URL:
Dev Supabase service key:   (set it on Render — do not send it to me)
Dev Render service URL:
```

**Do not send me tokens or keys.** I can do the git work without them; you set
the secrets directly in Render and Supabase.

---

## 8. Open questions

1. **Which account owns the future?** Shape A, B or C from §2.
2. **Repo name** — you said "SB Android App Prod / Dev" as environment names.
   For a single repo, one name is needed. Suggest **`SB-Android-App`**, with
   Prod and Dev as *environments*, not repo names.
3. **Is Prod allowed a maintenance window?** Step 7 needs one, however brief.
4. **Does the Android app need to talk to Dev at all?** If not, Dev is a
   web/admin-only environment and the app's `.env` never points at it.
