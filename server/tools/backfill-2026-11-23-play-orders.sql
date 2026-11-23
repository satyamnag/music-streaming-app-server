-- ============================================================
-- ONE-OFF RECONCILIATION: the seven Play orders of 19–23 Nov 2026
--
-- WHY THIS FILE EXISTS
--   Between 19 and 23 Nov 2026, seven real Google Play purchases (₹120 each,
--   annual) completed while Google Play's real-time notifications were not
--   reaching Superwall, so neither the entitlement nor the referral credit was
--   ever written for six of them. Superwall only learned about two of them once
--   the notification pipe was fixed.
--
--   The order -> buyer mapping in this file was resolved from the OFFICIAL
--   Google Play Developer API (orders.get -> purchaseToken ->
--   purchases.subscriptionsv2.get -> externalAccountIdentifiers.
--   obfuscatedExternalAccountId, the id the app passes to Play), not guessed.
--
-- HOW TO RUN
--   Supabase SQL Editor, after migrations 047 and 048 are applied.
--   Everything here is idempotent: re-running changes nothing and never
--   duplicates a commission (048 enforces one per referred user).
--
-- WHAT IT DOES NOT DO
--   * It does not touch the store, the app, or any Play data. Read-only on the
--     Play side; writes only to this database.
--   * It writes no money: commissions stay 'pending' (track-only ledger).
-- ============================================================

-- ------------------------------------------------------------------
-- 0) Preconditions: 047 and 048 must be in place.
--    If this block raises, apply those migrations first.
-- ------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'admin_affiliate_summary'
  ) then
    raise exception 'Migration 047 is missing: apply 047_affiliate_admin_reporting.sql first';
  end if;
  if not exists (
    select 1 from pg_indexes
    where schemaname = 'public' and indexname = 'commissions_one_per_referred_idx'
  ) then
    raise exception 'Migration 048 is missing: apply 048_one_commission_per_referred.sql first';
  end if;
  raise notice 'preconditions ok (047 + 048 present)';
end $$;

-- ------------------------------------------------------------------
-- 1) Entitlement for all seven paying customers.
--    Each row mirrors the store: ACTIVE, soulful_yearly, one year from the
--    order's own createTime. last_event_name='backfill_order' makes the
--    Superwall sync re-verify these rows later (so a cancellation still lands).
-- ------------------------------------------------------------------
insert into public.play_subscriptions
  (user_id, product_id, status, current_start, current_end, last_event_id, last_event_name, event_ts)
values
  ('user_3HcxrnLfXm9HM57XQDdoWRO8Lm8', 'soulful_yearly', 'active', '2026-11-23T02:45:18Z', '2027-11-23T02:45:18Z', 'backfill_3349', 'backfill_order', now()),
  ('user_3IJxJaGkq8JialXLifFwAI8wosP', 'soulful_yearly', 'active', '2026-11-23T01:12:07Z', '2027-11-23T01:12:07Z', 'backfill_3346', 'backfill_order', now()),
  ('user_3HujrPyIJLONDkazbQiwNEYN23W', 'soulful_yearly', 'active', '2026-11-22T23:48:07Z', '2027-11-22T23:48:07Z', 'backfill_3355', 'backfill_order', now()),
  ('user_3MSkMkthBkY7jVQuGKDNxoQkjzF', 'soulful_yearly', 'active', '2026-11-22T13:23:35Z', '2027-11-22T13:23:35Z', 'backfill_3329', 'backfill_order', now()),
  ('user_3MHp06PbInd7Vp0E5r630mRZZtD', 'soulful_yearly', 'active', '2026-11-21T01:59:22Z', '2027-11-21T01:59:22Z', 'backfill_3336', 'backfill_order', now()),
  ('user_3MMTQUBXG7MEUxTBmbo9zKSUfPC', 'soulful_yearly', 'active', '2026-11-20T07:27:41Z', '2027-11-20T07:27:41Z', 'backfill_3343', 'backfill_order', now()),
  ('user_3LmDxnP5fssCGshWnT4ptbWwamg', 'soulful_yearly', 'active', '2026-11-19T00:25:41Z', '2027-11-19T00:25:41Z', 'backfill_3398', 'backfill_order', now())
on conflict (user_id, product_id) do update
  set status = 'active',
      current_start = excluded.current_start,
      current_end = excluded.current_end,
      last_event_id = excluded.last_event_id,
      last_event_name = excluded.last_event_name,
      event_ts = now();

-- ------------------------------------------------------------------
-- 2) Order audit rows, so the admin directory shows the order id per friend.
-- ------------------------------------------------------------------
select public.admin_order_backfill('user_3HcxrnLfXm9HM57XQDdoWRO8Lm8', 'GPA.3349-8814-0784-50213', 'soulful_yearly', 'play', 120, '2026-11-23T02:45:18Z');
select public.admin_order_backfill('user_3IJxJaGkq8JialXLifFwAI8wosP', 'GPA.3346-1937-0916-76332', 'soulful_yearly', 'play', 120, '2026-11-23T01:12:07Z');
select public.admin_order_backfill('user_3HujrPyIJLONDkazbQiwNEYN23W', 'GPA.3355-4742-8139-11196', 'soulful_yearly', 'play', 120, '2026-11-22T23:48:07Z');
select public.admin_order_backfill('user_3MSkMkthBkY7jVQuGKDNxoQkjzF', 'GPA.3329-9747-0967-60331', 'soulful_yearly', 'play', 120, '2026-11-22T13:23:35Z');
select public.admin_order_backfill('user_3MHp06PbInd7Vp0E5r630mRZZtD', 'GPA.3336-8784-6123-73288', 'soulful_yearly', 'play', 120, '2026-11-21T01:59:22Z');
select public.admin_order_backfill('user_3MMTQUBXG7MEUxTBmbo9zKSUfPC', 'GPA.3343-8388-9129-57514', 'soulful_yearly', 'play', 120, '2026-11-20T07:27:41Z');
select public.admin_order_backfill('user_3LmDxnP5fssCGshWnT4ptbWwamg', 'GPA.3398-1155-9438-39846', 'soulful_yearly', 'play', 120, '2026-11-19T00:25:41Z');

-- ------------------------------------------------------------------
-- 3) The four missing ₹51 credits.
--
--    Each call returns true when the credit was written, false when it was
--    refused - either because the friend was already credited (048: one per
--    referred user, ever) or because that REFERRER is not an active subscriber
--    right now (the locked business rule).
--
--    user_3MHp06PbInd7Vp0E5r630mRZZtD is deliberately NOT called: they already
--    hold a ₹51 commission (razorpay_yearly), so 048 would refuse it anyway.
-- ------------------------------------------------------------------
-- karthik@famerelay.com  (code SB16A8359B3C)
select 'subhadradevi'   as friend, public.credit_referral_commission('user_3IJxJaGkq8JialXLifFwAI8wosP', 'soulful_yearly', 120, 0, 'backfill_credit_GPA3346') as credited
union all
select 'amithkn',        public.credit_referral_commission('user_3MSkMkthBkY7jVQuGKDNxoQkjzF', 'soulful_yearly', 120, 0, 'backfill_credit_GPA3329')
union all
select 'vadiselasrinu92', public.credit_referral_commission('user_3MMTQUBXG7MEUxTBmbo9zKSUfPC', 'soulful_yearly', 120, 0, 'backfill_credit_GPA3343')
union all
-- poojachowdhury300@gmail.com  (code SBDA03BBA29A)
select 'abhiaare05',     public.credit_referral_commission('user_3HujrPyIJLONDkazbQiwNEYN23W', 'soulful_yearly', 120, 0, 'backfill_credit_GPA3355');

-- ------------------------------------------------------------------
-- 4) THE REPORT. Read this after step 3.
-- ------------------------------------------------------------------

-- 4a. Every affiliate: friends, paid friends, money waiting.
select referrer_user_id, email, code, is_active,
       friends_joined, paid_friends, pending_amount, total_amount
from public.admin_affiliate_summary(null, null, null, 50);

-- 4b. The seven orders: buyer, referrer, order id, commission state.
select a.referred_user_id as buyer, ud_b.email as buyer_email,
       a.referrer_user_id, ud_r.email as referrer_email, a.code,
       p.order_id, p.amount as paid, c.commission_amount as commission, c.status as commission_status
from public.referral_attributions a
left join public.user_directory ud_b on ud_b.user_id = a.referred_user_id
left join public.user_directory ud_r on ud_r.user_id = a.referrer_user_id
left join public.referral_purchases p on p.referred_user_id = a.referred_user_id
left join public.commissions c on c.referred_user_id = a.referred_user_id
where a.referred_user_id in (
  'user_3HcxrnLfXm9HM57XQDdoWRO8Lm8','user_3IJxJaGkq8JialXLifFwAI8wosP',
  'user_3HujrPyIJLONDkazbQiwNEYN23W','user_3MSkMkthBkY7jVQuGKDNxoQkjzF',
  'user_3MHp06PbInd7Vp0E5r630mRZZtD','user_3MMTQUBXG7MEUxTBmbo9zKSUfPC',
  'user_3LmDxnP5fssCGshWnT4ptbWwamg')
order by a.created_at desc;

-- 4c. The ledger itself, newest first.
select c.referrer_user_id, ud.email as referrer_email, c.referred_user_id,
       c.product_id, c.commission_amount, c.status, c.created_at
from public.commissions c
left join public.user_directory ud on ud.user_id = c.referrer_user_id
order by c.created_at desc
limit 20;

-- 4d. Every paying customer is entitled (all rows should read active/play).
select ps.user_id, ud.email, ps.product_id, ps.status, ps.current_end, ps.last_event_name
from public.play_subscriptions ps
left join public.user_directory ud on ud.user_id = ps.user_id
where ps.user_id in (
  'user_3HcxrnLfXm9HM57XQDdoWRO8Lm8','user_3IJxJaGkq8JialXLifFwAI8wosP',
  'user_3HujrPyIJLONDkazbQiwNEYN23W','user_3MSkMkthBkY7jVQuGKDNxoQkjzF',
  'user_3MHp06PbInd7Vp0E5r630mRZZtD','user_3MMTQUBXG7MEUxTBmbo9zKSUfPC',
  'user_3LmDxnP5fssCGshWnT4ptbWwamg')
order by ps.current_end desc;
