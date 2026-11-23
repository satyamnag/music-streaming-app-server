-- ============================================================
-- MIGRATION 049: one owner per Google Play subscription
-- Run this in the Supabase SQL editor.
--
-- NO DESTRUCTIVE STATEMENTS. This file contains no DROP, DELETE, TRUNCATE or
-- UPDATE: it only adds a column, an index and two functions. The previous
-- draft dropped the old function to change its signature; instead the signature
-- is extended by OVERLOADING, so both versions exist and the older one is
-- replaced in place with a thin wrapper.
--
-- WHY
--   A Google Play subscription belongs to the Google account on the device, not
--   to the app account. When two Clerk accounts sign in on the same device (a
--   shared phone, a family Play account, a tester switching accounts),
--   Superwall reports the SAME subscription for both, and the Play API sync
--   would write an "active" row for each: two paying-looking accounts for one
--   ₹120 purchase.
--
--   The entitlement must follow the ACCOUNT THAT BOUGHT IT. This migration adds
--   the store subscription id to the row and refuses to grant a subscription
--   that is already entitled for a different account. Nothing in the Android
--   app changes.
--
-- WHAT IS ALLOWED
--   * The first account holding the subscription keeps it.
--   * A genuine change of owner (Superwall's `transferred` event) still works:
--     that path retires the previous row first, so the new owner can claim it.
--   * A renewal simply updates the existing owner's row.
-- ============================================================

-- ------------------------------------------------------------------
-- 1) The store subscription id on the row (Play order / original transaction
--    id, e.g. GPA.3349-8814-0784-50213). Additive and nullable: existing rows
--    are untouched and simply have no id until a webhook, the sync, or the ops
--    script supplies one.
-- ------------------------------------------------------------------
alter table public.play_subscriptions
  add column if not exists subscription_id text;

create index if not exists play_subscriptions_subscription_id_idx
  on public.play_subscriptions (subscription_id);

-- ------------------------------------------------------------------
-- 2) The guarded implementation, with the subscription id as a 12th argument.
--    A NEW signature is created; nothing is dropped.
-- ------------------------------------------------------------------
create or replace function public.play_subscription_upsert(
  p_user_id text,
  p_product_id text,
  p_status text,
  p_current_start timestamptz,
  p_current_end timestamptz,
  p_store text,
  p_environment text,
  p_last_event_id text,
  p_last_event_name text,
  p_event_ts timestamptz,
  p_raw jsonb,
  p_subscription_id text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_other_owner text;
begin
  if p_user_id is null or p_user_id = '' or p_product_id is null or p_product_id = '' then
    raise exception 'user_id and product_id are required';
  end if;

  -- ONE OWNER. If this store subscription is currently entitled for a DIFFERENT
  -- account, do not grant it here: the purchase belongs to that account. Only
  -- rows that still grant access are considered, so a completed transfer
  -- (previous row cancelled and ended) does not block the new owner.
  if p_subscription_id is not null and p_subscription_id <> '' then
    select ps.user_id into v_other_owner
    from public.play_subscriptions ps
    where ps.subscription_id = p_subscription_id
      and ps.user_id <> p_user_id
      and ps.status = 'active'
      and (ps.current_end is null or ps.current_end >= now())
    limit 1;

    if v_other_owner is not null then
      raise notice
        'play_subscription_upsert: subscription % already owned by %; refusing to grant it to %',
        p_subscription_id, v_other_owner, p_user_id;
      return;
    end if;
  end if;

  insert into public.play_subscriptions (
    user_id, product_id, status, current_start, current_end, store, environment,
    last_event_id, last_event_name, event_ts, raw, subscription_id
  ) values (
    p_user_id, p_product_id, p_status, p_current_start, p_current_end, p_store,
    p_environment, p_last_event_id, p_last_event_name, p_event_ts,
    coalesce(p_raw, '{}'::jsonb), nullif(p_subscription_id, '')
  )
  on conflict (user_id, product_id) do update set
    status = excluded.status,
    current_start = coalesce(excluded.current_start, play_subscriptions.current_start),
    current_end = excluded.current_end,
    store = excluded.store,
    environment = excluded.environment,
    last_event_id = excluded.last_event_id,
    last_event_name = excluded.last_event_name,
    event_ts = excluded.event_ts,
    raw = excluded.raw,
    subscription_id = coalesce(excluded.subscription_id, play_subscriptions.subscription_id),
    updated_at = now()
  where play_subscriptions.event_ts is null
     or excluded.event_ts >= play_subscriptions.event_ts;
end;
$$;

revoke execute on function public.play_subscription_upsert(
  text, text, text, timestamptz, timestamptz, text, text, text, text, timestamptz, jsonb, text
) from public, anon, authenticated;
grant execute on function public.play_subscription_upsert(
  text, text, text, timestamptz, timestamptz, text, text, text, text, timestamptz, jsonb, text
) to service_role;

-- ------------------------------------------------------------------
-- 3) The original 11-argument signature is REPLACED IN PLACE (no DROP) with a
--    thin wrapper, so a caller still using it keeps working:
--      * the deployed server now sends the id (12 arguments) and gets the guard;
--      * an older in-flight deployment sending 11 arguments still writes state,
--        exactly as before this migration.
-- ------------------------------------------------------------------
create or replace function public.play_subscription_upsert(
  p_user_id text,
  p_product_id text,
  p_status text,
  p_current_start timestamptz,
  p_current_end timestamptz,
  p_store text,
  p_environment text,
  p_last_event_id text,
  p_last_event_name text,
  p_event_ts timestamptz,
  p_raw jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.play_subscription_upsert(
    p_user_id, p_product_id, p_status, p_current_start, p_current_end,
    p_store, p_environment, p_last_event_id, p_last_event_name, p_event_ts,
    p_raw, null::text
  );
end;
$$;

revoke execute on function public.play_subscription_upsert(
  text, text, text, timestamptz, timestamptz, text, text, text, text, timestamptz, jsonb
) from public, anon, authenticated;
grant execute on function public.play_subscription_upsert(
  text, text, text, timestamptz, timestamptz, text, text, text, text, timestamptz, jsonb
) to service_role;

-- ------------------------------------------------------------------
-- CONFIRM (read-only)
-- ------------------------------------------------------------------
select column_name from information_schema.columns
where table_schema = 'public' and table_name = 'play_subscriptions' and column_name = 'subscription_id';

select indexname from pg_indexes
where schemaname = 'public' and indexname = 'play_subscriptions_subscription_id_idx';

-- Both signatures must appear: 11 args (wrapper) and 12 args (guarded).
select p.proname,
       pg_get_function_arguments(p.oid) as args
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'play_subscription_upsert'
order by pg_get_function_arguments(p.oid);
