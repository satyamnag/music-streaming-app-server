# Where the API keys live, and the order they are read in

The server needs a handful of credentials at boot: Deepgram, OpenAI, R2, Clerk,
Superwall webhook secret, the partner KEK, the admin token, Google Translate.

They are resolved from three sources, in this order:

```
AWS Secrets Manager   →   Supabase Vault   →   process.env   →   (absent = fail closed)
```

A later source is used **only** for names an earlier source did not supply, so a
successful AWS read always wins and a failed one is invisible to the caller.

Code: `server/server.js` (`loadSecretsFromVault`, `loadSecretsFromAws`,
`VAULT_SECRET_KEYS`, `secrets`), `server/libs/awsSecrets.mjs`.
Tests: `server/test/aws-secrets.test.mjs`.

---

## 1. AWS Secrets Manager (optional, off by default)

Enabled only by `AWS_SECRETS_ENABLED=1`. With it unset the module is never imported
and startup is byte-identical to the Vault-only behaviour.

| Variable | Purpose |
|---|---|
| `AWS_SECRETS_ENABLED=1` | turns the AWS source on |
| `AWS_REGION` | `ap-south-1` (falls back to `AWS_DEFAULT_REGION`, then `ap-south-1`) |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | least-privilege principal, `secretsmanager:GetSecretValue` on the specific ARNs only |

### Naming convention

Secrets in the account are named `<service>/<key>`:
`superwall/api-key`, `onesignal/api-key`, `posthog/api-key`,
`clerk/publishable-key`, `r2/base-url`, `supabase/url`, `deepgram/api-key`,
`openai/api-key`.

The server's **internal** names are unchanged, so nothing else in the codebase had
to move. Only the lookup name is translated, by an explicit map in
`libs/awsSecrets.mjs`:

```
deepgram_api_key  → deepgram/api-key
openai_api_key    → openai/api-key
```

Names with no override are looked up verbatim. Those that do not exist in AWS return
`ResourceNotFoundException`, which is expected and harmless: the Vault value stays in
place.

### Fail-closed behaviour

- 3 s timeout **per name**; one slow secret cannot stall boot.
- Per-name isolation: a denied or missing secret does not stop the others.
- A missing SDK, `AccessDenied`, `ResourceNotFound` or a timeout all log a short
  reason and continue. **Boot never fails because AWS is unreachable.**
- Secret **values** are never logged — only names and error codes.

## 2. Supabase Vault

Read once at startup through `public.get_secret(name)`, a `SECURITY DEFINER`
function granted to `service_role` only (migration `005_vault.sql`). The mobile
app's `anon`/`authenticated` keys can never decrypt it.

The single bootstrap credential that must remain in the deployment env is
`SUPABASE_SERVICE_KEY`, because it is what connects to the Vault.

## 3. Environment variables

Per-name fallbacks for local development. A Vault or AWS value always wins.

---

## Verifying what actually happened

At boot the log names each source, for example:

```
[secrets] deepgram_api_key loaded from vault
[secrets] openai_api_key loaded from aws (ap-south-1, openai/api-key)
[secrets] aws read failed for r2_account_id: ResourceNotFoundException
```

Independently, CloudTrail records every `GetSecretValue` call with the caller, the
secret name and any error code — which is how a deployment was confirmed to be
reading the two key names above.

## Rotating a key

1. Put the new value in AWS (`put-secret-value`) or the Vault.
2. Restart the service so the loader re-reads at boot.

Rotating in **both** stores is unnecessary once AWS is enabled — AWS wins — but
remove the stale copy afterwards so only one source of truth remains.

## Least-privilege policy for the runtime principal

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "secretsmanager:GetSecretValue",
    "Resource": [
      "arn:aws:secretsmanager:<region>:<account>:secret:deepgram/api-key-XXXXXX",
      "arn:aws:secretsmanager:<region>:<account>:secret:openai/api-key-XXXXXX"
    ]
  }]
}
```

Do **not** run the service as an administrator identity. AdministratorAccess is for
provisioning; the runtime credential should be able to read exactly these ARNs and
nothing else.

---

## Verified operational facts (2026-11-09)

These were confirmed with live calls against the account, not from documentation.

### Access

| Fact | Value |
|---|---|
| Working profile | **`famerelay`** (`~/.aws/credentials`), region **ap-south-1** |
| Broken profile | **`default`** holds an invalid key — every call fails with `UnrecognizedClientException`. Never rely on it |
| Permissions used | `secretsmanager:ListSecrets`, `secretsmanager:GetSecretValue` |

Always pass the profile explicitly:

```bash
AWS_PROFILE=famerelay AWS_REGION=ap-south-1 node _probe.mjs
```

### What exists in the account (19 secrets)

```
clerk/publishable-key        onesignal/api-key           supabase/anon-key
deepgram/api-key             onesignal/rest-api-key      supabase/url
hide-donations               openai/api-key              superwall/api-key
posthog/api-key              r2/base-url                 release/channel
update-check/enabled         tutrtalk/prod/* (6 secrets, unrelated project)
```

### Gaps that block the Razorpay rail

| Secret | State |
|---|---|
| `razorpay/key-secret` | **missing** (`ResourceNotFoundException`) |
| `razorpay/webhook-secret` | **missing** (`ResourceNotFoundException`) |
| `superwall/api-key` | **re-created 2026-11-13** - read-only `sk_...` key (len 67, readback verified). Used ONLY by the audit tooling (`server/tools/check-paid-user.mjs`) to read the dashboard; it is NOT shipped in the app. The app keeps `superwall/publishable-key` (pk_) |
| `superwall/publishable-key` | ✅ **created 2026-11-09** — `pk_` prefix, len 24, readback verified; `.env` now reads it |

Consequence: the app cannot initialise Superwall (secret key where `pk_` is expected),
and a secret credential is inside the APK. Rotate the `sk_`, add
`superwall/publishable-key`, then add the two Razorpay secrets.

### The app cannot read Secrets Manager — build-time injection instead

A mobile binary calling Secrets Manager would need AWS keys inside the APK, which is
strictly worse. The compliant pattern: **CI reads the publishable keys from Secrets
Manager, writes them into the build's `.env`, and compiles** —
`clerk/publishable-key`, `superwall/publishable-key`, `supabase/anon-key`,
`onesignal/api-key`, `posthog/api-key`. Secrets never enter the APK; publishable keys
never sit in the repository.

### Re-verify in one command

```bash
cd server
AWS_PROFILE=famerelay AWS_REGION=ap-south-1 node -e "
import('./libs/awsSecrets.mjs').then(async (m) => {
  const { SecretsManagerClient, GetSecretValueCommand } = await import('@aws-sdk/client-secrets-manager');
  const client = new SecretsManagerClient({ region: 'ap-south-1' });
  const r = await m.loadAwsSecrets({
    names: ['razorpay/key-secret','razorpay/webhook-secret'],
    client, GetSecretValueCommand,
  });
  console.log('loaded:', r.loaded, 'failed:', r.failed.map(f => f.name + ':' + f.reason));
});"
```

`loaded` listing both names is the proof the rail is wired.
### State after the Superwall cleanup (2026-11-09)

- The organization `sk_` key was **revoked** in the Superwall dashboard and its AWS copy
  (`superwall/api-key`) **deleted** (`ForceDeleteWithoutRecovery`). Only
  `superwall/publishable-key` remains for Superwall.
- `superwall/publishable-key` holds the **Android** public key (`pk_`, len 24). The local
  `.env` was switched to it and verified byte-identical on readback.
- The iOS public key is a **different** value — Android builds must use the Android one.
- Still outstanding for the web rail: `razorpay/key-secret`, `razorpay/webhook-secret`.
### The app's build-time path, verified (2026-11-09)

The Android app **never** calls Secrets Manager at runtime — it cannot without shipping
AWS keys. Its keys are **compiled in** by `envied` from `.env`, and that `.env` is
produced by `android-release.yml` from AWS Secrets Manager first, DOTENV_RELEASE second.

Simulating the release job's eleven lookups against the real account (`AWS_PROFILE=famerelay`):

| Secret | Result |
|---|---|
| `supabase/url` | OK (40) |
| `supabase/anon-key` | OK (208) |
| `clerk/publishable-key` | OK (40) |
| `r2/base-url` | OK (31) |
| `release/channel` | OK (6) |
| `update-check/enabled` | OK (1) |
| `hide-donations` | OK (1) |
| `superwall/publishable-key` | OK (24) |
| `onesignal/api-key` | OK (36) |
| `posthog/api-key` | OK (48) |
| `posthog/host` | ✅ created 2026-11-09 — `https://us.i.posthog.com` (US cloud) |

11 of 11 come from AWS. `posthog/host` falls back to DOTENV_RELEASE (and the app defaults
to `https://us.i.posthog.com` in `env.dart`). Create `posthog/host` to close it.

**Fixed in the workflow the same day:** it still asked for `superwall/api-key`, which had
been deleted during the rotation — that would have dropped `SUPERWALL_API_KEY` from every
build and let the DOTENV fallback re-inject the old value. The mapping now reads
`superwall/publishable-key`, and the "Verify required .env keys" step refuses to ship
unless `SUPERWALL_API_KEY` starts with `pk_`.

**Still outside AWS:** `API_BASE_URL` (the Node API host used by the entitlement check) is
not fetched from Secrets Manager — it arrives via DOTENV_RELEASE. It is not a credential,
but if the rule is to be absolute, create `api-base-url` and add the mapping.

**Not provable from here:** an actual GitHub Actions run. The YAML parses and every AWS
lookup above was executed for real; the job itself must be observed in Actions.
### Razorpay credentials — verified against the live API (2026-11-09)

| Item | Value | Evidence |
|---|---|---|
| Key ID (public, Render env) | `rzp_live_TxzrGybeVepASY` | `GET /v1/plans` returned 200 with it |
| Key secret (AWS) | `razorpay/key-secret`, len 24 | authenticates with that key ID — **same mode confirmed** |
| Plan (Render env) | `plan_Ty0WSKxH35Rfuo` | 12000 paise, INR, period yearly, interval 1 |
| Webhook secret (AWS) | `razorpay/webhook-secret`, len 64 | identical to the value registered in the Razorpay webhook form |

Render env still required: `RAZORPAY_KEY_ID=rzp_live_TxzrGybeVepASY`,
`RAZORPAY_PLAN_YEARLY=plan_Ty0WSKxH35Rfuo`, `AWS_SECRETS_ENABLED=1`,
`AWS_REGION=ap-south-1`, plus the `famerelay` access key pair.

**This is LIVE mode.** There has been no successful test-mode purchase, so the
payment path (signature → row → entitlement → app unlock) is still unproven
end-to-end. A test-mode plan and key pair exist separately and cost nothing;
use them for the rehearsal before a real customer pays.
---

## Reading the Superwall dashboard (audit path)

Added 2026-11-13. The read-only key lives at **`superwall/api-key`** (AWS, `famerelay`,
`ap-south-1`). Read it in-process; never print it, never put it in `.env`.

```powershell
$key = aws secretsmanager get-secret-value --profile famerelay --region ap-south-1 `
  --secret-id "superwall/api-key" --query SecretString --output text
```

Verified identifiers (from `GET /v2/projects`):

| Thing | Value |
|---|---|
| Organization | `26125` |
| Project `Soulful Bhakti` | `28422` |
| Application `Soulful Bhakti` (android, `com.soulfulbhakti.app`) | `52776` |

What the key can and cannot do:

| Endpoint | Use |
|---|---|
| `GET /v2/projects` | resolve project/app ids |
| `GET /v2/users/{id}/subscription-summary?application_id=52776` | **the paid/free answer**: `has_active_subscription`, products, store, expiry |
| `GET /v2/users/{id}/active-entitlements?application_id=52776` | active entitlements |
| `GET /v3/users/{id}/subscriptions?application_id=52776` | the subscription records themselves |
| `GET /v2/projects/28422/applications/52776/recent-transactions?environment=PRODUCTION&from=..&to=..&event_type=all` | every purchase event (**`event_type` must be `all`** — the default subscription-only view returns nothing for this app) |
| `POST /v2/users/query` | user attributes (`total`, rows); **not** subscription state |
| `GET /v2/organizations/26125/query/*` | **403** with this key - the warehouse SQL API needs a different scope |

Helper that wraps the per-user calls:

```bash
SUPERWALL_API_KEY=$(aws secretsmanager get-secret-value --profile famerelay \
  --region ap-south-1 --secret-id superwall/api-key --query SecretString --output text) \
  node server/tools/check-paid-user.mjs user_xxx
```

Rotate this key in Superwall -> Settings -> API keys when it is no longer needed.