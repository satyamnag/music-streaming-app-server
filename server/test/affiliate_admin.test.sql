-- ============================================================
-- TEST: affiliate/referral administration (migration 047)
--
-- Requires migrations 003, 039, 042, 046 and 047.
-- Everything runs inside one transaction that is rolled back.
--
-- Usage (from server/):
--   psql "$PARTNER_TEST_DB_URL" -v ON_ERROR_STOP=1 -f test/affiliate_admin.test.sql
-- ============================================================

begin;

-- ------------------------------------------------------------------
-- Fixtures
--   admin_ref   : active subscriber with a code and two friends
--   admin_paid  : friend #1 — PAID on Play, commission pending
--   admin_free  : friend #2 — joined, never paid
-- ------------------------------------------------------------------
insert into public.razorpay_subscriptions (subscription_id, user_id, plan_id, plan_slug, status)
values ('sub_admin_ref', 'admin_ref', 'plan_test', 'yearly', 'active')
on conflict (subscription_id) do update set status = 'active';

insert into public.referral_codes (user_id, code) values ('admin_ref', 'SBADMIN001')
on conflict (user_id) do nothing;

insert into public.referral_attributions (code, referrer_user_id, referred_user_id) values
  ('SBADMIN001', 'admin_ref', 'admin_paid'),
  ('SBADMIN001', 'admin_ref', 'admin_free')
on conflict (referred_user_id) do nothing;

insert into public.user_directory (user_id, email, name) values
  ('admin_ref', 'affiliate@example.com', 'Affiliate One'),
  ('admin_paid', 'payer@example.com', 'Paying Friend'),
  ('admin_free', 'free@example.com', 'Free Friend')
on conflict (user_id) do update set email = excluded.email;

insert into public.commissions
  (referrer_user_id, referred_user_id, product_id, plan_price, rate_percent,
   commission_amount, status, source_event_id)
values
  ('admin_ref', 'admin_paid', 'soulful_yearly', 120, 0, 51, 'pending', 'evt_admin_047')
on conflict (source_event_id) do nothing;

-- The order id for the paying friend (as the webhook would record it).
select public.admin_order_backfill(
  'admin_paid', 'GPA.ADMIN-0001', 'soulful_yearly', 'play', 120,
  '2026-11-23T02:45:00Z', 'processed'
);

-- ------------------------------------------------------------------
-- 1. Summary: one row, the right counts, the right money, email joined.
-- ------------------------------------------------------------------
do $$
declare
  r record;
begin
  select * into r from public.admin_affiliate_summary('SBADMIN001', null, null, 50);
  if r is null then raise exception 'FAIL 1a: no affiliate row returned'; end if;
  if r.email <> 'affiliate@example.com' then raise exception 'FAIL 1b: email=%', r.email; end if;
  if r.code <> 'SBADMIN001' then raise exception 'FAIL 1c: code=%', r.code; end if;
  if not r.is_active then raise exception 'FAIL 1d: affiliate should be active'; end if;
  if r.friends_joined <> 2 then raise exception 'FAIL 1e: friends=%', r.friends_joined; end if;
  if r.paid_friends <> 1 then raise exception 'FAIL 1f: paid=%', r.paid_friends; end if;
  if r.pending_amount <> 51 or r.total_amount <> 51 then
    raise exception 'FAIL 1g: pending=% total=%', r.pending_amount, r.total_amount;
  end if;
  raise notice 'PASS 1: affiliate summary (2 friends, 1 paid, Rs.51 waiting)';
end $$;

-- ------------------------------------------------------------------
-- 2. Filters: search by email, by user id, status and rail.
-- ------------------------------------------------------------------
do $$
declare n integer;
begin
  select count(*) into n from public.admin_affiliate_summary('payer@example.com', null, null, 50);
  -- searching a CUSTOMER's email must not match the affiliate directory
  if n <> 0 then raise exception 'FAIL 2a: customer email matched % affiliates', n; end if;

  select count(*) into n from public.admin_affiliate_summary('affiliate@example.com', null, null, 50);
  if n <> 1 then raise exception 'FAIL 2b: affiliate email search returned %', n; end if;

  select count(*) into n from public.admin_affiliate_summary('admin_ref', null, null, 50);
  if n <> 1 then raise exception 'FAIL 2c: user id search returned %', n; end if;

  select count(*) into n from public.admin_affiliate_summary(null, 'pending', null, 50);
  if n < 1 then raise exception 'FAIL 2d: pending filter returned %', n; end if;

  select count(*) into n from public.admin_affiliate_summary(null, 'pending', 'play', 50);
  if n < 1 then raise exception 'FAIL 2e: play filter returned %', n; end if;

  select count(*) into n from public.admin_affiliate_summary(null, 'pending', 'web', 50);
  if n <> 0 then raise exception 'FAIL 2f: web filter returned % (no web commission exists)', n; end if;

  raise notice 'PASS 2: search, status and rail filters behave';
end $$;

-- ------------------------------------------------------------------
-- 3. Drill-down: both friends listed, the payer with order + commission.
-- ------------------------------------------------------------------
do $$
declare
  r record;
  v_paid record;
  v_free record;
begin
  select * into v_paid from public.admin_affiliate_referrals('admin_ref')
  where referred_user_id = 'admin_paid';
  select * into v_free from public.admin_affiliate_referrals('admin_ref')
  where referred_user_id = 'admin_free';

  if v_paid is null or v_free is null then
    raise exception 'FAIL 3a: expected both friends in the drill-down';
  end if;
  if v_paid.email <> 'payer@example.com' then raise exception 'FAIL 3b: payer email=%', v_paid.email; end if;
  if v_paid.order_id <> 'GPA.ADMIN-0001' then raise exception 'FAIL 3c: order=%', v_paid.order_id; end if;
  if v_paid.rail <> 'play' then raise exception 'FAIL 3d: rail=%', v_paid.rail; end if;
  if v_paid.amount <> 120 then raise exception 'FAIL 3e: amount=%', v_paid.amount; end if;
  if v_paid.commission_amount <> 51 or v_paid.commission_status <> 'pending' then
    raise exception 'FAIL 3f: commission=% %', v_paid.commission_amount, v_paid.commission_status;
  end if;
  if v_free.commission_amount is not null then
    raise exception 'FAIL 3g: the unpaid friend must carry no commission';
  end if;
  raise notice 'PASS 3: drill-down shows order id, rail, amount and commission state';
end $$;

-- ------------------------------------------------------------------
-- 4. admin_order_backfill is idempotent.
-- ------------------------------------------------------------------
do $$
declare n integer;
begin
  perform public.admin_order_backfill(
    'admin_paid', 'GPA.ADMIN-0001', 'soulful_yearly', 'play', 120,
    '2026-11-23T02:45:00Z', 'processed'
  );
  select count(*) into n from public.referral_purchases where order_id = 'GPA.ADMIN-0001';
  if n <> 1 then raise exception 'FAIL 4: backfill produced % rows, want 1', n; end if;
  raise notice 'PASS 4: order backfill is idempotent';
end $$;

-- ------------------------------------------------------------------
-- 5. A lapsed affiliate is reported as such (LAPSED in the UI).
-- ------------------------------------------------------------------
do $$
declare r record;
begin
  update public.razorpay_subscriptions set status = 'expired' where user_id = 'admin_ref';
  select * into r from public.admin_affiliate_summary('admin_ref', null, null, 50);
  if r.is_active then raise exception 'FAIL 5: lapsed affiliate still reported active'; end if;
  raise notice 'PASS 5: lapsed affiliate reported inactive';
end $$;

-- ------------------------------------------------------------------
-- 6. The per-rail split (migration 050): one Play commission + one web
--    commission must be counted separately, and their sums must add up.
-- ------------------------------------------------------------------
do $$
declare r record;
begin
  -- a second friend paid on the WEB rail
  insert into public.referral_attributions (code, referrer_user_id, referred_user_id)
  values ('SBADMIN001', 'admin_ref', 'admin_webpayer')
  on conflict (referred_user_id) do nothing;

  insert into public.commissions
    (referrer_user_id, referred_user_id, product_id, plan_price, rate_percent,
     commission_amount, status, source_event_id)
  values
    ('admin_ref', 'admin_webpayer', 'razorpay_yearly', 120, 0, 51, 'pending', 'evt_admin_050')
  on conflict (source_event_id) do nothing;

  select * into r from public.admin_affiliate_summary_v2('admin_ref', null, null, 50);
  if r.paid_play <> 1 or r.paid_web <> 1 then
    raise exception 'FAIL 6a: split is play=% web=% (want 1/1)', r.paid_play, r.paid_web;
  end if;
  if r.paid_friends <> 2 then
    raise exception 'FAIL 6b: paid total=% (want 2)', r.paid_friends;
  end if;
  if r.pending_play <> 51 or r.pending_web <> 51 then
    raise exception 'FAIL 6c: pending split is play=% web=% (want 51/51)', r.pending_play, r.pending_web;
  end if;
  if r.pending_amount <> r.pending_play + r.pending_web then
    raise exception 'FAIL 6d: the split does not add up to the total';
  end if;
  raise notice 'PASS 6: the Play and web commissions are counted separately and sum to the total';
end $$;

rollback;
