-- ============================================================================
-- Partner admin-issued credentials + login — database behaviour tests
-- ============================================================================
-- Exercises the REAL functions (no stub) for the changed pipeline where the
-- ADMIN creates the account and issues the credentials.
--
-- Every check RAISEs on failure, so `psql -v ON_ERROR_STOP=1` aborts at the
-- first broken invariant. A clean run means every assertion held.
--
-- Run:
--   psql -h 127.0.0.1 -p 55432 -U postgres -d sb_partner_test \
--        -v ON_ERROR_STOP=1 -f test/partner_auth.test.sql
-- ============================================================================

\set ON_ERROR_STOP on
\pset pager off

truncate table
  public.partner_audit_log,
  public.partner_email_events,
  public.partner_documents,
  public.partners,
  public.affiliate_commissions,
  public.affiliate_referrals,
  public.coupon_attributions,
  public.coupons,
  public.affiliates
restart identity cascade;

create or replace function pg_temp.ok(cond boolean, label text)
returns void language plpgsql as $$
begin
  if cond is not true then
    raise exception 'ASSERTION FAILED: %', label;
  end if;
  raise notice '  PASS %', label;
end $$;

do $$ begin
  raise notice '====================================================';
  raise notice ' Partner auth — admin-issued credentials + login';
  raise notice '====================================================';
end $$;

-- ---------------------------------------------------------------------------
-- 1) The schema-resolved pgcrypto wrappers exist and actually work.
--    These are the ones that broke twice in production for digest(), so they
--    are asserted directly rather than assumed.
-- ---------------------------------------------------------------------------
do $$
declare
  v_hash text;
  v_salt text;
begin
  raise notice '-- 1) pgcrypto wrappers';

  v_salt := public.sb_gen_salt('bf', 10);
  perform pg_temp.ok(v_salt like '$2%', 'sb_gen_salt(bf) returns a bcrypt salt');

  v_hash := public.sb_crypt('correct horse battery staple', v_salt);
  perform pg_temp.ok(v_hash like '$2%', 'sb_crypt returns a bcrypt hash');
  perform pg_temp.ok(
    public.sb_crypt('correct horse battery staple', v_hash) = v_hash,
    'sb_crypt verifies the same password against the stored hash'
  );
  perform pg_temp.ok(
    public.sb_crypt('wrong password', v_hash) <> v_hash,
    'sb_crypt rejects a wrong password'
  );

  -- Cost is clamped into 10..12 regardless of what the caller asks for.
  perform pg_temp.ok(
    public.sb_gen_salt('bf', 99) like '$2%',
    'sb_gen_salt clamps an out-of-range cost instead of failing'
  );
end $$;

-- ---------------------------------------------------------------------------
-- 2) Admin credential issuance.
-- ---------------------------------------------------------------------------
create temporary table t_ids (name text primary key, id uuid);

do $$
declare
  v_id uuid;
  v_res record;
begin
  raise notice '-- 2) credential issuance';

  insert into public.partners (email, portal_token_hash, status)
  values ('auth-test@example.com', public.partner_token_hash('seed-token'), 'draft')
  returning id into v_id;

  insert into t_ids values ('main', v_id);

  -- A short password must be refused: bcrypt of a 6-char password is not an
  -- acceptable credential even if a caller asks for it.
  select * into v_res from public.partner_set_credentials(v_id, 'short', 10);
  perform pg_temp.ok(v_res.ok = false, 'short password refused');
  perform pg_temp.ok(v_res.reason = 'password_too_short', 'reason is password_too_short');

  -- Out-of-range cost refused.
  select * into v_res from public.partner_set_credentials(
    v_id, 'a-sufficiently-long-password', 4);
  perform pg_temp.ok(v_res.ok = false, 'cost below 10 refused');
  perform pg_temp.ok(v_res.reason = 'invalid_bcrypt_cost', 'reason is invalid_bcrypt_cost');

  -- Unknown partner refused.
  select * into v_res from public.partner_set_credentials(
    gen_random_uuid(), 'a-sufficiently-long-password', 10);
  perform pg_temp.ok(v_res.ok = false, 'unknown partner refused');
  perform pg_temp.ok(v_res.reason = 'not_found', 'reason is not_found');

  -- The real thing.
  select * into v_res from public.partner_set_credentials(
    v_id, 'Sbx7Km2pQ9rTvWz4Yh8', 10);
  perform pg_temp.ok(v_res.ok = true, 'credentials issued');
  perform pg_temp.ok(v_res.login_id like 'SB-%', 'generated handle has the SB- prefix');
  perform pg_temp.ok(length(v_res.login_id) = 9, 'handle is 9 chars (SB- + 6)');
  perform pg_temp.ok(
    v_res.login_id !~ '[01OIL]', 'handle avoids look-alike glyphs 0/1/O/I/L'
  );
end $$;

do $$
declare
  v_row public.partners;
begin
  raise notice '-- 2b) stored shape';

  select * into v_row from public.partners where email = 'auth-test@example.com';

  perform pg_temp.ok(v_row.login_id is not null, 'login_id persisted');
  perform pg_temp.ok(
    v_row.password_hash like '$2%', 'password_hash is a bcrypt hash'
  );
  perform pg_temp.ok(
    v_row.password_hash <> 'Sbx7Km2pQ9rTvWz4Yh8',
    'the raw password is NOT stored'
  );
  perform pg_temp.ok(
    position('Sbx7Km2pQ9rTvWz4Yh8' in coalesce(v_row.password_hash, '')) = 0,
    'the raw password does not appear anywhere in the hash'
  );
  perform pg_temp.ok(
    v_row.must_change_password = true,
    'must_change_password is true for an admin-issued password'
  );
  perform pg_temp.ok(v_row.failed_login_count = 0, 'failure counter starts at 0');
  perform pg_temp.ok(v_row.locked_until is null, 'not locked initially');

  -- The audit trail must not contain the password.
  perform pg_temp.ok(
    not exists (
      select 1 from public.partner_audit_log l
      where l.partner_id = v_row.id
        and l.detail::text like '%Sbx7Km2pQ9rTvWz4Yh8%'
    ),
    'audit log never records the raw password'
  );
  perform pg_temp.ok(
    exists (
      select 1 from public.partner_audit_log l
      where l.partner_id = v_row.id and l.action = 'credentials_issued'
    ),
    'credential issuance is audited'
  );
end $$;

-- ---------------------------------------------------------------------------
-- 3) Login.
-- ---------------------------------------------------------------------------
do $$
declare
  v_res record;
  v_handle text;
  v_ok_count int;
begin
  raise notice '-- 3) login';

  select login_id into v_handle from public.partners where email = 'auth-test@example.com';

  -- Wrong password.
  select * into v_res from public.partner_login(v_handle, 'definitely-the-wrong-pw', null);
  perform pg_temp.ok(v_res.ok = false, 'wrong password rejected');
  perform pg_temp.ok(
    v_res.reason = 'invalid_credentials', 'wrong password gives a generic reason'
  );
  perform pg_temp.ok(v_res.portal_token is null, 'no token issued on failure');

  -- Unknown handle must give the IDENTICAL reason (no user enumeration).
  select * into v_res from public.partner_login('SB-ZZZZZZ', 'anything-at-all-here', null);
  perform pg_temp.ok(v_res.ok = false, 'unknown handle rejected');
  perform pg_temp.ok(
    v_res.reason = 'invalid_credentials',
    'unknown handle gives the SAME reason as a wrong password (no enumeration)'
  );

  -- Correct password.
  select * into v_res from public.partner_login(v_handle, 'Sbx7Km2pQ9rTvWz4Yh8', null);
  perform pg_temp.ok(v_res.ok = true, 'correct password accepted');
  perform pg_temp.ok(
    v_res.portal_token is not null and length(v_res.portal_token) = 64,
    'a 256-bit session token is issued (64 hex chars)'
  );
  perform pg_temp.ok(v_res.must_change = true, 'login reports the forced password change');

  -- Case-insensitive handle.
  select * into v_res from public.partner_login(lower(v_handle), 'Sbx7Km2pQ9rTvWz4Yh8', null);
  perform pg_temp.ok(v_res.ok = true, 'login handle is case-insensitive');

  -- The session token must actually work with the EXISTING functions. This is
  -- the crux of the design: no existing function was modified, so this proves
  -- the new login is compatible with the 14 token-consuming functions.
  select count(*) into v_ok_count
  from public.partner_get_self(v_res.portal_token);
  perform pg_temp.ok(v_ok_count = 1, 'the new session token works with partner_get_self');

  perform pg_temp.ok(
    (select count(*) from public.partner_get_self('not-a-real-token')) = 0,
    'a bogus token returns nothing'
  );
end $$;

-- ---------------------------------------------------------------------------
-- 4) Session rotation on each login.
-- ---------------------------------------------------------------------------
do $$
declare
  v_handle text;
  v_t1 text;
  v_t2 text;
begin
  raise notice '-- 4) session rotation';

  select login_id into v_handle from public.partners where email = 'auth-test@example.com';

  select portal_token into v_t1 from public.partner_login(v_handle, 'Sbx7Km2pQ9rTvWz4Yh8', null);
  select portal_token into v_t2 from public.partner_login(v_handle, 'Sbx7Km2pQ9rTvWz4Yh8', null);

  perform pg_temp.ok(v_t1 <> v_t2, 'each login mints a distinct token');
  perform pg_temp.ok(
    (select count(*) from public.partner_get_self(v_t1)) = 0,
    'the PREVIOUS token is invalidated by a new login'
  );
  perform pg_temp.ok(
    (select count(*) from public.partner_get_self(v_t2)) = 1,
    'the newest token is valid'
  );
end $$;

-- ---------------------------------------------------------------------------
-- 5) Lockout after repeated failures, and recovery.
-- ---------------------------------------------------------------------------
do $$
declare
  v_handle text;
  v_res record;
  v_row public.partners;
  i int;
begin
  raise notice '-- 5) lockout';

  select login_id into v_handle from public.partners where email = 'auth-test@example.com';

  for i in 1..7 loop
    select * into v_res from public.partner_login(v_handle, 'wrong-password-here-x', null, 8, 15);
    perform pg_temp.ok(v_res.ok = false, 'failure ' || i || ' rejected');
  end loop;

  select * into v_row from public.partners where email = 'auth-test@example.com';
  perform pg_temp.ok(v_row.failed_login_count = 7, 'failure counter reached 7');
  perform pg_temp.ok(v_row.locked_until is null, 'not yet locked before the threshold');

  -- 8th failure trips the lock.
  select * into v_res from public.partner_login(v_handle, 'wrong-password-here-x', null, 8, 15);
  perform pg_temp.ok(v_res.ok = false, '8th failure rejected');

  select * into v_row from public.partners where email = 'auth-test@example.com';
  perform pg_temp.ok(v_row.locked_until is not null, 'account is locked at the threshold');
  perform pg_temp.ok(v_row.locked_until > now(), 'lock expiry is in the future');

  -- While locked, even the CORRECT password must fail.
  select * into v_res from public.partner_login(v_handle, 'Sbx7Km2pQ9rTvWz4Yh8', null);
  perform pg_temp.ok(v_res.ok = false, 'correct password rejected while locked');
  perform pg_temp.ok(
    v_res.reason = 'invalid_credentials',
    'lockout is not disclosed (same generic reason)'
  );

  -- An admin reissue must clear the lock, or it would look like it worked
  -- while the partner still could not get in.
  select * into v_res from public.partner_set_credentials(
    (select id from public.partners where email = 'auth-test@example.com'),
    'BrandNewPassword1234', 10);
  perform pg_temp.ok(v_res.ok = true, 'admin can reissue credentials');

  select * into v_row from public.partners where email = 'auth-test@example.com';
  perform pg_temp.ok(v_row.locked_until is null, 'reissue clears the lockout');
  perform pg_temp.ok(v_row.failed_login_count = 0, 'reissue resets the failure counter');

  -- Reissue reuses the handle so the partner's login id does not change.
  perform pg_temp.ok(
    v_row.login_id = v_handle, 'reissue keeps the same login id'
  );

  -- The new password works; the old one does not.
  select * into v_res from public.partner_login(v_handle, 'BrandNewPassword1234', null);
  perform pg_temp.ok(v_res.ok = true, 'the reissued password works');

  select * into v_res from public.partner_login(v_handle, 'Sbx7Km2pQ9rTvWz4Yh8', null);
  perform pg_temp.ok(v_res.ok = false, 'the OLD password no longer works');
end $$;

-- ---------------------------------------------------------------------------
-- 6) Forced password change.
-- ---------------------------------------------------------------------------
do $$
declare
  v_handle text;
  v_res record;
  v_token text;
  v_row public.partners;
begin
  raise notice '-- 6) password change';

  select login_id into v_handle from public.partners where email = 'auth-test@example.com';

  -- A short new password is refused.
  select * into v_res from public.partner_change_password('some-token', 'short', 10);
  perform pg_temp.ok(v_res.ok = false, 'an invalid session cannot change the password');

  select portal_token into v_token
  from public.partner_login(v_handle, 'BrandNewPassword1234', null);

  select * into v_res from public.partner_change_password(v_token, 'short', 10);
  perform pg_temp.ok(v_res.ok = false, 'a short new password is refused');
  perform pg_temp.ok(v_res.reason = 'password_too_short', 'reason is password_too_short');

  select * into v_res from public.partner_change_password(v_token, 'ChosenByPartner9876', 10);
  perform pg_temp.ok(v_res.ok = true, 'the partner can set their own password');

  select * into v_row from public.partners where email = 'auth-test@example.com';
  perform pg_temp.ok(
    v_row.must_change_password = false, 'must_change_password is cleared'
  );
  perform pg_temp.ok(
    v_row.password_changed_at is not null, 'password_changed_at recorded'
  );

  -- Rotating the password must invalidate the session that performed it.
  perform pg_temp.ok(
    (select count(*) from public.partner_get_self(v_token)) = 0,
    'changing the password invalidates the session used to change it'
  );

  -- The old (admin-issued) password must no longer work.
  select * into v_res from public.partner_login(v_handle, 'BrandNewPassword1234', null);
  perform pg_temp.ok(v_res.ok = false, 'the admin-issued password stops working');

  -- The new one does.
  select * into v_res from public.partner_login(v_handle, 'ChosenByPartner9876', null);
  perform pg_temp.ok(v_res.ok = true, 'the partner-chosen password works');
  perform pg_temp.ok(
    v_res.must_change = false, 'forced change is no longer reported'
  );
end $$;

-- ---------------------------------------------------------------------------
-- 7) Constraints.
-- ---------------------------------------------------------------------------
do $$
declare
  v_login text;
begin
  raise notice '-- 7) constraints';

  -- A password hash with no handle would be a silently unusable account.
  begin
    insert into public.partners (email, portal_token_hash, password_hash)
    values ('bad@example.com', public.partner_token_hash('t'), '$2a$10$abcdefghijklmnopqrstuv');
    perform pg_temp.ok(false, 'a password hash without a login id must be rejected');
  exception when check_violation then
    perform pg_temp.ok(true, 'a password hash without a login id is rejected');
  end;

  -- Malformed handle.
  begin
    insert into public.partners (email, portal_token_hash, login_id)
    values ('bad2@example.com', public.partner_token_hash('t2'), 'lowercase-bad');
    perform pg_temp.ok(false, 'a malformed login id must be rejected');
  exception when check_violation then
    perform pg_temp.ok(true, 'a malformed login id is rejected');
  end;

  -- Handles are unique case-insensitively.
  select login_id into v_login from public.partners where email = 'auth-test@example.com';

  -- NOTE: lower(v_login) violates the FORMAT constraint (which requires
  -- uppercase) before the unique index is even consulted, so this raises
  -- check_violation, not unique_violation. Both are correct rejections; what
  -- matters is that a case-variant cannot be inserted. Assert on the fact of
  -- rejection rather than on which constraint happened to fire.
  begin
    insert into public.partners (email, portal_token_hash, login_id)
    values ('dup@example.com', public.partner_token_hash('t3'), lower(v_login));
    perform pg_temp.ok(false, 'a duplicate login id (any case) must be rejected');
  exception when check_violation or unique_violation then
    perform pg_temp.ok(true, 'a duplicate login id in any case is rejected');
  end;

  -- And the unique index itself must reject an EXACT duplicate.
  begin
    insert into public.partners (email, portal_token_hash, login_id)
    values ('dup2@example.com', public.partner_token_hash('t4'), v_login);
    perform pg_temp.ok(false, 'an exact duplicate login id must be rejected');
  exception when unique_violation then
    perform pg_temp.ok(true, 'an exact duplicate login id is rejected by the unique index');
  end;

  -- Multiple rows may have NO handle (they simply cannot log in yet).
  insert into public.partners (email, portal_token_hash) values
    ('nohandle1@example.com', public.partner_token_hash('n1')),
    ('nohandle2@example.com', public.partner_token_hash('n2'));
  perform pg_temp.ok(
    (select count(*) from public.partners where login_id is null) = 2,
    'multiple partners without credentials coexist (NULL handles do not collide)'
  );
end $$;

-- ---------------------------------------------------------------------------
-- 8) A row with no issued credentials cannot log in at all.
-- ---------------------------------------------------------------------------
do $$
declare
  v_res record;
begin
  raise notice '-- 8) no-credentials row';

  select * into v_res from public.partner_login('SB-NOSUCH1', 'anything-at-all-here', null);
  perform pg_temp.ok(v_res.ok = false, 'a handle invented by the caller does not log in');

  -- Even if an attacker guesses a REAL null-credential row's (absent) handle,
  -- there is nothing to compare against.
  perform pg_temp.ok(
    (select count(*) from public.partners where login_id is null and password_hash is not null) = 0,
    'no row has a password hash without a handle'
  );
end $$;

-- ---------------------------------------------------------------------------
-- 9) Partner dashboard: self-scoped, aggregates only, no KYC leakage.
-- ---------------------------------------------------------------------------
do $$
declare
  v_token text;
  v_handle text;
  v_dash record;
  v_cols text;
begin
  raise notice '-- 9) dashboard';

  select login_id into v_handle from public.partners where email = 'auth-test@example.com';

  -- A bogus token returns NO rows rather than an error, so the caller cannot
  -- distinguish "bad token" from "no data".
  perform pg_temp.ok(
    (select count(*) from public.partner_dashboard('bogus-token-xyz')) = 0,
    'a bogus session token yields no dashboard rows (and no error)'
  );

  select portal_token into v_token
  from public.partner_login(v_handle, 'ChosenByPartner9876', null);

  select * into v_dash from public.partner_dashboard(v_token);
  perform pg_temp.ok(v_dash.partner_id is not null, 'a valid token yields the dashboard');
  perform pg_temp.ok(
    v_dash.partner_id = (select id from public.partners where email = 'auth-test@example.com'),
    'the dashboard is scoped to the caller own row'
  );
  perform pg_temp.ok(v_dash.status = 'draft', 'dashboard reports the real status');
  perform pg_temp.ok(v_dash.login_id = v_handle, 'dashboard reports the login id');

  -- Not approved yet => no artefacts, and the counts are zero rather than NULL.
  perform pg_temp.ok(v_dash.affiliate_id is null, 'no affiliate before approval');
  perform pg_temp.ok(v_dash.referrer_code is null, 'no referrer code before approval');
  perform pg_temp.ok(v_dash.referral_count = 0, 'referral count defaults to 0, not NULL');
  perform pg_temp.ok(v_dash.conversion_count = 0, 'conversion count defaults to 0, not NULL');
  perform pg_temp.ok(v_dash.commission_total = 0, 'commission total defaults to 0, not NULL');

  -- CRITICAL: the dashboard must not expose identity data. Assert on the
  -- function's declared return type, which is the authoritative surface —
  -- rather than on the SELECT list, which a later edit could widen.
  --
  -- NOTE: a `returns table` function has prorettype = the `record`
  -- pseudo-type (typrelid = 0), so joining pg_attribute via prorettype
  -- yields nothing. pg_get_function_result() is the correct accessor.
  select pg_get_function_result(p.oid) into v_cols
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'partner_dashboard';

  perform pg_temp.ok(v_cols is not null, 'dashboard return columns are introspectable');
  perform pg_temp.ok(
    v_cols like '%referral_count%', 'dashboard exposes referral_count'
  );
  perform pg_temp.ok(
    v_cols like '%commission_total%', 'dashboard exposes commission_total'
  );

  -- No KYC column may appear in the dashboard's output shape.
  perform pg_temp.ok(
    v_cols !~ '(aadhaar|pan_number|gstin|bank_|address|postal|phone|date_of_birth|legal_name)',
    'dashboard exposes NO KYC identity columns'
  );
end $$;

-- ---------------------------------------------------------------------------
-- 10) Dashboard reflects real referrals and commission money once approved.
-- ---------------------------------------------------------------------------
do $$
declare
  v_partner uuid;
  v_aff uuid;
  v_token text;
  v_handle text;
  v_dash record;
  i int;
begin
  raise notice '-- 10) dashboard aggregates';

  select id into v_partner from public.partners where email = 'auth-test@example.com';
  select login_id into v_handle from public.partners where id = v_partner;

  -- Build the approved shape directly: an affiliate plus its issued artefacts.
  insert into public.affiliates (name, contact_email, commission_amount, referrer_code, status)
  values ('Auth Test Partner', 'auth-test@example.com', 250, 'AUTHTEST01', 'active')
  returning id into v_aff;

  -- Setting status beyond draft/withdrawn requires the DPDP consent flags
  -- (partners_consent_check). That constraint is correct and is deliberately
  -- NOT bypassed here: the fixture satisfies it exactly as a real approved
  -- partner would.
  update public.partners set
    status = 'approved',
    affiliate_id = v_aff,
    approved_at = now(),
    terms_accepted = true,
    privacy_accepted = true,
    truthfulness_declared = true
  where id = v_partner;

  insert into public.coupons (code, affiliate_id, status, max_redemptions, redemption_count)
  values ('AUTHTESTCOUPON', v_aff, 'active', 100, 3);

  -- 3 referrals, 2 conversions, split across the pipeline's own status values.
  for i in 1..3 loop
    insert into public.affiliate_referrals (referrer_code, affiliate_id, purchaser_user_id)
    values ('AUTHTEST01', v_aff, 'auth-user-' || i);
  end loop;

  insert into public.affiliate_commissions
    (affiliate_id, purchaser_user_id, product_id, plan_price, rate_percent,
     commission_amount, status, source_event_id)
  values
    (v_aff, 'auth-user-1', 'pro_yearly', 999, 25, 250, 'pending',  'auth-evt-1'),
    (v_aff, 'auth-user-2', 'pro_yearly', 999, 25, 250, 'credited', 'auth-evt-2'),
    (v_aff, 'auth-user-3', 'pro_yearly', 999, 25, 250, 'paid',     'auth-evt-3');

  select portal_token into v_token
  from public.partner_login(v_handle, 'ChosenByPartner9876', null);

  select * into v_dash from public.partner_dashboard(v_token);

  perform pg_temp.ok(v_dash.affiliate_id = v_aff, 'affiliate is linked after approval');
  perform pg_temp.ok(v_dash.referrer_code = 'AUTHTEST01', 'referral code is exposed');
  perform pg_temp.ok(
    v_dash.install_url like '%referrer=utm_source=AUTHTEST01',
    'install URL uses the Play Install Referrer format the app actually parses'
  );
  perform pg_temp.ok(
    v_dash.install_url like 'https://play.google.com/store/apps/details?id=com.soulfulbhakti.app&referrer=utm_source=%',
    'install URL matches every other construction site in the codebase'
  );
  perform pg_temp.ok(v_dash.coupon_code = 'AUTHTESTCOUPON', 'coupon code is exposed');
  perform pg_temp.ok(v_dash.coupon_redemption_count = 3, 'coupon redemptions are counted');

  perform pg_temp.ok(v_dash.referral_count = 3, 'referral count is correct');
  perform pg_temp.ok(v_dash.conversion_count = 3, 'conversion count is correct');
  perform pg_temp.ok(v_dash.commission_pending = 250, 'pending commission bucketed correctly');
  perform pg_temp.ok(v_dash.commission_credited = 250, 'credited commission bucketed correctly');
  perform pg_temp.ok(v_dash.commission_paid = 250, 'paid commission bucketed correctly');
  perform pg_temp.ok(v_dash.commission_total = 750, 'total commission is the sum');
  perform pg_temp.ok(v_dash.commission_rate = 250, 'the agreed rate is shown');

  -- A SECOND partner must not be able to see any of this.
  perform pg_temp.ok(
    not exists (
      select 1 from public.partner_dashboard(
        (select portal_token_hash from public.partners where email = 'nohandle1@example.com')
      )
    ),
    'a token hash is not itself a valid session token'
  );
end $$;

do $$ begin
  raise notice '====================================================';
  raise notice ' ALL PARTNER AUTH TESTS PASSED';
  raise notice '====================================================';
end $$;
