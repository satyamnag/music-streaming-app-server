-- ============================================================
-- TEST: channel links (migration 052)
--
-- Requires migrations 003, 039, 042, 047, 051, 052.
-- Runs in one transaction and rolls back.
--
-- Usage (from server/):
--   psql "$PARTNER_TEST_DB_URL" -v ON_ERROR_STOP=1 -f test/channel_links.test.sql
-- ============================================================

begin;

-- ------------------------------------------------------------------
-- 1. The three brand codes exist, are flagged as channels, and are owned by
--    identities that can never be an active subscriber.
-- ------------------------------------------------------------------
do $$
declare n integer;
begin
  select count(*) into n from public.referral_codes where is_channel;
  if n < 3 then raise exception 'FAIL 1a: expected at least 3 channel codes, found %', n; end if;

  select count(*) into n
  from public.referral_codes
  where is_channel and channel in ('facebook', 'instagram', 'youtube');
  if n < 3 then raise exception 'FAIL 1b: expected one code per channel, found %', n; end if;

  select count(*) into n
  from public.referral_codes rc
  where rc.is_channel and exists (
    select 1 from public.subscription_entitlement_any_rail(rc.user_id) e where e.active
  );
  if n <> 0 then raise exception 'FAIL 1c: a channel identity is an active subscriber (% rows)', n; end if;

  raise notice 'PASS 1: three channel codes, none of them a paying identity';
end $$;

-- ------------------------------------------------------------------
-- 2. A sign-up through a channel link IS recorded (so sign-ups are countable)
--    but earns NO commission, because the referrer is never active.
-- ------------------------------------------------------------------
do $$
declare
  v_attributed boolean;
  v_credited boolean;
  v_code text;
begin
  select code into v_code from public.referral_codes where channel = 'instagram' and is_channel;
  if v_code is null then raise exception 'FAIL 2a: no instagram channel code'; end if;

  insert into public.referral_attributions (code, referrer_user_id, referred_user_id)
  select v_code, rc.user_id, 'chan_test_devotee'
  from public.referral_codes rc
  where rc.code = v_code
  on conflict (referred_user_id) do nothing;

  select exists (
    select 1 from public.referral_attributions where referred_user_id = 'chan_test_devotee'
  ) into v_attributed;
  if not v_attributed then raise exception 'FAIL 2b: the channel sign-up was not recorded'; end if;

  v_credited := public.credit_referral_commission(
    'chan_test_devotee', 'soulful_yearly', 120, 0, 'evt_channel_test_052'
  );
  if v_credited then
    raise exception 'FAIL 2c: a channel link paid a commission - it must never pay';
  end if;
  raise notice 'PASS 2: channel sign-up recorded, no commission paid';
end $$;

-- ------------------------------------------------------------------
-- 3. The report counts clicks and sign-ups per channel.
-- ------------------------------------------------------------------
do $$
declare r record; v_code text;
begin
  select code into v_code from public.referral_codes where channel = 'facebook' and is_channel;

  insert into public.referral_channel_clicks (channel, code, source_path)
  values ('facebook', v_code, '/go/fb'), ('facebook', v_code, '/go/fb');

  insert into public.referral_attributions (code, referrer_user_id, referred_user_id)
  select v_code, rc.user_id, 'chan_test_fb1' from public.referral_codes rc where rc.code = v_code
  on conflict (referred_user_id) do nothing;
  insert into public.referral_attributions (code, referrer_user_id, referred_user_id)
  select v_code, rc.user_id, 'chan_test_fb2' from public.referral_codes rc where rc.code = v_code
  on conflict (referred_user_id) do nothing;

  select * into r from public.admin_channel_summary() where channel = 'facebook';
  if r is null then raise exception 'FAIL 3a: facebook row missing from the report'; end if;
  if r.clicks < 2 then raise exception 'FAIL 3b: clicks=% (want >= 2)', r.clicks; end if;
  if r.signups < 2 then raise exception 'FAIL 3c: signups=% (want >= 2)', r.signups; end if;
  if r.paid_users <> 0 then raise exception 'FAIL 3d: paid_users=% (want 0)', r.paid_users; end if;
  raise notice 'PASS 3: clicks and sign-ups are counted, paid accounts are 0';
end $$;

-- ------------------------------------------------------------------
-- 4. A paying devotee from a channel link IS counted as a paid conversion.
-- ------------------------------------------------------------------
do $$
declare r record; v_code text;
begin
  select code into v_code from public.referral_codes where channel = 'youtube' and is_channel;
  insert into public.referral_attributions (code, referrer_user_id, referred_user_id)
  select v_code, rc.user_id, 'chan_test_yt1' from public.referral_codes rc where rc.code = v_code
  on conflict (referred_user_id) do nothing;

  insert into public.play_subscriptions
    (user_id, product_id, status, current_start, current_end, subscription_id, last_event_name, event_ts)
  values ('chan_test_yt1', 'soulful_yearly', 'active', now(), now() + interval '300 days',
          'GPA.CHANTEST', 'initial_purchase', now())
  on conflict (user_id, product_id) do update set status = 'active';

  insert into public.referral_purchases
    (source_event_id, referred_user_id, order_id, product_id, rail, amount, occurred_at)
  values ('backfill:GPA.CHANTEST', 'chan_test_yt1', 'GPA.CHANTEST', 'soulful_yearly', 'play', 120, now())
  on conflict (source_event_id) do nothing;

  select * into r from public.admin_channel_summary() where channel = 'youtube';
  if r.paid_users < 1 then raise exception 'FAIL 4a: paid_users=% (want >= 1)', r.paid_users; end if;
  if coalesce(r.play_revenue, 0) < 120 then
    raise exception 'FAIL 4b: play_revenue=% (want >= 120)', r.play_revenue;
  end if;
  raise notice 'PASS 4: a paying devotee is counted, with the Play revenue';
end $$;

-- ------------------------------------------------------------------
-- 5. Channel identities stay out of the affiliate directory.
-- ------------------------------------------------------------------
do $$
declare n integer;
begin
  select count(*) into n
  from public.admin_affiliate_summary_v2(null, null, null, 200)
  where referrer_user_id like 'channel\_%';
  if n <> 0 then raise exception 'FAIL 5: % channel identities leaked into the affiliate list', n; end if;
  raise notice 'PASS 5: channel identities are not affiliates';
end $$;

rollback;
