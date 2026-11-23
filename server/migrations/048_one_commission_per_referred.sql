-- ============================================================
-- MIGRATION 048: one commission per referred user, across BOTH rails
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- WHY
--   The business rule is "first payment only, once per referred user, ever"
--   (docs: SUBSCRIPTIONS.md §Business rules). It was enforced by TWO partial
--   indexes that never meet:
--     * migration 039: commissions (referred_user_id) WHERE product_id =
--       'razorpay_yearly'
--     * migration 042: commissions (referred_user_id) WHERE product_id IN
--       ('soulful_yearly','soulful_monthly')
--   A friend credited once on the WEB rail can therefore be credited AGAIN for
--   their Play purchase (and the reverse), paying ₹102 for one friend. This is
--   a live risk: one referred user already holds a razorpay_yearly credit and a
--   Play order of their own.
--
-- WHAT THIS CHANGES
--   * One partial-index-free UNIQUE index on commissions (referred_user_id):
--     at most one commission row per friend, whatever the product or rail.
--   * The credit functions keep working unchanged: their "on conflict do
--     nothing" now also catches the cross-rail case, and they still return the
--     honest false/already_credited answer.
--
-- SAFETY
--   * The index is only created after PROVING no referred user already holds
--     more than one row. If duplicates exist the migration STOPS with the ids
--     instead of failing halfway, because a unique index cannot be created over
--     them and silently guessing which row to delete would change money.
--   * Nothing is deleted. The two older partial indexes stay (harmless, and
--     they keep the original intent readable).
--   * Re-runnable: if-not-exists + create-or-replace style only.
-- ============================================================

-- ------------------------------------------------------------------
-- 0) Pre-check: stop loudly if existing data would violate the rule.
-- ------------------------------------------------------------------
do $$
declare
  v_dupes integer;
  v_examples text;
begin
  select count(*) into v_dupes
  from (
    select c.referred_user_id
    from public.commissions c
    group by c.referred_user_id
    having count(*) > 1
  ) d;

  if v_dupes > 0 then
    select string_agg(d.referred_user_id, ', ') into v_examples
    from (
      select c.referred_user_id
      from public.commissions c
      group by c.referred_user_id
      having count(*) > 1
      limit 10
    ) d;

    raise exception
      'Stop: % referred user(s) already hold more than one commission row (e.g. %). Resolve those rows first (keep one, delete or supersede the other), then re-run 048.',
      v_dupes, v_examples;
  end if;

  raise notice 'pre-check ok - no referred user holds more than one commission row';
end $$;

-- ------------------------------------------------------------------
-- 1) The rule itself.
-- ------------------------------------------------------------------
create unique index if not exists commissions_one_per_referred_idx
  on public.commissions (referred_user_id);

-- ------------------------------------------------------------------
-- CONFIRM (read-only)
-- ------------------------------------------------------------------
select indexname from pg_indexes
where schemaname = 'public'
  and indexname in (
    'commissions_one_per_referred_idx',
    'commissions_razorpay_one_per_referred_idx',
    'commissions_play_one_per_referred_idx'
  )
order by indexname;
