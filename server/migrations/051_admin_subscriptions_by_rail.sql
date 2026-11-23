-- ============================================================
-- MIGRATION 051: one place to list every subscription, by rail
-- Run this in the Supabase SQL editor. NO DESTRUCTIVE STATEMENTS
-- (read-only function; no DROP / UPDATE / DELETE / ALTER).
--
-- WHY
--   Two rails write entitlement rows and they live in separate tables:
--     * Google Play (Android app)  -> public.play_subscriptions
--     * Razorpay (web app)         -> public.razorpay_subscriptions
--   Support and reconciliation need ONE list where the rail is a filter, with
--   the customer's email next to the Clerk id, the store reference, who referred
--   them, and the ₹51 state. Without this, answering "show me only the Play
--   subscribers" means writing SQL by hand.
--
-- WHAT THIS ADDS
--   * admin_subscriptions(p_rail, p_status, p_search, p_limit):
--       p_rail    'play' | 'web' | null (both)
--       p_status  'active' | 'inactive' | null (both)
--       p_search  matches email, Clerk id or the store reference (order id /
--                 Razorpay subscription id)
--     One row per subscription (a customer who bought on both rails appears
--     once per rail, which is the truth and is what reconciliation needs).
--   * is_active mirrors the entitlement rules already enforced elsewhere:
--       Play:  active                     -> yes (open-ended unless end set)
--              cancelled / paused        -> until current_end
--              expired / refunded        -> no
--       Web:   active / authenticated     -> yes
--              pending                   -> until current_end + 72 h
--              cancelled / halted        -> until current_end
--              anything else             -> no
--
-- POLICY NOTE
--   Read-only reporting over data this system already stores. It touches no
--   Google Play billing, no Play Developer API and no customer-facing flow; the
--   Play rows it reads were written from verified store events only.
--
-- SAFETY
--   * Function only: nothing is created, altered or removed.
--   * SECURITY DEFINER + pinned search_path; EXECUTE revoked from
--     PUBLIC/anon/authenticated, granted to service_role. The browser can only
--     reach it through the admin-guarded endpoint.
-- ============================================================

create or replace function public.admin_subscriptions(
  p_rail text default null,
  p_status text default null,
  p_search text default null,
  p_limit integer default 200
)
returns table (
  customer_user_id text,
  email text,
  name text,
  rail text,
  product_id text,
  status text,
  is_active boolean,
  current_start timestamptz,
  current_end timestamptz,
  store_ref text,
  referrer_user_id text,
  referrer_email text,
  commission_amount numeric,
  commission_status text,
  credited_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  with play as (
    select
      ps.user_id,
      'play'::text as rail,
      ps.product_id,
      ps.status,
      (
        (ps.status = 'active' and (ps.current_end is null or ps.current_end >= now()))
        or (ps.status in ('cancelled', 'paused') and coalesce(ps.current_end, now()) >= now())
      ) as is_active,
      ps.current_start,
      ps.current_end,
      coalesce(ps.subscription_id, ps.last_event_id) as store_ref,
      ps.updated_at as touched_at
    from public.play_subscriptions ps
  ),
  web as (
    select
      rs.user_id,
      'web'::text as rail,
      rs.plan_slug as product_id,
      rs.status,
      (
        rs.status in ('active', 'authenticated')
        or (rs.status = 'pending' and coalesce(rs.current_end, now()) + interval '72 hours' > now())
        or (rs.status in ('cancelled', 'halted') and coalesce(rs.current_end, now()) > now())
      ) as is_active,
      rs.current_start,
      rs.current_end,
      rs.subscription_id as store_ref,
      rs.updated_at as touched_at
    from public.razorpay_subscriptions rs
  ),
  every_subscription as (
    select * from play
    union all
    select * from web
  )
  select
    s.user_id as customer_user_id,
    ud.email,
    ud.name,
    s.rail,
    s.product_id,
    s.status,
    s.is_active,
    s.current_start,
    s.current_end,
    s.store_ref,
    ra.referrer_user_id,
    ur.email as referrer_email,
    c.commission_amount,
    c.status as commission_status,
    c.created_at as credited_at
  from every_subscription s
  left join public.user_directory ud on ud.user_id = s.user_id
  left join public.referral_attributions ra on ra.referred_user_id = s.user_id
  left join public.user_directory ur on ur.user_id = ra.referrer_user_id
  left join public.commissions c on c.referred_user_id = s.user_id
  where (p_rail is null or p_rail = '' or s.rail = p_rail)
    and (
      p_status is null or p_status = ''
      or (p_status = 'active' and s.is_active)
      or (p_status = 'inactive' and not s.is_active)
    )
    and (
      p_search is null or p_search = ''
      or ud.email ilike '%' || p_search || '%'
      or s.user_id ilike '%' || p_search || '%'
      or coalesce(s.store_ref, '') ilike '%' || p_search || '%'
      or coalesce(ur.email, '') ilike '%' || p_search || '%'
    )
  order by s.is_active desc, s.current_end desc nulls last, s.user_id
  limit coalesce(nullif(p_limit, 0), 200);
$$;

revoke execute on function public.admin_subscriptions(text, text, text, integer) from public, anon, authenticated;
grant execute on function public.admin_subscriptions(text, text, text, integer) to service_role;

-- ------------------------------------------------------------------
-- CONFIRM (read-only): counts per rail, so the two lists are provably split.
-- ------------------------------------------------------------------
select rail,
       count(*)                                            as subscriptions,
       count(*) filter (where is_active)                    as active,
       count(*) filter (where commission_amount is not null) as with_commission
from public.admin_subscriptions(null, null, null, 1000)
group by rail
order by rail;
