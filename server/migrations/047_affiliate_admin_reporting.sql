-- ============================================================
-- MIGRATION 047: affiliate/referral administration data
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- WHY
--   The referral ledger (migrations 003/039/042/046) answers "what does ONE
--   referrer see on /account". The admin had no way to answer the business
--   questions:
--     * which affiliate brought which paying customer?
--     * what did that customer pay, on which rail, with which Play order id?
--     * is the ₹51 credited, and to whom exactly (email, not just a Clerk id)?
--     * which affiliates have joined friends but no paying ones?
--
--   Emails are not stored anywhere in this database (Clerk owns them), so the
--   server writes them into `user_directory` from Superwall's subscriber
--   attributes (and can backfill on demand). Play order ids are recorded in
--   `referral_purchases` from the webhook, and can be backfilled for orders
--   that arrived before the Play notifications were fixed.
--
-- WHAT THIS ADDS
--   * `user_directory`      – user_id -> email/name (service-role only)
--   * `referral_purchases`  – one row per store purchase a referred user made
--                            (order id, product, rail, amount, time)
--   * `admin_affiliate_summary(...)`  – one row per affiliate, filterable
--   * `admin_affiliate_referrals(...)` – drill-down for one affiliate
--   * `admin_order_backfill(...)` – record an order discovered outside the
--                                   webhook (e.g. from the Play Developer API)
--
-- WHAT IT DOES NOT CHANGE
--   * No existing table, function, index or grant is touched.
--   * The customer-facing /account card keeps reading
--     `referral_program_summary` exactly as before.
--   * Nothing in the Android app.
--
-- SAFETY
--   * Additive and re-runnable (if-not-exists / create-or-replace).
--   * Every new object is revoked from PUBLIC/anon/authenticated and granted
--     to service_role only: the Node server decides who may read it (admin
--     session), the browser can never query it directly.
-- ============================================================

-- ------------------------------------------------------------------
-- 1) User directory: the email/name an admin needs to identify a person.
--    Written by the server (Superwall subscriber attributes); never by a
--    client.
-- ------------------------------------------------------------------
create table if not exists public.user_directory (
  user_id    text primary key,          -- Clerk user id
  email      text,
  name       text,
  source     text,                      -- 'superwall-webhook' | 'superwall-api' | 'manual'
  updated_at timestamptz not null default now()
);

create index if not exists user_directory_email_idx on public.user_directory (lower(email));

alter table public.user_directory enable row level security;
revoke all on public.user_directory from anon, authenticated;
grant select, insert, update on public.user_directory to service_role;

-- ------------------------------------------------------------------
-- 2) Purchase audit: one row per store purchase made by a REFERRED user.
--    `source_event_id` is the webhook event id (idempotent re-delivery) or
--    'backfill:<order_id>' for an order recovered from the store's API.
-- ------------------------------------------------------------------
create table if not exists public.referral_purchases (
  source_event_id  text primary key,
  referred_user_id text not null,
  order_id         text,
  product_id       text not null,
  rail             text not null check (rail in ('play', 'web', 'other')),
  amount           numeric,
  status           text not null default 'processed',
  occurred_at      timestamptz not null default now(),
  created_at       timestamptz not null default now()
);

create index if not exists referral_purchases_referred_idx
  on public.referral_purchases (referred_user_id, occurred_at desc);
create index if not exists referral_purchases_order_idx
  on public.referral_purchases (order_id);

alter table public.referral_purchases enable row level security;
revoke all on public.referral_purchases from anon, authenticated;
grant select, insert, update on public.referral_purchases to service_role;

-- ------------------------------------------------------------------
-- 3) Entitlement snapshot for every referrer, from the any-rail reader
--    (migration 046) so the admin sees "is this affiliate still paying?"
--    exactly as the referral credit rule does.
-- ------------------------------------------------------------------
create or replace function public.admin_affiliate_entitlement()
returns table (referrer_user_id text, active boolean)
language sql
stable
security definer
set search_path = public
as $$
  select r.rid, coalesce(se.active, false) as active
  from (
    select distinct ra.referrer_user_id as rid from public.referral_attributions ra
    union
    select distinct c.referrer_user_id from public.commissions c
  ) r
  left join lateral (
    select a.active from public.subscription_entitlement_any_rail(r.rid) a limit 1
  ) se on true;
$$;

revoke execute on function public.admin_affiliate_entitlement() from public, anon, authenticated;
grant execute on function public.admin_affiliate_entitlement() to service_role;

-- ------------------------------------------------------------------
-- 4) Affiliate directory: one row per referrer, with the numbers an admin
--    filters on. `p_search` matches email, code or user id; `p_status`
--    ('pending'|'credited') and `p_rail` ('play'|'web') narrow the list to
--    affiliates that have at least one such commission.
-- ------------------------------------------------------------------
create or replace function public.admin_affiliate_summary(
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
  last_credit_at timestamptz
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
           coalesce(sum(c.commission_amount) filter (where c.status = 'pending'), 0) as pending,
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
    a.last_credit
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

revoke execute on function public.admin_affiliate_summary(text, text, text, integer) from public, anon, authenticated;
grant execute on function public.admin_affiliate_summary(text, text, text, integer) to service_role;

-- ------------------------------------------------------------------
-- 5) Per-affiliate drill-down: every friend, whether they paid, on which
--    rail, with the store order id, and the commission state.
-- ------------------------------------------------------------------
create or replace function public.admin_affiliate_referrals(p_referrer text)
returns table (
  referred_user_id text,
  email text,
  name text,
  attributed_at timestamptz,
  order_id text,
  product_id text,
  rail text,
  amount numeric,
  purchased_at timestamptz,
  commission_amount numeric,
  commission_status text,
  credited_at timestamptz,
  subscription_status text,
  subscription_end timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    ra.referred_user_id,
    ud.email,
    ud.name,
    ra.created_at as attributed_at,
    rp.order_id,
    coalesce(c.product_id, rp.product_id) as product_id,
    coalesce(rp.rail,
             case when c.product_id = 'razorpay_yearly' then 'web'
                  when c.product_id in ('soulful_yearly', 'soulful_monthly') then 'play'
                  else null end) as rail,
    rp.amount,
    rp.occurred_at as purchased_at,
    c.commission_amount,
    c.status as commission_status,
    c.created_at as credited_at,
    coalesce(ent.status, ent_rz.status) as subscription_status,
    coalesce(ent.current_end, ent_rz.current_end) as subscription_end
  from public.referral_attributions ra
  left join public.user_directory ud on ud.user_id = ra.referred_user_id
  left join public.commissions c on c.referred_user_id = ra.referred_user_id
  left join lateral (
    select p.order_id, p.product_id, p.rail, p.amount, p.occurred_at
    from public.referral_purchases p
    where p.referred_user_id = ra.referred_user_id
    order by p.occurred_at desc
    limit 1
  ) rp on true
  left join lateral (
    select ps.status, ps.current_end
    from public.play_subscriptions ps
    where ps.user_id = ra.referred_user_id
    order by ps.updated_at desc
    limit 1
  ) ent on true
  left join lateral (
    select rs.status, rs.current_end
    from public.razorpay_subscriptions rs
    where rs.user_id = ra.referred_user_id
    order by rs.created_at desc
    limit 1
  ) ent_rz on true
  where ra.referrer_user_id = p_referrer
  order by coalesce(rp.occurred_at, c.created_at, ra.created_at) desc;
$$;

revoke execute on function public.admin_affiliate_referrals(text) from public, anon, authenticated;
grant execute on function public.admin_affiliate_referrals(text) to service_role;

-- ------------------------------------------------------------------
-- 5) Backfill helper for orders discovered outside the webhook (the Play
--    Developer API resolves order id -> user id authoritatively). Idempotent:
--    the deterministic source_event_id makes a repeat a no-op.
-- ------------------------------------------------------------------
create or replace function public.admin_order_backfill(
  p_referred_user_id text,
  p_order_id text,
  p_product_id text,
  p_rail text,
  p_amount numeric,
  p_occurred_at timestamptz,
  p_status text default 'processed'
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_referred_user_id is null or p_order_id is null or p_product_id is null then
    raise exception 'referred_user_id, order_id and product_id are required';
  end if;
  if p_rail not in ('play', 'web', 'other') then
    raise exception 'rail must be play, web or other';
  end if;

  insert into public.referral_purchases (
    source_event_id, referred_user_id, order_id, product_id, rail, amount, status, occurred_at
  ) values (
    'backfill:' || p_order_id, p_referred_user_id, p_order_id, p_product_id, p_rail,
    p_amount, coalesce(p_status, 'processed'), coalesce(p_occurred_at, now())
  )
  on conflict (source_event_id) do update set
    referred_user_id = excluded.referred_user_id,
    product_id = excluded.product_id,
    rail = excluded.rail,
    amount = excluded.amount,
    status = excluded.status,
    occurred_at = excluded.occurred_at;

  return true;
end;
$$;

revoke execute on function public.admin_order_backfill(text, text, text, text, numeric, timestamptz, text) from public, anon, authenticated;
grant execute on function public.admin_order_backfill(text, text, text, text, numeric, timestamptz, text) to service_role;

-- ------------------------------------------------------------------
-- CONFIRM (read-only)
-- ------------------------------------------------------------------
select tablename from pg_tables
where schemaname = 'public' and tablename in ('user_directory', 'referral_purchases');

select p.proname
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('admin_affiliate_summary', 'admin_affiliate_referrals', 'admin_order_backfill')
order by p.proname;
