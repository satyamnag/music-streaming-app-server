-- ============================================================================
-- 034_partner_document_access_log.sql
-- ============================================================================
-- Brings the REPOSITORY in line with PRODUCTION for
-- public.partner_log_document_access.
--
-- ---------------------------------------------------------------------------
-- READ THIS FIRST: THE HISTORY OF THIS FILE, BECAUSE IT EXPLAINS ITS SHAPE
-- ---------------------------------------------------------------------------
-- An earlier version of this migration was WRONG and would have broken a
-- working production function. It was written on the belief that the function
-- did not exist anywhere, because it is absent from every migration in this
-- repository. That belief was mistaken. The function DOES exist in production;
-- it was applied out-of-band and never committed, so the repository and the
-- live database had silently drifted.
--
-- Applying the earlier version produced, in production:
--
--     ERROR: 42P13: cannot change return type of existing function
--     HINT:  Use DROP FUNCTION partner_log_document_access(...) first.
--
-- That error was the drift surfacing. The live function is a REAL, WORKING
-- implementation: it returns void, inserts into partner_audit_log with
-- actor_type='admin', and strips control characters from the user agent against
-- log injection. It was never broken, and document-access auditing was never a
-- no-op. The earlier file's claim to the contrary was false.
--
-- So this file no longer INVENTS a function. It REPRODUCES the live one, so a
-- database built from this repository ends up with the function production
-- already has. That is a sync, not a redesign.
--
-- ---------------------------------------------------------------------------
-- THE CONTRACT, TAKEN FROM PRODUCTION
-- ---------------------------------------------------------------------------
--   returns void                 NOT a table. The caller reads only `error`,
--                                never `data`, so a fire-and-forget write is
--                                the correct shape — the original Express code
--                                was right and needed no change.
--   p_action  text               NO DEFAULT
--   p_result  text               NO DEFAULT
--   p_reason  text DEFAULT NULL
--   p_ip_hash text DEFAULT NULL
--   p_user_agent text DEFAULT NULL
--
-- The action value written is 'document.access'.
--
-- The TypeScript port passes all eight arguments by name, so it satisfies both
-- this signature and the no-default parameters. The bug was never in a caller.
--
-- ---------------------------------------------------------------------------
-- DEPLOYING THIS AGAINST PRODUCTION IS A NO-OP, AND THAT IS THE POINT
-- ---------------------------------------------------------------------------
-- The CREATE OR REPLACE below is equivalent to the live definition: same return
-- type, same parameter list, same defaults, same body. It therefore does not
-- raise 42P13 and does not change behaviour. Against a database built from this
-- repository it CREATES the function; against production it replaces it with an
-- identical one. Either way the two converge.
--
-- ---------------------------------------------------------------------------
-- WHY THERE IS NO DROP
-- ---------------------------------------------------------------------------
-- The obvious "fix" for 42P13 is to DROP first — that is what the HINT suggests.
-- It is the wrong move here:
--
--   * A DROP would discard a working, OWASP-conscious implementation in favour
--     of one written from a description, because the DROP only exists to clear
--     the way for MY design. There is no reason to prefer my design; the live
--     one is already in service.
--   * DROP + CREATE is not atomic with respect to concurrent callers. Between
--     the two statements the function does not exist, and an audit write landing
--     in that window would fail. For an audit path that is the wrong risk to
--     take in order to change a return type nobody needs changed.
--   * pg_depend showed no dependents, so a DROP would succeed — which is
--     precisely why the decision must be about intent rather than feasibility.
--
-- Because this file reproduces the live shape, no DROP is needed.
--
-- ---------------------------------------------------------------------------
-- SCOPE
-- ---------------------------------------------------------------------------
-- Additive and idempotent. Creates the function if absent, replaces it with an
-- equivalent definition if present. No table, column, policy or existing row is
-- altered. No application code changes.
-- ============================================================================

create or replace function public.partner_log_document_access(
  p_partner_id uuid,
  p_document_id uuid,
  p_admin text,
  p_action text,
  p_result text,
  p_reason text default null,
  p_ip_hash text default null,
  p_user_agent text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $function$
begin
  insert into public.partner_audit_log
    (partner_id, actor_type, actor, action, detail, ip_hash, user_agent)
  values (
    p_partner_id, 'admin', p_admin, coalesce(p_action, 'document.access'),
    jsonb_build_object(
      'document_id', p_document_id,
      'result', coalesce(p_result, 'unknown'),
      'reason', p_reason
    ),
    p_ip_hash,
    -- Bound and strip control characters: OWASP warns that logged data
    -- must be sanitised to prevent log injection.
    left(regexp_replace(coalesce(p_user_agent, ''), '[[:cntrl:]]', '', 'g'), 300)
  );
end;
$function$;

comment on function public.partner_log_document_access(uuid, uuid, text, text, text, text, text, text) is
  'Append-only record of an admin accessing a partner KYC document. Stores ids, outcome and reason only — never document content or PII. service_role only.';

-- ---------------------------------------------------------------------------
-- GRANTS — the ONE deliberate change this file makes relative to production
-- ---------------------------------------------------------------------------
-- The function is SECURITY DEFINER, so it runs with the owner's privileges and
-- bypasses RLS on the audit table. That makes EXECUTE the security boundary:
-- whoever may call it may append rows to an append-only log, choosing their own
-- actor string, and those rows can never afterwards be edited or deleted. The
-- anon and authenticated roles must not be able to do that.
--
-- The live function's ACL was reported as the DEFAULT, which for a function
-- means EXECUTE is granted to PUBLIC. If that is accurate this is a real
-- tightening; if EXECUTE was in fact already restricted, this block changes
-- nothing and is harmless, because it revokes privileges that were not held and
-- re-grants service_role what it already had.
--
-- `revoke` precedes `grant` so a re-run cannot leave a stale PUBLIC grant.
-- ---------------------------------------------------------------------------
revoke all on function public.partner_log_document_access(uuid, uuid, text, text, text, text, text, text)
  from public, anon, authenticated;
grant execute on function public.partner_log_document_access(uuid, uuid, text, text, text, text, text, text)
  to service_role;

-- ============================================================================
-- VERIFY (plain SELECTs; run them in any SQL console, including Supabase's)
-- ============================================================================
--
-- Expect returns = void and this exact parameter list.
--
--   select p.proname,
--          pg_get_function_identity_arguments(p.oid) as identity_args,
--          pg_get_function_result(p.oid)             as returns
--     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname = 'public' and p.proname = 'partner_log_document_access';
--
-- Expect anon = false, authenticated = false, service_role = true.
--
--   select r.rolname,
--          has_function_privilege(
--            r.rolname,
--            'public.partner_log_document_access(uuid,uuid,text,text,text,text,text,text)',
--            'EXECUTE') as can_execute
--     from pg_roles r
--    where r.rolname in ('anon','authenticated','service_role')
--    order by r.rolname;
--
-- Expect one new 'document.access' row naming the acting admin.
--
--   select public.partner_log_document_access(
--     '<partner-uuid>'::uuid, '<doc-uuid>'::uuid, 'reviewer@soulfulbhakti.com',
--     'document.access', 'success', null, 'iphash', 'agent');
--   select id, actor, action, detail, created_at
--     from public.partner_audit_log
--    where action = 'document.access' order by id desc limit 1;
--
-- Expect BOTH to RAISE 'partner_audit_log is append-only'.
--
--   update public.partner_audit_log set action='tampered' where action='document.access';
--   delete from public.partner_audit_log where action='document.access';
-- ============================================================================
