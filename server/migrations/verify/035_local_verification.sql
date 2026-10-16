-- ============================================================================
-- VERIFY 035 in a database that has the real partner schema.
-- Read/write, but ONLY against a local test DB. Never run against production:
-- section B and C change a partner's password.
-- ============================================================================

\echo '--- 0. pick a partner ---'
select id, coalesce(login_id, '<none>') as login_id, coalesce(email,'<none>') as email
  from public.partners order by created_at limit 3;

\echo ''
\echo '--- A. LEGACY 3-ARG CALL must still resolve (backwards compatibility) ---'
select 'A: 3-arg' as test, ok, login_id, reason
  from public.partner_set_credentials(
    (select id from public.partners order by created_at limit 1),
    'Legacy-Three-Arg-Password-2026', 10);

\echo ''
\echo '--- B. 4-ARG call with an admin identity must RECORD the actor ---'
select 'B: 4-arg with admin' as test, ok, login_id, reason
  from public.partner_set_credentials(
    (select id from public.partners order by created_at limit 1),
    'With-Admin-Identity-Password-2026', 10, 'admin@soulfulbhakti.com');

\echo ''
\echo '--- C. 4-arg with a BLANK admin must read NULL, not whitespace ---'
select 'C: blank admin' as test, ok, login_id, reason
  from public.partner_set_credentials(
    (select id from public.partners order by created_at limit 1),
    'Blank-Admin-Identity-Password-26', 10, '   ');

\echo ''
\echo '--- D. the audit rows just written ---'
select id, action, actor_type,
       coalesce(actor, '<NULL>') as actor,
       detail
  from public.partner_audit_log
 where action = 'credentials_issued'
 order by id desc limit 4;

\echo ''
\echo '--- E. the password must NOT appear anywhere in the audit detail ---'
select count(*) as rows_leaking_a_password
  from public.partner_audit_log
 where detail::text ilike '%password%'
    or detail::text ilike '%$2a$%'
    or detail::text ilike '%bcrypt_pw%';

\echo ''
\echo '--- F. guard rails still enforced ---'
select 'too short' as test, ok, reason
  from public.partner_set_credentials(
    (select id from public.partners order by created_at limit 1), 'short', 10, 'a@b.com');
select 'bad cost' as test, ok, reason
  from public.partner_set_credentials(
    (select id from public.partners order by created_at limit 1),
    'A-Perfectly-Fine-Long-Password', 99, 'a@b.com');
select 'unknown partner' as test, ok, reason
  from public.partner_set_credentials(
    '00000000-0000-0000-0000-000000000000'::uuid,
    'A-Perfectly-Fine-Long-Password', 10, 'a@b.com');

\echo ''
\echo '--- G. grants: service_role only, never anon/authenticated ---'
select g.grantee, g.privilege_type
  from information_schema.routine_privileges g
  join information_schema.routines r on r.specific_name = g.specific_name
 where r.routine_name = 'partner_set_credentials'
 order by 1;
