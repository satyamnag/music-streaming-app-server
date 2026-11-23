-- ============================================================
-- MIGRATION 049: one owner per Google Play subscription
-- Run this in the Supabase SQL editor.
--
-- WHY
--   A Google Play subscription belongs to the Google account on the device,
--   not to the app account. When two Clerk accounts sign in on the same device
--   (a shared phone, a family Play account, or a tester switching accounts),
--   Superwall reports the SAME subscription for both, and the Play API sync
--   would therefore write an "active" row for each of them: two paying-looking
--   accounts for one ₹120 purchase.
--
--   The entitlement must follow the ACCOUNT THAT BOUGHT IT. This migration adds
--   the subscription id to the row and refuses to grant a subscription that is
--   already entitled for a different account. Nothing in the Android app
--   changes: the app keeps calling the same endpoints.
--
-- WHAT IS ALLOWED
--   * The first account that holds the subscription keeps it.
--   * A genuine change of owner (Superwall's `transferred` event) still works:
--     that path cancels the previous owner's row first, so the new owner can
--     claim it.
--   * A renewal simply updates the existing owner's row.
--
-- SAFETY
--   * Additive column + index, and one function replaced with a superset
--     signature (one extra DEFAULT NULL argument), so an old caller that omits
--     the id behaves exactly as before.
--   * No row is deleted or modified by this migration.
-- ============================================================

-- ------------------------------------------------------------------
-- 1) The subscription id on the row (the Play order / original transaction id,
--    e.g. GPA.3349-8814-0784-50213).
-- ------------------------------------------------------------------
alter table public.play_subscriptions
  add column if not exists subscription_id text;

create index if not exists play_subscriptions_subscription_id_idx
  on public.play_subscriptions (subscription_id);

-- ------------------------------------------------------------------
-- 2) Recreate the guarded upsert with an optional subscription id and the
--    one-owner rule. Same behaviour as migration 046 when the id is omitted.
-- ------------------------------------------------------------------
drop function if exists public.play_subscription_upsert(
  text, text, text, timestamptz, timestamptz, text, text, text, text, timestamptz, jsonb
);

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
  p_subscription_id text default null
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
  -- account, do not grant it here: the purchase belongs to that account. The
  -- check looks only at rows that still grant access, so a completed transfer
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

revoke execute on function public.play_subscription_upsert(text, text, text, timestamptz, timestamptz, text, text, text, text, timestamptz, jsonb, text) from public, anon, authenticated;
grant execute on function public.play_subscription_upsert(text, text, text, timestamptz, timestamptz, text, text, text, text, timestamptz, jsonb, text)
  to service_role;

-- ------------------------------------------------------------------
-- CONFIRM (read-only)
-- ------------------------------------------------------------------
select column_name from information_schema.columns
where table_schema = 'public' and table_name = 'play_subscriptions' and column_name = 'subscription_id';

select indexname from pg_indexes
where schemaname = 'public' and indexname = 'play_subscriptions_subscription_id_idx';
