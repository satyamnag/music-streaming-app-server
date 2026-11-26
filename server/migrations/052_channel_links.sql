-- ============================================================
-- MIGRATION 052: company-owned channel links (Facebook / Instagram / YouTube)
-- Run this in the Supabase SQL editor.
--
-- WHAT THESE LINKS ARE
--   Three brand-owned invite links, one per traffic source. They are NOT
--   affiliate links: nobody earns ₹51 from them. What they do is make each
--   channel measurable - clicks, sign-ups and paid conversions, per channel -
--   which is the "meaningful" number that replaces the rupee figure.
--
-- HOW ATTRIBUTION STAYS HONEST
--   The Android app reads the referral code from `utm_source` (verified in
--   ReferrerBridge.parseUtmSource). A channel link therefore carries a channel
--   code as utm_source, plus utm_medium/utm_campaign for the traffic source.
--   That code lives in `referral_codes` (is_channel = true) owned by a
--   dedicated non-Clerk identity (`channel_facebook`, ...). Consequences:
--     * a sign-up through it IS recorded (referral_attributions), so we can
--       count sign-ups per channel;
--     * it can never pay ₹51, because the credit rule requires the referrer to
--       be an active subscriber and a `channel_*` identity never is - no code
--       change is needed to suppress the reward;
--     * it cannot pollute the affiliate directory: the affiliate summaries now
--       exclude channel codes.
--
-- NO DESTRUCTIVE STATEMENTS: additive columns, one table, one index, seeded
-- rows for three brand codes, and read-only functions. No DROP/DELETE.
-- ============================================================

-- ------------------------------------------------------------------
-- 1) Channel metadata on a referral code.
-- ------------------------------------------------------------------
alter table public.referral_codes add column if not exists channel text;
alter table public.referral_codes add column if not exists is_channel boolean not null default false;

create index if not exists referral_codes_channel_idx
  on public.referral_codes (channel) where is_channel;

-- ------------------------------------------------------------------
-- 2) Click log: one row per visit to a channel link. No PII is stored - only
--    the channel, the code and when the click happened.
-- ------------------------------------------------------------------
create table if not exists public.referral_channel_clicks (
  id          uuid primary key default gen_random_uuid(),
  channel     text not null check (channel in ('facebook', 'instagram', 'youtube')),
  code        text not null,
  source_path text,
  created_at  timestamptz not null default now()
);

create index if not exists referral_channel_clicks_channel_idx
  on public.referral_channel_clicks (channel, created_at desc);

alter table public.referral_channel_clicks enable row level security;
revoke all on public.referral_channel_clicks from anon, authenticated;
grant select, insert on public.referral_channel_clicks to service_role;

-- ------------------------------------------------------------------
-- 3) The three brand codes. Idempotent: re-running changes nothing.
--    `channel_*` identities are deliberately NOT Clerk ids, so they can never
--    satisfy the "referrer must be an active subscriber" rule.
-- ------------------------------------------------------------------
insert into public.referral_codes (user_id, code, channel, is_channel) values
  ('channel_facebook',  'SBFBORG', 'facebook',  true),
  ('channel_instagram', 'SBIGORG', 'instagram', true),
  ('channel_youtube',   'SBYTORG', 'youtube',   true)
on conflict (code) do update
  set channel = excluded.channel,
      is_channel = true;

-- ------------------------------------------------------------------
-- 4) Per-channel report: clicks, sign-ups, paying accounts, Play revenue.
-- ------------------------------------------------------------------
create or replace function public.admin_channel_summary()
returns table (
  channel text,
  code text,
  clicks bigint,
  signups bigint,
  paid_users bigint,
  play_revenue numeric,
  last_click_at timestamptz,
  last_signup_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    rc.channel,
    rc.code,
    (select count(*) from public.referral_channel_clicks k where k.channel = rc.channel)::bigint as clicks,
    (select count(*) from public.referral_attributions ra where ra.code = rc.code)::bigint as signups,
    (
      select count(distinct ra.referred_user_id)
      from public.referral_attributions ra
      where ra.code = rc.code
        and (
          exists (
            select 1 from public.play_subscriptions ps
            where ps.user_id = ra.referred_user_id
              and ps.status = 'active'
              and (ps.current_end is null or ps.current_end >= now())
          )
          or exists (
            select 1 from public.razorpay_subscriptions rs
            where rs.user_id = ra.referred_user_id
              and (
                rs.status in ('active', 'authenticated')
                or (rs.status in ('pending', 'cancelled', 'halted')
                    and coalesce(rs.current_end, now()) >= now())
              )
          )
        )
    )::bigint as paid_users,
    coalesce((
      select sum(p.amount)
      from public.referral_purchases p
      join public.referral_attributions ra on ra.referred_user_id = p.referred_user_id
      where ra.code = rc.code and p.rail = 'play'
    ), 0) as play_revenue,
    (select max(k.created_at) from public.referral_channel_clicks k where k.channel = rc.channel) as last_click_at,
    (select max(ra.created_at) from public.referral_attributions ra where ra.code = rc.code) as last_signup_at
  from public.referral_codes rc
  where rc.is_channel
  order by rc.channel;
$$;

revoke execute on function public.admin_channel_summary() from public, anon, authenticated;
grant execute on function public.admin_channel_summary() to service_role;

-- ------------------------------------------------------------------
-- 5) Keep channel identities out of the affiliate directory: they are
--    campaigns, not people who can earn. Same signature as before, so this is
--    a replace, not a new object.
-- ------------------------------------------------------------------
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
  with channel_identities as (
    select distinct rc.user_id
    from public.referral_codes rc
    where rc.is_channel
  ),
  friends as (
    select ra.referrer_user_id as rid, count(*)::bigint as n
    from public.referral_attributions ra
    where ra.referrer_user_id not in (select user_id from channel_identities)
    group by 1
  ),
  agg as (
    select c.referrer_user_id as rid,
           count(*) filter (
             where c.product_id in ('soulful_yearly', 'soulful_monthly', 'razorpay_yearly')
           )::bigint as paid,
           count(*) filter (where c.product_id in ('soulful_yearly', 'soulful_monthly'))::bigint as paid_play,
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
    where c.referrer_user_id not in (select user_id from channel_identities)
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
  left join public.referral_codes rc on rc.user_id = coalesce(f.rid, a.rid) and not rc.is_channel
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
-- CONFIRM (read-only)
-- ------------------------------------------------------------------
select code, channel, is_channel from public.referral_codes where is_channel order by channel;
select * from public.admin_channel_summary();
