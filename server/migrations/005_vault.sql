-- ============================================================
-- MIGRATION: Supabase Vault secret access (safe read path)
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- Purpose:
--   Risky credentials (R2 access keys, ADMIN_TOKEN, webhook secrets)
--   are stored in Supabase Vault (encrypted at rest; the project
--   encryption key is held by Supabase, NOT in the database).
--
--   The Express server connects using SUPABASE_SERVICE_KEY (the only
--   bootstrap credential that must remain in the deployment env), then
--   reads the other secrets from the vault through this single RPC.
--
-- Security model:
--   - The function is SECURITY DEFINER: it runs as the owner (postgres)
--     and can read vault.decrypted_secrets.
--   - EXECUTE is granted ONLY to service_role. anon/authenticated (the
--     mobile app keys) can never decrypt vault secrets.
--   - search_path is pinned to `public` to prevent search-path hijacking.
--   - The function accepts a secret NAME and returns the decrypted value.
-- ============================================================

create or replace function public.get_secret(p_name text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_secret text;
begin
  if p_name is null or p_name = '' then
    return null;
  end if;

  select d.decrypted_secret into v_secret
  from vault.decrypted_secrets d
  where d.name = p_name
  limit 1;

  return v_secret;
end;
$$;

-- Only the service role (the trusted backend) may read secrets.
revoke all on function public.get_secret(text) from public;
grant execute on function public.get_secret(text) to service_role;

-- ------------------------------------------------------------------
-- Verify (should return 0 rows: nothing stored yet is fine; this only
-- lists the function)
-- ------------------------------------------------------------------
select proname, prosecdef
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and proname = 'get_secret';
