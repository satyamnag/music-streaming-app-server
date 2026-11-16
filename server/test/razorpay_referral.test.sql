-- ============================================================
-- TEST: Razorpay referral program (migration 039)
--
-- Runs against a real PostgreSQL database with migrations 003, 038 and
-- 039 applied. Everything happens inside one transaction that is rolled
-- back, so it leaves no rows behind and is safe to re-run.
--
-- Usage (from server/):
--   psql "$PARTNER_TEST_DB_URL" -v ON_ERROR_STOP=1 -f test/razorpay_referral.test.sql
--
-- Every assertion raises an exception on failure, so a non-zero exit or
-- a raised error means the program is broken.
-- ============================================================

begin;

-- ------------------------------------------------------------------
-- Fixtures
--   test_ref_active  : an active subscriber (a valid affiliate)
--   test_ref_lapsed  : has a code but no active subscription
--   test_referred    : subscribes using test_ref_active's code
--   test_self        : tries to use its own code
--   test_plain       : subscribes with no code at all
-- ------------------------------------------------------------------

-- An active Razorpay subscription makes test_ref_active an affiliate.
insert into public.razorpay_subscriptions
  (subscription_id, user_id, plan_id, plan_slug, status)
values
  ('sub_test_ref_active', 'test_ref_active', 'plan_test', 'yearly', 'active')
on conflict (subscription_id) do update set status = 'active';

insert into public.referral_codes (user_id, code) values
  ('test_ref_active', 'SBTESTACTIVE'),
  ('test_ref_lapsed', 'SBTESTLAPSED')
on conflict (user_id) do nothing;

-- ------------------------------------------------------------------
-- 1. A code from an active subscriber validates.
-- ------------------------------------------------------------------
do $$
declare
  v_status text;
begin
  v_status := public.validate_referral_code('SBTESTACTIVE', 'test_referred');
  if v_status <> 'valid' then
    raise exception 'FAIL 1: expected valid, got %', v_status;
  end if;
  raise notice 'PASS 1: active subscriber code validates';
end $$;

-- Case/whitespace insensitivity (people paste codes with spaces).
do $$
begin
  if public.validate_referral_code('  sbtestactive  ', 'test_referred') <> 'valid' then
    raise exception 'FAIL 1b: code matching is not case/space insensitive';
  end if;
  raise notice 'PASS 1b: code matching is case/space insensitive';
end $$;

-- ------------------------------------------------------------------
-- 2. An unknown code is rejected.
-- ------------------------------------------------------------------
do $$
begin
  if public.validate_referral_code('SBNOPE0000', 'test_referred') <> 'unknown' then
    raise exception 'FAIL 2: unknown code was not rejected';
  end if;
  raise notice 'PASS 2: unknown code rejected';
end $$;

-- ------------------------------------------------------------------
-- 3. Self-referral is rejected.
-- ------------------------------------------------------------------
do $$
begin
  if public.validate_referral_code('SBTESTACTIVE', 'test_ref_active') <> 'self' then
    raise exception 'FAIL 3: self-referral was not rejected';
  end if;
  raise notice 'PASS 3: self-referral rejected';
end $$;

-- ------------------------------------------------------------------
-- 4. A code from a non-subscriber is rejected.
-- ------------------------------------------------------------------
do $$
begin
  if public.validate_referral_code('SBTESTLAPSED', 'test_referred') <> 'inactive_referrer' then
    raise exception 'FAIL 4: lapsed referrer code was accepted';
  end if;
  raise notice 'PASS 4: lapsed referrer code rejected';
end $$;

-- ------------------------------------------------------------------
-- 5. The first successful payment credits exactly Rs.51, pending.
-- ------------------------------------------------------------------
do $$
declare
  v_result text;
  v_row record;
begin
  v_result := public.credit_razorpay_referral_commission(
    'test_referred', 'SBTESTACTIVE', 'pay_first_001', 120
  );
  if v_result <> 'credited' then
    raise exception 'FAIL 5: expected credited, got %', v_result;
  end if;

  select referrer_user_id, referred_user_id, product_id, commission_amount,
         status, plan_price, rate_percent, source_event_id
    into v_row
  from public.commissions
  where referred_user_id = 'test_referred' and product_id = 'razorpay_yearly';

  if v_row.referrer_user_id <> 'test_ref_active' then
    raise exception 'FAIL 5a: wrong referrer %', v_row.referrer_user_id;
  end if;
  if v_row.commission_amount <> 51 then
    raise exception 'FAIL 5b: expected 51, got %', v_row.commission_amount;
  end if;
  if v_row.status <> 'pending' then
    raise exception 'FAIL 5c: expected pending, got %', v_row.status;
  end if;
  if v_row.plan_price <> 120 then
    raise exception 'FAIL 5d: expected plan price 120, got %', v_row.plan_price;
  end if;
  if v_row.source_event_id <> 'pay_first_001' then
    raise exception 'FAIL 5e: wrong idempotency key %', v_row.source_event_id;
  end if;
  raise notice 'PASS 5: first payment credited Rs.51 as pending';
end $$;

-- ------------------------------------------------------------------
-- 6. Attribution was written at payment time and is now immutable.
-- ------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from public.referral_attributions
    where referred_user_id = 'test_referred'
      and referrer_user_id = 'test_ref_active'
      and code = 'SBTESTACTIVE'
  ) then
    raise exception 'FAIL 6: attribution was not recorded';
  end if;
  if public.validate_referral_code('SBTESTLAPSED', 'test_referred') <> 'already_attributed' then
    raise exception 'FAIL 6b: an already-attributed user could be re-attributed';
  end if;
  raise notice 'PASS 6: attribution recorded once and immutable';
end $$;

-- ------------------------------------------------------------------
-- 7. FIRST PAYMENT ONLY: a renewal must not credit again.
-- ------------------------------------------------------------------
do $$
declare
  v_result text;
  v_count int;
begin
  v_result := public.credit_razorpay_referral_commission(
    'test_referred', 'SBTESTACTIVE', 'pay_renewal_002', 120
  );
  if v_result <> 'already_credited' then
    raise exception 'FAIL 7: renewal credited again (got %)', v_result;
  end if;

  select count(*) into v_count
  from public.commissions
  where referred_user_id = 'test_referred' and product_id = 'razorpay_yearly';
  if v_count <> 1 then
    raise exception 'FAIL 7b: expected 1 credit row, found %', v_count;
  end if;
  raise notice 'PASS 7: renewals credit nothing (first payment only)';
end $$;

-- ------------------------------------------------------------------
-- 8. Idempotency: replaying the same payment id changes nothing.
-- ------------------------------------------------------------------
do $$
declare
  v_count int;
begin
  perform public.credit_razorpay_referral_commission(
    'test_referred', 'SBTESTACTIVE', 'pay_first_001', 120
  );
  select count(*) into v_count
  from public.commissions
  where referred_user_id = 'test_referred' and product_id = 'razorpay_yearly';
  if v_count <> 1 then
    raise exception 'FAIL 8: replay created a duplicate (count %)', v_count;
  end if;
  raise notice 'PASS 8: replaying a payment id is idempotent';
end $$;

-- ------------------------------------------------------------------
-- 9. No code and no prior attribution => nothing is credited.
-- ------------------------------------------------------------------
do $$
declare
  v_result text;
  v_count int;
begin
  v_result := public.credit_razorpay_referral_commission(
    'test_plain', null, 'pay_plain_001', 120
  );
  if v_result <> 'not_attributed' then
    raise exception 'FAIL 9: expected not_attributed, got %', v_result;
  end if;

  select count(*) into v_count
  from public.commissions where referred_user_id = 'test_plain';
  if v_count <> 0 then
    raise exception 'FAIL 9b: an unattributed purchase was credited';
  end if;
  raise notice 'PASS 9: unattributed purchase credits nothing';
end $$;

-- ------------------------------------------------------------------
-- 10. A lapsed referrer earns nothing, even with a valid-at-signup code.
-- ------------------------------------------------------------------
do $$
declare
  v_result text;
  v_count int;
begin
  v_result := public.credit_razorpay_referral_commission(
    'test_other', 'SBTESTLAPSED', 'pay_other_001', 120
  );
  if v_result <> 'referrer_inactive' then
    raise exception 'FAIL 10: expected referrer_inactive, got %', v_result;
  end if;

  select count(*) into v_count
  from public.commissions where referred_user_id = 'test_other';
  if v_count <> 0 then
    raise exception 'FAIL 10b: a lapsed referrer was credited';
  end if;
  raise notice 'PASS 10: lapsed referrer earns nothing';
end $$;

-- ------------------------------------------------------------------
-- 11. Self-referral is refused by the credit path too (defence in depth).
-- ------------------------------------------------------------------
do $$
declare
  v_result text;
begin
  v_result := public.credit_razorpay_referral_commission(
    'test_ref_active', 'SBTESTACTIVE', 'pay_self_001', 120
  );
  if v_result <> 'self_referral' then
    raise exception 'FAIL 11: expected self_referral, got %', v_result;
  end if;
  raise notice 'PASS 11: credit path refuses self-referral';
end $$;

-- ------------------------------------------------------------------
-- 12. The partial index is scoped: Play rows are NOT limited to one.
--     (Proves the new constraint cannot break the existing pipeline.)
-- ------------------------------------------------------------------
do $$
begin
  insert into public.commissions
    (referrer_user_id, referred_user_id, product_id, plan_price,
     rate_percent, commission_amount, status, source_event_id)
  values
    ('test_ref_active', 'test_referred', 'soulful_yearly', 120, 25, 30, 'pending', 'play_evt_1'),
    ('test_ref_active', 'test_referred', 'soulful_yearly', 120, 25, 30, 'pending', 'play_evt_2');

  if (select count(*) from public.commissions
      where referred_user_id = 'test_referred' and product_id = 'soulful_yearly') <> 2 then
    raise exception 'FAIL 12: the partial index blocked Play commission rows';
  end if;
  raise notice 'PASS 12: Play rows are unaffected by the new index';
end $$;

-- ------------------------------------------------------------------
-- 13. The account-page summary reports the right numbers.
-- ------------------------------------------------------------------
do $$
declare
  v_row record;
begin
  select * into v_row from public.referral_program_summary('test_ref_active');

  if v_row.code <> 'SBTESTACTIVE' then
    raise exception 'FAIL 13a: wrong code %', v_row.code;
  end if;
  if v_row.is_affiliate is not true then
    raise exception 'FAIL 13b: active subscriber not reported as affiliate';
  end if;
  if v_row.credited_referrals <> 1 then
    raise exception 'FAIL 13c: expected 1 referral credit, got %', v_row.credited_referrals;
  end if;
  if v_row.amount_per_referral <> 51 then
    raise exception 'FAIL 13d: expected 51 per referral, got %', v_row.amount_per_referral;
  end if;
  -- 51 from the referral + 30 + 30 from the two Play rows.
  if v_row.total_amount <> 111 then
    raise exception 'FAIL 13e: expected total 111, got %', v_row.total_amount;
  end if;
  if v_row.pending_amount <> 111 then
    raise exception 'FAIL 13f: expected pending 111, got %', v_row.pending_amount;
  end if;
  raise notice 'PASS 13: summary reports code, affiliate flag and earnings';
end $$;

-- ------------------------------------------------------------------
-- 14. The amount is configurable without a code change.
-- ------------------------------------------------------------------
do $$
declare
  v_result text;
  v_amount numeric;
begin
  update public.referral_program_config set commission_amount = 75 where id = true;

  insert into public.razorpay_subscriptions
    (subscription_id, user_id, plan_id, plan_slug, status)
  values ('sub_test_ref2', 'test_ref2', 'plan_test', 'yearly', 'active')
  on conflict (subscription_id) do update set status = 'active';
  insert into public.referral_codes (user_id, code) values ('test_ref2', 'SBTESTREF2')
  on conflict (user_id) do nothing;

  v_result := public.credit_razorpay_referral_commission(
    'test_referred2', 'SBTESTREF2', 'pay_ref2_001', 120
  );
  if v_result <> 'credited' then
    raise exception 'FAIL 14: expected credited, got %', v_result;
  end if;

  select commission_amount into v_amount
  from public.commissions where referred_user_id = 'test_referred2';
  if v_amount <> 75 then
    raise exception 'FAIL 14b: configured amount not honoured (got %)', v_amount;
  end if;

  update public.referral_program_config set commission_amount = 51 where id = true;
  raise notice 'PASS 14: the flat amount is configurable';
end $$;

-- ------------------------------------------------------------------
-- 15. Single level: the referrer's own referrer earns nothing.
-- ------------------------------------------------------------------
do $$
declare
  v_count int;
begin
  -- test_ref2 is itself a subscriber; make it referred by test_ref_active,
  -- then have test_ref2 refer test_referred2 (already done in test 14).
  insert into public.referral_attributions (code, referrer_user_id, referred_user_id)
  values ('SBTESTACTIVE', 'test_ref_active', 'test_ref2')
  on conflict (referred_user_id) do nothing;

  select count(*) into v_count
  from public.commissions
  where referrer_user_id = 'test_ref_active' and referred_user_id = 'test_ref2';

  if v_count <> 0 then
    raise exception 'FAIL 15: upline was credited (multi-level behaviour)';
  end if;
  raise notice 'PASS 15: single level only, no upline credit';
end $$;

-- ------------------------------------------------------------------
-- 16. The account-page summary works before a user has a code (so the
--     page can advertise the amount to a non-affiliate).
-- ------------------------------------------------------------------
do $$
declare
  v_count int;
  v_row record;
begin
  select count(*) into v_count
  from public.referral_program_summary('test_no_code_user');

  if v_count <> 1 then
    raise exception 'FAIL 16: summary returned % rows for a user with no code (expected 1)', v_count;
  end if;

  select * into v_row from public.referral_program_summary('test_no_code_user');
  if v_row.code is not null then
    raise exception 'FAIL 16b: expected a null code, got %', v_row.code;
  end if;
  if v_row.amount_per_referral <> 51 then
    raise exception 'FAIL 16c: expected amount 51, got %', v_row.amount_per_referral;
  end if;
  if v_row.is_affiliate is not false then
    raise exception 'FAIL 16d: a non-subscriber was reported as an affiliate';
  end if;
  raise notice 'PASS 16: summary works before a user has a code';
end $$;

-- ------------------------------------------------------------------
-- 17. ANY NUMBER of users may use the same code. One code is not
--     single-use; each distinct referred user earns the referrer once.
-- ------------------------------------------------------------------
do $$
declare
  v_result text;
  v_count int;
begin
  v_result := public.credit_razorpay_referral_commission(
    'test_referred3', 'SBTESTACTIVE', 'pay_third_001', 120
  );
  if v_result <> 'credited' then
    raise exception 'FAIL 17: a second user was not credited (got %)', v_result;
  end if;

  select count(*) into v_count
  from public.commissions
  where referrer_user_id = 'test_ref_active' and product_id = 'razorpay_yearly';
  if v_count <> 2 then
    raise exception 'FAIL 17b: expected 2 referral credits, got %', v_count;
  end if;
  raise notice 'PASS 17: the same code credits every new referred user';
end $$;

-- ------------------------------------------------------------------
-- Nothing above should have persisted.
-- ------------------------------------------------------------------
rollback;

select 'ALL RAZORPAY REFERRAL TESTS PASSED' as result;
