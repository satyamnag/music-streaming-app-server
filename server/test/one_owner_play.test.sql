-- ============================================================
-- TEST: one owner per Google Play subscription (migration 049)
--
-- Requires migrations 038, 046, 047, 048 and 049.
-- Runs in one transaction and rolls back.
--
-- Usage (from server/):
--   psql "$PARTNER_TEST_DB_URL" -v ON_ERROR_STOP=1 -f test/one_owner_play.test.sql
-- ============================================================

begin;

-- ------------------------------------------------------------------
-- 1. The first account claims the subscription and keeps it.
-- ------------------------------------------------------------------
do $$
declare r record;
begin
  perform public.play_subscription_upsert(
    'owner_A', 'soulful_yearly', 'active',
    now() - interval '1 day', now() + interval '300 days',
    'PLAY_STORE', 'PRODUCTION', 'evt_a1', 'initial_purchase', now(),
    '{}'::jsonb, 'GPA.OWNER-0001'
  );

  select user_id, status, subscription_id into r
  from public.play_subscriptions where user_id = 'owner_A';

  if r.status <> 'active' or r.subscription_id <> 'GPA.OWNER-0001' then
    raise exception 'FAIL 1: owner row wrong (% / %)', r.status, r.subscription_id;
  end if;
  raise notice 'PASS 1: first account owns the subscription';
end $$;

-- ------------------------------------------------------------------
-- 2. A SECOND account on the same Play subscription is refused.
--    (This is the shared-device case: one ₹120 purchase must not entitle
--    two app accounts.)
-- ------------------------------------------------------------------
do $$
declare n integer;
begin
  perform public.play_subscription_upsert(
    'owner_B', 'soulful_yearly', 'active',
    now() - interval '1 day', now() + interval '300 days',
    'PLAY_STORE', 'PRODUCTION', 'evt_b1', 'initial_purchase',
    now() + interval '1 second', '{}'::jsonb, 'GPA.OWNER-0001'
  );

  select count(*) into n from public.play_subscriptions
  where user_id = 'owner_B' and status = 'active';

  if n <> 0 then
    raise exception 'FAIL 2: the second account was granted a subscription it does not own';
  end if;
  raise notice 'PASS 2: a shared Play subscription does not entitle a second account';
end $$;

-- ------------------------------------------------------------------
-- 3. A renewal by the real owner still updates normally.
-- ------------------------------------------------------------------
do $$
declare r record;
begin
  perform public.play_subscription_upsert(
    'owner_A', 'soulful_yearly', 'active',
    now() - interval '1 day', now() + interval '660 days',
    'PLAY_STORE', 'PRODUCTION', 'evt_a2', 'renewal',
    now() + interval '2 seconds', '{}'::jsonb, 'GPA.OWNER-0001'
  );

  select status, current_end into r from public.play_subscriptions where user_id = 'owner_A';
  if r.current_end < now() + interval '600 days' then
    raise exception 'FAIL 3: renewal did not extend the owner row';
  end if;
  raise notice 'PASS 3: renewals keep working for the owner';
end $$;

-- ------------------------------------------------------------------
-- 4. A genuine transfer (previous owner ended first) IS allowed.
-- ------------------------------------------------------------------
do $$
declare n integer;
begin
  -- what the `transferred` path does: retire the previous row at the switch
  perform public.play_subscription_upsert(
    'owner_A', 'soulful_yearly', 'cancelled',
    null, now() - interval '1 second',
    'PLAY_STORE', 'PRODUCTION', 'evt_t1', 'transferred',
    now() + interval '3 seconds', '{}'::jsonb, 'GPA.OWNER-0001'
  );

  perform public.play_subscription_upsert(
    'owner_C', 'soulful_yearly', 'active',
    now(), now() + interval '300 days',
    'PLAY_STORE', 'PRODUCTION', 'evt_t2', 'transferred',
    now() + interval '4 seconds', '{}'::jsonb, 'GPA.OWNER-0001'
  );

  select count(*) into n from public.play_subscriptions
  where user_id = 'owner_C' and status = 'active';
  if n <> 1 then
    raise exception 'FAIL 4: a completed transfer did not move the subscription';
  end if;
  raise notice 'PASS 4: a real transfer moves ownership';
end $$;

-- ------------------------------------------------------------------
-- 5. Omitting the subscription id keeps the migration-046 behaviour
--    (an old caller must not break).
-- ------------------------------------------------------------------
do $$
declare n integer;
begin
  perform public.play_subscription_upsert(
    'owner_D', 'soulful_yearly', 'active',
    now(), now() + interval '30 days',
    'PLAY_STORE', 'PRODUCTION', 'evt_d1', 'initial_purchase', now(), '{}'::jsonb
  );
  select count(*) into n from public.play_subscriptions
  where user_id = 'owner_D' and status = 'active';
  if n <> 1 then
    raise exception 'FAIL 5: the id-less call stopped working';
  end if;
  raise notice 'PASS 5: callers that omit the subscription id still work';
end $$;

rollback;
