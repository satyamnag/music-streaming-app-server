-- ============================================================
-- MIGRATION 050: split the affiliate numbers by rail (Play vs web)
-- Run this in the Supabase SQL editor. NO DESTRUCTIVE STATEMENTS.
--
-- WHY
--   A commission arrives from one of two rails:
--     * Google Play (Android app)  -> commissions.product_id = 'soulful_yearly'
--                                     (or 'soulful_monthly')
--     * Razorpay (web app)         -> commissions.product_id = 'razorpay_yearly'
--   The totals alone cannot answer "how many of this affiliate's paying friends
--   came from the app, and how many from the web?", which is needed for
--   reconciliation: the Play count must equal the Play orders, and the web count
--   must equal the Razorpay subscriptions. Two rails, one ₹51 rule each.
--
-- WHAT THIS ADDS
--   * admin_affiliate_summary_v2(): the same rows and filters as
--     admin_affiliate_summary(), plus paid_play, paid_web, pending_play and
--     pending_web. A NEW function name, so nothing is dropped or replaced and no
--     caller of the old function breaks.
--
-- SAFETY
--   * Additive only: read-only SQL function, service_role execution.
--   * The old function stays exactly as it is.
-- ============================================================

create or replace function public.admin_affiliate_summary_v2(
  p_search text default null,
  p_status text default null,
  p_rail text default null,
  p_limit integer default 200
)
returns table (
  referrer_user_id text,
  code text,
  email text,
  name text,
  is_active boolean,
  friends_joined bigint,
  paid_friends bigint,
  pending_amount numeric,
  settled_amount numeric,
  total_amount numeric,
  last_credit_at timestamptz,
  paid_play bigint,
  paid_web bigint,
  pending_play numeric,
  pending_web numeric
)
language sql
stable
security definer
set search_path = public
as $$
  with friends as (
    select ra.referrer_user_id as rid, count(*)::bigint as n
    from public.referral_attributions ra
    group by 1
  ),
  agg as (
    select c.referrer_user_id as rid,
           count(*) filter (
             where c.product_id in ('soulful_yearly', 'soulful_monthly', 'razorpay_yearly')
           )::bigint as paid,
           count(*) filter (
             where c.product_id in ('soulful_yearly', 'soulful_monthly')
           )::bigint as paid_play,
           count(*) filter (where c.product_id = 'razorpay_yearly')::bigint as paid_web,
           coalesce(sum(c.commission_amount) filter (where c.status = 'pending'), 0) as pending,
           coalesce(sum(c.commission_amount) filter (
             where c.status = 'pending' and c.product_id in ('soulful_yearly', 'soulful_monthly')
           ), 0) as pending_play,
           coalesce(sum(c.commission_amount) filter (
             where c.status = 'pending' and c.product_id = 'razorpay_yearly'
           ), 0) as pending_web,
           coalesce(sum(c.commission_amount) filter (where c.status in ('credited', 'paid')), 0) as settled,
           coalesce(sum(c.commission_amount), 0) as total,
           max(c.created_at) as last_credit,
           bool_or(c.status = 'pending') as has_pending,
           bool_or(c.status in ('credited', 'paid')) as has_credited,
           bool_or(c.product_id = 'razorpay_yearly') as has_web,
           bool_or(c.product_id in ('soulful_yearly', 'soulful_monthly')) as has_play
    from public.commissions c
    group by 1
  ),
  ent as (
    select * from public.admin_affiliate_entitlement()
  )
  select
    coalesce(f.rid, a.rid) as referrer_user_id,
    rc.code,
    ud.email,
    ud.name,
    coalesce(se.active, false) as is_active,
    coalesce(f.n, 0)::bigint as friends_joined,
    coalesce(a.paid, 0)::bigint as paid_friends,
    coalesce(a.pending, 0) as pending_amount,
    coalesce(a.settled, 0) as settled_amount,
    coalesce(a.total, 0) as total_amount,
    a.last_credit,
    coalesce(a.paid_play, 0)::bigint as paid_play,
    coalesce(a.paid_web, 0)::bigint as paid_web,
    coalesce(a.pending_play, 0) as pending_play,
    coalesce(a.pending_web, 0) as pending_web
  from friends f
  full join agg a on a.rid = f.rid
  left join public.referral_codes rc on rc.user_id = coalesce(f.rid, a.rid)
  left join public.user_directory ud on ud.user_id = coalesce(f.rid, a.rid)
  left join ent se on se.referrer_user_id = coalesce(f.rid, a.rid)
  where coalesce(f.rid, a.rid) is not null
    and (
      p_search is null or p_search = ''
      or ud.email ilike '%' || p_search || '%'
      or rc.code ilike '%' || p_search || '%'
      or coalesce(f.rid, a.rid) ilike '%' || p_search || '%'
    )
    and (p_status is null or p_status = '' or (p_status = 'pending' and coalesce(a.has_pending, false))
                                       or (p_status = 'credited' and coalesce(a.has_credited, false)))
    and (p_rail is null or p_rail = '' or (p_rail = 'web' and coalesce(a.has_web, false))
                                     or (p_rail = 'play' and coalesce(a.has_play, false)))
  order by coalesce(a.total, 0) desc, coalesce(f.n, 0) desc
  limit coalesce(nullif(p_limit, 0), 200);
$$;

revoke execute on function public.admin_affiliate_summary_v2(text, text, text, integer) from public, anon, authenticated;
grant execute on function public.admin_affiliate_summary_v2(text, text, text, integer) to service_role;

-- ------------------------------------------------------------------
-- CONFIRM (read-only): the rail split for the three known affiliates.
-- ------------------------------------------------------------------
select referrer_user_id, email, paid_friends, paid_play, paid_web,
       pending_amount, pending_play, pending_web
from public.admin_affiliate_summary_v2(null, null, null, 50);
