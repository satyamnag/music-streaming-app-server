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
| `superwall/api-key` | **holds an `sk_` secret key (len 67)** — wrong type for an SDK key |
| `superwall/publishable-key` | **missing** — the `pk_…` key is not stored anywhere in AWS |

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