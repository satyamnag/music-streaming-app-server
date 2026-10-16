-- ============================================================================
-- 035_partner_credentials_audit_actor.sql
-- ============================================================================
-- Records WHO issued a partner's credentials.
--
-- ---------------------------------------------------------------------------
-- THE DEFECT
-- ---------------------------------------------------------------------------
-- partner_set_credentials writes an audit row that names nobody:
--
--   insert into public.partner_audit_log (partner_id, actor_type, action, detail)
--   values (p_partner_id, 'admin', 'credentials_issued',
--           jsonb_build_object('login_id', v_login, 'bcrypt_cost', v_cost));
--
-- Note the columns: there is no `actor`. And the function has no parameter that
-- could supply one — its signature is
--
--   partner_set_credentials(p_partner_id uuid, p_password text, p_bcrypt_cost integer)
--
-- So `actor` is NULL for every credentials_issued row EVER written, and
-- "which admin issued this password" is unanswerable.
--
-- Observed in production, from partner_audit_log:
--
--   email_attested     actor_type=admin  actor='admin@soulfulbhakti.com'
--   credentials_issued actor_type=admin  actor=NULL          <-- this one
--
-- The attestation is attributable; the credential issuance is not. That matters
-- more, not less: issuing a credential is the action that creates a working login
-- to an account holding someone's government ID documents. An unattributable
-- privileged action is precisely what this table exists to prevent — and
-- partner_attest_email already does it correctly with `left(p_admin, 200)`.
--
-- ---------------------------------------------------------------------------
-- WHY THIS IS A MIGRATION AND NOT A CODE CHANGE
-- ---------------------------------------------------------------------------
-- The identity cannot be supplied by a caller: there is no parameter to pass it
-- through. Both the Express route and the ported web-app route pass exactly
-- (p_partner_id, p_password, p_bcrypt_cost). Adding an argument in the app would
-- fail to resolve the RPC at all, so the signature has to change here first.
--
-- ---------------------------------------------------------------------------
-- THE CHANGE
-- ---------------------------------------------------------------------------
-- Adds `p_admin text` as a TRAILING parameter WITH A DEFAULT of NULL.
--
--   * Trailing + defaulted means existing callers that pass only the original
--     three arguments KEEP WORKING once the old overload is dropped, because
--     PostgreSQL supplies the default.
--   * When p_admin is supplied it is recorded, bounded to 200 characters, which
--     mirrors partner_attest_email exactly.
--   * When it is omitted the row still reads actor=NULL, i.e. the CURRENT
--     behaviour. That is deliberate: this migration must not silently fabricate
--     an actor, and it must not fail a credential issuance that would otherwise
--     succeed. Callers should pass it; until they do, nothing gets worse.
--
-- ============================================================================
-- THE DROP IS LOAD-BEARING — DO NOT REMOVE IT
-- ============================================================================
-- `create or replace function` matches on NAME **AND ARGUMENT TYPES**. Adding
-- p_admin therefore does NOT replace the existing function; it creates a SECOND
-- one alongside it, and a 3-argument call then becomes ambiguous:
--
--     ERROR: function public.partner_set_credentials(uuid, unknown, integer)
--            is not unique
--     HINT:  Could not choose a best candidate function.
--
-- VERIFIED by applying an earlier draft of this migration WITHOUT the drop: two
-- overloads were present, (uuid,text,integer) and (uuid,text,integer,text), and
-- the 3-argument call that BOTH the live Express route and the ported web-app
-- route make failed outright. The deployment would have broken on the next
-- credential issuance.
--
-- So the old 3-argument signature MUST be dropped first. `if exists` keeps it
-- idempotent, and the DROP sits immediately before the CREATE in the same file.
--
-- NOTE the contrast with migration 034: there, dropping would have discarded a
-- working implementation that did not need to change, so it was refused. Here
-- the SIGNATURE itself is the defect, so replacing it is the only correct move.
-- ============================================================================
drop function if exists public.partner_set_credentials(uuid, text, integer);

-- ---------------------------------------------------------------------------
-- SCOPE
-- ---------------------------------------------------------------------------
-- Replaces one function. No table, column, policy or existing audit row is
-- altered. No application code change is required, because the trailing default
-- keeps existing 3-argument calls resolving.
--
-- IDEMPOTENT: on a re-run the drop finds nothing to remove and the create
-- replaces the identical function.
--
-- ---------------------------------------------------------------------------
-- APPLIED AND VERIFIED — 2026-10-16
-- ---------------------------------------------------------------------------
-- Rehearsed in full on a LOCAL database carrying the same 3-argument signature
-- as production, then applied to production inside a single transaction.
--
-- Before:      partner_set_credentials(p_partner_id, p_password, p_bcrypt_cost)
-- After:       partner_set_credentials(p_partner_id, p_password, p_bcrypt_cost, p_admin)
-- Overloads:   0 remnants of the 3-argument form
-- Grants:      postgres + service_role only; anon/authenticated absent
--
-- Behaviour confirmed, each by execution rather than by reading the SQL:
--   * a 3-ARGUMENT call still RESOLVES and reaches the function body. Probed
--     with a deliberately short password so resolution was proven with no side
--     effect: the call returned `password_too_short`, i.e. the function's own
--     verdict, not a resolution error. This is the case that broke before.
--   * a 4-argument call with an identity records it: actor =
--     'admin@soulfulbhakti.com'. THE DEFECT IS FIXED.
--   * a 4-argument call with a BLANK identity records NULL, not whitespace —
--     nullif(trim(...)) doing its job, so a blank cannot masquerade as a name.
--   * guard rails intact: password_too_short / invalid_bcrypt_cost / not_found.
--   * the audit detail contains NO password and NO bcrypt hash (checked by
--     matching '%password%' and '$2a$' across partner_audit_log: 0 rows).
--
-- DATA IMPACT: NONE. Partner rows 4 -> 4 and audit rows 16 -> 16 across the
-- change. The partner with a working login (SB-5VZTRN) kept its password hash,
-- its zero failure count and its unlocked state.
--
-- ROLLBACK, if ever needed — verified to work, not merely written down:
--   drop function if exists public.partner_set_credentials(uuid,text,integer,text);
--   \i _partner-sql/ROLLBACK-035-partner_set_credentials.sql
-- The snapshot is a verbatim pg_get_functiondef() of the pre-migration
-- function, and restoring it was tested end-to-end.
--
-- NOTE ON THE SUPABASE "DESTRUCTIVE OPERATION" WARNING: the DROP below triggers
-- it, correctly — it does remove an object. It removes a FUNCTION DEFINITION,
-- not data: no table, column, policy or audit row is touched, and the
-- replacement carries the same body plus the actor. If you are re-running this
-- by hand in the SQL editor, the warning is expected and is not a reason to
-- stop; confirm the pre-flight signature is 3 arguments first, because if the
-- DROP matches nothing then the CREATE adds a SECOND overload and the
-- 3-argument calls become ambiguous.
-- ============================================================================

create or replace function public.partner_set_credentials(
  p_partner_id uuid,
  p_password text,
  p_bcrypt_cost integer default 10,
  -- WHO is issuing. Trailing + defaulted so existing 3-argument callers keep
  -- resolving; see the header note.
  p_admin text default null
)
returns table (ok boolean, login_id text, reason text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_login text;
  v_cost int;
begin
  -- bcrypt cost bounds. Below 10 is too weak to be worth the bcrypt cost;
  -- above 12 is measurably painful. Measured on this codebase's test
  -- cluster (PG 18.6): cost 10 ~= 363 ms, 11 ~= 827 ms, 12 ~= 2378 ms.
  -- Cost is parameterised rather than hard-coded because those timings are
  -- machine-specific.
  v_cost := coalesce(p_bcrypt_cost, 10);
  if v_cost < 10 or v_cost > 12 then
    return query select false, null::text, 'invalid_bcrypt_cost'::text;
    return;
  end if;

  -- A minimum length is enforced here as well as in the server: the DB is
  -- the last line of defence, and a short password must not be storable.
  if p_password is null or length(p_password) < 16 then
    return query select false, null::text, 'password_too_short'::text;
    return;
  end if;

  if not exists (select 1 from public.partners p where p.id = p_partner_id) then
    return query select false, null::text, 'not_found'::text;
    return;
  end if;

  -- Reuse the partner's existing handle if they already have one, so
  -- re-issuing a password does not silently change their login id.
  select p.login_id into v_login
  from public.partners p where p.id = p_partner_id;

  if v_login is null then
    v_login := public.partner_gen_login_id();
  end if;

  update public.partners p set
    login_id = v_login,
    password_hash = public.sb_crypt(p_password, public.sb_gen_salt('bf', v_cost)),
    must_change_password = true,
    password_set_at = now(),
    password_changed_at = null,
    -- A fresh credential clears any lockout: otherwise an admin reissue
    -- would appear to succeed while the partner stayed locked out.
    failed_login_count = 0,
    locked_until = null,
    updated_at = now()
  where p.id = p_partner_id;

  -- THE FIX: record the acting admin, bounded exactly as partner_attest_email
  -- bounds its own actor. `nullif(trim(...))` turns a blank string into NULL
  -- rather than storing whitespace, which would read as an identity.
  insert into public.partner_audit_log
    (partner_id, actor_type, actor, action, detail)
  values (
    p_partner_id,
    'admin',
    nullif(left(trim(coalesce(p_admin, '')), 200), ''),
    'credentials_issued',
    jsonb_build_object('login_id', v_login, 'bcrypt_cost', v_cost)
  );

  return query select true, v_login, 'ok'::text;
end;
$$;

comment on function public.partner_set_credentials(uuid, text, integer, text) is
  'Issues or re-issues a partner login (login_id + bcrypt hash). p_admin records WHO issued it in partner_audit_log; pass it, or the row reads actor=NULL. service_role only.';

-- Grants are unchanged in substance, but restated so the new 4-argument
-- signature is definitely covered rather than relying on the old 3-argument
-- grant surviving the replace. Revoke precedes grant so a re-run cannot leave a
-- stale PUBLIC grant behind.
revoke all on function public.partner_set_credentials(uuid, text, integer, text)
  from public, anon, authenticated;
grant execute on function public.partner_set_credentials(uuid, text, integer, text)
  to service_role;

-- ============================================================================
-- VERIFY (plain SELECTs; run in any SQL console, including Supabase's)
-- ============================================================================
--
-- Expect ONE row, with 4 arguments and p_admin last.
--
--   select p.proname,
--          pg_get_function_identity_arguments(p.oid) as args,
--          pg_get_function_result(p.oid)             as returns
--     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname = 'public' and p.proname = 'partner_set_credentials';
--
-- Expect the actor to be recorded after issuing with an identity. Use a REAL
-- partner id; this DOES change that partner's password.
--
--   select public.partner_set_credentials(
--     '<partner-uuid>'::uuid, 'A-Long-Enough-Password-2026', 10,
--     'admin@soulfulbhakti.com');
--
--   select action, actor_type, actor, detail, created_at
--     from public.partner_audit_log
--    where action = 'credentials_issued'
--    order by id desc limit 1;
--
-- Expect: actor = 'admin@soulfulbhakti.com'  (not NULL)
--
-- Existing 3-argument calls must still resolve (backwards compatibility):
--
--   select public.partner_set_credentials('<partner-uuid>'::uuid,
--     'Another-Long-Password-2026', 10);
-- ============================================================================
