-- ============================================================
-- TEST: admin subscriptions by rail (migration 051)
--
-- Requires migrations 038, 046, 047, 049, 051.
-- Runs in one transaction and rolls back.
--
-- Usage (from server/):
--   psql "$PARTNER_TEST_DB_URL" -v ON_ERROR_STOP=1 -f test/admin_subscriptions.test.sql
-- ============================================================

begin;

-- ------------------------------------------------------------------
-- Fixtures: one Play subscriber (referred + credited), one web
-- subscriber (referred + credited), one Play subscriber who is expired
-- and not referred.
-- ------------------------------------------------------------------
insert into public.user_directory (user_id, email, name) values
  ('sub_play_user', 'play@example.com', 'Play Person'),
  ('sub_web_user', 'web@example.com', 'Web Person'),
  ('sub_dead_user', 'gone@example.com', 'Expired Person'),
  ('sub_ref', 'affiliate@example.com', 'Affiliate')
on conflict (user_id) do update set email = excluded.email;

insert into public.referral_codes (user_id, code) values ('sub_ref', 'SBRATEST001')
on conflict (user_id) do nothing;

insert into public.referral_attributions (code, referrer_user_id, referred_user_id) values
  ('SBRATEST001', 'sub_ref', 'sub_play_user'),
  ('SBRATEST001', 'sub_ref', 'sub_web_user')
on conflict (referred_user_id) do nothing;

insert into public.play_subscriptions
  (user_id, product_id, status, current_start, current_end, subscription_id, last_event_name, event_ts)
values
  ('sub_play_user', 'soulful_yearly', 'active', now() - interval '1 day', now() + interval '300 days', 'GPA.PLAY-0001', 'initial_purchase', now()),
  ('sub_dead_user', 'soulful_yearly', 'expired', now() - interval '400 days', now() - interval '35 days', 'GPA.DEAD-0001', 'expiration', now())
on conflict (user_id, product_id) do update set status = excluded.status, current_end = excluded.current_end;

insert into public.razorpay_subscriptions
  (subscription_id, user_id, plan_id, plan_slug, status, current_start, current_end)
values
  ('sub_test_web_051', 'sub_web_user', 'plan_test', 'yearly', 'active', now() - interval '1 day', now() + interval '300 days')
on conflict (subscription_id) do update set status = 'active';

insert into public.commissions
  (referrer_user_id, referred_user_id, product_id, plan_price, rate_percent, commission_amount, status, source_event_id)
values
  ('sub_ref', 'sub_play_user', 'soulful_yearly', 120, 0, 51, 'pending', 'evt_test_051_play'),
  ('sub_ref', 'sub_web_user', 'razorpay_yearly', 120, 0, 51, 'pending', 'evt_test_051_web')
on conflict (source_event_id) do nothing;

-- ------------------------------------------------------------------
-- 1. The rail filter actually separates the two stores.
-- ------------------------------------------------------------------
do $$
declare n integer;
begin
  select count(*) into n from public.admin_subscriptions('play', null, 'sub_play_user', 100);
  if n <> 1 then raise exception 'FAIL 1a: play filter returned % rows for the play user', n; end if;

  select count(*) into n from public.admin_subscriptions('web', null, 'sub_play_user', 100);
  if n <> 0 then raise exception 'FAIL 1b: a Play subscriber appeared under the web filter'; end if;

  select count(*) into n from public.admin_subscriptions('web', null, 'sub_web_user', 100);
  if n <> 1 then raise exception 'FAIL 1c: web filter returned % rows for the web user', n; end if;

  select count(*) into n from public.admin_subscriptions('play', null, 'sub_web_user', 100);
  if n <> 0 then raise exception 'FAIL 1d: a web subscriber appeared under the play filter'; end if;

  raise notice 'PASS 1: play and web lists are separate';
end $$;

-- ------------------------------------------------------------------
-- 2. Each row carries the email next to the Clerk id, the store reference,
--    the referrer and the commission.
-- ------------------------------------------------------------------
do $$
declare r record;
begin
  select * into r from public.admin_subscriptions('play', null, 'sub_play_user', 10);
  if r.email <> 'play@example.com' then raise exception 'FAIL 2a: email=%', r.email; end if;
  if r.store_ref <> 'GPA.PLAY-0001' then raise exception 'FAIL 2b: store_ref=%', r.store_ref; end if;
  if r.referrer_user_id <> 'sub_ref' then raise exception 'FAIL 2c: referrer=%', r.referrer_user_id; end if;
  if r.referrer_email <> 'affiliate@example.com' then raise exception 'FAIL 2d: referrer email=%', r.referrer_email; end if;
  if r.commission_amount <> 51 or r.commission_status <> 'pending' then
    raise exception 'FAIL 2e: commission %/%', r.commission_amount, r.commission_status;
  end if;
  if not r.is_active then raise exception 'FAIL 2f: active subscriber reported inactive'; end if;
  raise notice 'PASS 2: email, store ref, referrer and commission are all present';
end $$;

-- ------------------------------------------------------------------
-- 3. Status filter: an expired, unreferred Play row is inactive and unlinked.
-- ------------------------------------------------------------------
do $$
declare r record; n integer;
begin
  select count(*) into n from public.admin_subscriptions('play', 'active', 'sub_dead_user', 100);
  if n <> 0 then raise exception 'FAIL 3a: an expired subscription appeared under active'; end if;

  select * into r from public.admin_subscriptions('play', 'inactive', 'sub_dead_user', 10);
  if r is null then raise exception 'FAIL 3b: the expired row is missing from inactive'; end if;
  if r.referrer_user_id is not null or r.commission_amount is not null then
    raise exception 'FAIL 3c: an unreferred row must carry no referrer and no commission';
  end if;
  raise notice 'PASS 3: status filter and the unreferred case behave';
end $$;

-- ------------------------------------------------------------------
-- 4. Search works by email and by store reference.
-- ------------------------------------------------------------------
do $$
declare n integer;
begin
  select count(*) into n from public.admin_subscriptions(null, null, 'play@example.com', 100);
  if n <> 1 then raise exception 'FAIL 4a: email search returned %', n; end if;

  select count(*) into n from public.admin_subscriptions(null, null, 'GPA.PLAY-0001', 100);
  if n <> 1 then raise exception 'FAIL 4b: store-reference search returned %', n; end if;

  select count(*) into n from public.admin_subscriptions(null, null, 'affiliate@example.com', 100);
  if n < 2 then raise exception 'FAIL 4c: referrer-email search returned %', n; end if;

  raise notice 'PASS 4: search by email, reference and referrer';
end $$;

-- ------------------------------------------------------------------
-- 5. No rail filter returns both rails.
-- ------------------------------------------------------------------
do $$
declare n integer;
begin
  select count(*) into n from public.admin_subscriptions(null, null, 'sub_', 100);
  if n < 3 then raise exception 'FAIL 5: unfiltered list returned % rows (want >= 3)', n; end if;
  raise notice 'PASS 5: no rail filter shows both stores';
end $$;

rollback;
