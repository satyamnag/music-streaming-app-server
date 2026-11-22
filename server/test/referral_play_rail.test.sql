-- ============================================================
-- TEST: Play rail entitlement + referral (migration 046)
--
-- Runs against a real PostgreSQL database with migrations 003, 038,
-- 039, 042 and 046 applied. Everything happens inside one transaction
-- that is rolled back, so it leaves no rows behind and is safe to
-- re-run.
--
-- Usage (from server/):
--   psql "$PARTNER_TEST_DB_URL" -v ON_ERROR_STOP=1 -f test/referral_play_rail.test.sql
--
-- Every assertion raises an exception on failure, so a non-zero exit or
-- a raised error means the program is broken.
-- ============================================================

begin;

-- ------------------------------------------------------------------
-- Fixtures
--   test_ref_play  : paid ONLY through Play (the case 046 exists for)
--   test_ref_rz    : paid through Razorpay (regression control)
--   test_ref_grace : Play user whose grace rules are asserted
--   test_referred_play / test_referred_rz : referred purchasers
-- ------------------------------------------------------------------

insert into public.play_subscriptions (user_id, product_id, status, current_start, current_end)
values
  ('test_ref_play', 'soulful_yearly', 'active', now() - interval '1 day', now() + interval '30 days'),
  ('test_ref_grace', 'soulful_monthly', 'cancelled', now() - interval '10 days', now() + interval '5 days')
on conflict (user_id, product_id) do update
  set status = excluded.status,
      current_start = excluded.current_start,
      current_end = excluded.current_end;

insert into public.razorpay_subscriptions (subscription_id, user_id, plan_id, plan_slug, status)
values ('sub_test_ref_rz', 'test_ref_rz', 'plan_test', 'yearly', 'active')
on conflict (subscription_id) do update set status = 'active';

insert into public.referral_codes (user_id, code) values
  ('test_ref_play', 'SBPLAY0001'),
  ('test_ref_rz', 'SBRZ000001')
on conflict (user_id) do nothing;

-- ------------------------------------------------------------------
-- 1. Entitlement: a Play-paid user is active, source 'play', Play plan.
-- ------------------------------------------------------------------
do $$
declare
  r record;
begin
  select * into r from public.subscription_entitlement_any_rail('test_ref_play');
  if not coalesce(r.active, false) then
    raise exception 'FAIL 1: Play-paid user not active';
  end if;
  if r.source <> 'play' then
    raise exception 'FAIL 1: source=%, want play', r.source;
  end if;
  if r.plan <> 'soulful_yearly' then
    raise exception 'FAIL 1: plan=%, want soulful_yearly', r.plan;
  end if;
  raise notice 'PASS 1: Play-paid user entitled (source=play)';
end $$;

-- ------------------------------------------------------------------
-- 2. Entitlement: a Razorpay-paid user is still active, source 'razorpay'.
-- ------------------------------------------------------------------
do $$
declare
  r record;
begin
  select * into r from public.subscription_entitlement_any_rail('test_ref_rz');
  if not coalesce(r.active, false) then
    raise exception 'FAIL 2: Razorpay-paid user not active';
  end if;
  if r.source <> 'razorpay' then
    raise exception 'FAIL 2: source=%, want razorpay', r.source;
  end if;
  raise notice 'PASS 2: Razorpay-paid user still entitled (source=razorpay)';
end $$;

-- ------------------------------------------------------------------
-- 3. Entitlement: an unknown user gets exactly one INACTIVE row.
-- ------------------------------------------------------------------
do $$
declare
  r record;
  n integer;
begin
  select count(*) into n from public.subscription_entitlement_any_rail('test_nobody');
  if n <> 1 then
    raise exception 'FAIL 3: expected one row, got %', n;
  end if;
  select * into r from public.subscription_entitlement_any_rail('test_nobody');
  if coalesce(r.active, false) then
    raise exception 'FAIL 3: unknown user reported active';
  end if;
  raise notice 'PASS 3: unknown user is inactive (one row)';
end $$;

-- ------------------------------------------------------------------
-- 4. Grace policy: cancelled with a future end stays active; expired
--    (or a past end) does not.
-- ------------------------------------------------------------------
do $$
declare
  r record;
begin
  select * into r from public.subscription_entitlement_any_rail('test_ref_grace');
  if not coalesce(r.active, false) then
    raise exception 'FAIL 4a: cancelled-but-in-period user should stay active';
  end if;

  update public.play_subscriptions
     set status = 'expired', current_end = now() - interval '1 hour'
   where user_id = 'test_ref_grace' and product_id = 'soulful_monthly';

  select * into r from public.subscription_entitlement_any_rail('test_ref_grace');
  if coalesce(r.active, false) then
    raise exception 'FAIL 4b: expired Play subscription should be inactive';
  end if;
  raise notice 'PASS 4: Play grace policy (cancelled-until-end, expired=off)';
end $$;

-- ------------------------------------------------------------------
-- 5. validate_referral_code: a Play-paid referrer's code validates.
-- ------------------------------------------------------------------
do $$
declare
  v_status text;
begin
  v_status := public.validate_referral_code('SBPLAY0001', 'test_referred_play');
  if v_status <> 'valid' then
    raise exception 'FAIL 5: expected valid, got %', v_status;
  end if;
  raise notice 'PASS 5: Play-paid referrer code validates';
end $$;

-- ------------------------------------------------------------------
-- 6. validate_referral_code: a LAPSED Play referrer is refused.
-- ------------------------------------------------------------------
do $$
declare
  v_status text;
begin
  update public.play_subscriptions
     set status = 'expired', current_end = now() - interval '1 hour'
   where user_id = 'test_ref_play' and product_id = 'soulful_yearly';

  v_status := public.validate_referral_code('SBPLAY0001', 'test_referred_play2');
  if v_status <> 'inactive_referrer' then
    raise exception 'FAIL 6: expected inactive_referrer, got %', v_status;
  end if;

  -- Restore the fixture for the credit tests below.
  update public.play_subscriptions
     set status = 'active', current_end = now() + interval '30 days'
   where user_id = 'test_ref_play' and product_id = 'soulful_yearly';
  raise notice 'PASS 6: lapsed Play referrer refused, then restored';
end $$;

-- ------------------------------------------------------------------
-- 7. credit_referral_commission: a referred Play purchase credits the
--    PLAY-PAID referrer the flat amount, as a pending row.
-- ------------------------------------------------------------------
insert into public.referral_attributions (code, referrer_user_id, referred_user_id)
values ('SBPLAY0001', 'test_ref_play', 'test_referred_play')
on conflict (referred_user_id) do nothing;

do $$
declare
  v_ok boolean;
  v_amount numeric;
  v_pending numeric;
  v_status text;
begin
  v_ok := public.credit_referral_commission(
    'test_referred_play', 'soulful_yearly', 120, 0, 'evt_test_play_001'
  );
  if not v_ok then
    raise exception 'FAIL 7a: credit refused for a Play-paid referrer';
  end if;

  select cfg.commission_amount into v_amount
  from public.referral_program_config cfg where cfg.id = true;
  if v_amount is null or v_amount <> 51 then
    raise exception 'FAIL 7b: flat amount=%, want 51', v_amount;
  end if;

  select c.commission_amount, c.status into v_pending, v_status
  from public.commissions c
  where c.referred_user_id = 'test_referred_play'
    and c.product_id = 'soulful_yearly';

  if v_pending <> v_amount or v_status <> 'pending' then
    raise exception 'FAIL 7c: commission row %/%, want %/pending', v_pending, v_status, v_amount;
  end if;
  raise notice 'PASS 7: Play purchase credits the Play-paid referrer Rs.% (pending)', v_amount;
end $$;

-- ------------------------------------------------------------------
-- 8. A second credit attempt for the same referred user is refused
--    (partial unique index, migrations 042).
-- ------------------------------------------------------------------
do $$
declare
  v_ok boolean;
begin
  v_ok := public.credit_referral_commission(
    'test_referred_play', 'soulful_yearly', 120, 0, 'evt_test_play_001_replay'
  );
  if v_ok then
    raise exception 'FAIL 8: duplicate Play credit was accepted';
  end if;
  raise notice 'PASS 8: one Play credit per referred user, ever';
end $$;

-- ------------------------------------------------------------------
-- 9. Regression: the same function still credits a RAZORPAY-paid
--    referrer (the 042 behaviour is preserved).
-- ------------------------------------------------------------------
insert into public.referral_attributions (code, referrer_user_id, referred_user_id)
values ('SBRZ000001', 'test_ref_rz', 'test_referred_rz')
on conflict (referred_user_id) do nothing;

do $$
declare
  v_ok boolean;
begin
  v_ok := public.credit_referral_commission(
    'test_referred_rz', 'soulful_yearly', 120, 0, 'evt_test_rz_001'
  );
  if not v_ok then
    raise exception 'FAIL 9: Razorpay-paid referrer was refused (regression)';
  end if;
  raise notice 'PASS 9: Razorpay-paid referrer still credited (regression)';
end $$;

-- ------------------------------------------------------------------
-- 10. referral_program_summary for the Play-paid referrer: affiliate,
--     one friend, Rs.51 earned, Rs.51 awaiting settlement.
-- ------------------------------------------------------------------
do $$
declare
  r record;
begin
  select * into r from public.referral_program_summary('test_ref_play');
  if not coalesce(r.is_affiliate, false) then
    raise exception 'FAIL 10a: Play-paid referrer not an affiliate';
  end if;
  if r.referral_count <> 1 then
    raise exception 'FAIL 10b: referral_count=%, want 1', r.referral_count;
  end if;
  if r.total_amount <> 51 or r.pending_amount <> 51 then
    raise exception 'FAIL 10c: total=%, pending=%, want 51/51', r.total_amount, r.pending_amount;
  end if;
  if r.credited_referrals <> 1 then
    raise exception 'FAIL 10d: credited_referrals=%, want 1', r.credited_referrals;
  end if;
  if r.amount_per_referral <> 51 then
    raise exception 'FAIL 10e: amount_per_referral=%, want 51', r.amount_per_referral;
  end if;
  raise notice 'PASS 10: /account summary: friends=1, earned=Rs.51, awaiting=Rs.51';
end $$;

-- ------------------------------------------------------------------
-- 11. play_subscription_upsert is monotonic: a replayed OLDER event
--     can never regress a newer state.
-- ------------------------------------------------------------------
do $$
declare
  r record;
begin
  perform public.play_subscription_upsert(
    'test_upsert_guard', 'soulful_yearly', 'active',
    now() - interval '1 day', now() + interval '30 days',
    'PLAY_STORE', 'PRODUCTION', 'evt_new', 'renewal', now(), '{}'::jsonb
  );

  -- Replay of an OLDER event (older event_ts) must be ignored.
  perform public.play_subscription_upsert(
    'test_upsert_guard', 'soulful_yearly', 'refunded',
    now() - interval '2 days', now() - interval '1 day',
    'PLAY_STORE', 'PRODUCTION', 'evt_old', 'initial_purchase',
    now() - interval '1 hour', '{}'::jsonb
  );

  select status into r from public.play_subscriptions
  where user_id = 'test_upsert_guard' and product_id = 'soulful_yearly';
  if r.status <> 'active' then
    raise exception 'FAIL 11a: older replayed event regressed status to %', r.status;
  end if;

  -- A genuinely NEWER event must still apply.
  perform public.play_subscription_upsert(
    'test_upsert_guard', 'soulful_yearly', 'cancelled',
    now() - interval '1 day', now() + interval '5 days',
    'PLAY_STORE', 'PRODUCTION', 'evt_newer', 'cancellation',
    now() + interval '1 minute', '{}'::jsonb
  );
  select status into r from public.play_subscriptions
  where user_id = 'test_upsert_guard' and product_id = 'soulful_yearly';
  if r.status <> 'cancelled' then
    raise exception 'FAIL 11b: newer event did not apply (status=%)', r.status;
  end if;
  raise notice 'PASS 11: play_subscription_upsert honours event order';
end $$;

rollback;
