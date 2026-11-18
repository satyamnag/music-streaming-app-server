-- ============================================================
-- MIGRATION 041 (DIAGNOSTIC): record what the Android app actually sends to
-- bind_affiliate_referral.
--
-- WHY
--   The app posts the code it read from the Play install referrer directly to
--   Supabase. API logs show the URL and the status but not the payload, so a
--   bind that resolves to nothing leaves no trace anywhere. This makes the
--   incoming value visible for one query.
--
-- WHAT IT DOES
--   * Creates public.referral_bind_log (throwaway diagnostic table).
--   * Adds ONE insert at the top of bind_affiliate_referral.
--   * Everything else in the function is byte-identical to migration 040.
--   * The insert is wrapped in an exception block, so it can never break a
--     bind, never change a return value, and never surface an error to the app.
--
-- SAFETY
--   No existing table is altered. No data is deleted. The only new object is
--   the log table. RLS on, no anon/authenticated grants - service_role only.
--   To remove it again, see the teardown block at the end.
--
-- AFTER APPLYING: launch the app once, sign in, then run the query at the
-- bottom. It shows the exact code the device is sending.
-- ============================================================

create table if not exists public.referral_bind_log (
  id bigserial primary key,
  incoming_code text,
  user_id text,
  created_at timestamptz not null default now()
);

alter table public.referral_bind_log enable row level security;
revoke all on public.referral_bind_log from anon, authenticated;
grant select, delete on public.referral_bind_log to service_role;

create index if not exists referral_bind_log_created_idx
  on public.referral_bind_log (created_at desc);

create or replace function public.bind_affiliate_referral(
  p_referrer_code text, p_user_id text
)
returns text
language plpgsql
security definer
set search_path = public
as $body$
declare
  v_affiliate_id uuid;
  v_bound boolean;
  v_user_referrer text;
begin
  -- DIAGNOSTIC (migration 041). Records the raw incoming values so a bind that
  -- resolves to nothing is still visible. Swallows every error: attribution
  -- must never fail because a log row could not be written.
  begin
    insert into public.referral_bind_log (incoming_code, user_id)
    values (p_referrer_code, p_user_id);
  exception when others then
    null;
  end;

  if p_referrer_code is null or p_referrer_code = ''
     or p_user_id is null or p_user_id = '' then
    return 'invalid';
  end if;

  -- USER REFERRAL CODES (040). Resolved first, but only when the code actually
  -- exists in referral_codes, so partner codes are unaffected.
  select rc.user_id into v_user_referrer
  from public.referral_codes rc
  where upper(rc.code) = upper(trim(p_referrer_code));

  if v_user_referrer is not null then
    if v_user_referrer = p_user_id then
      return 'invalid';   -- self-referral is never attribution
    end if;

    insert into public.referral_attributions (code, referrer_user_id, referred_user_id)
    values (upper(trim(p_referrer_code)), v_user_referrer, p_user_id)
    on conflict (referred_user_id) do nothing;

    return 'invalid';
  end if;

  -- ORIGINAL PARTNER BRANCH - unchanged from 033_partner_program.sql.
  if exists (
    select 1 from public.affiliate_referrals where purchaser_user_id = p_user_id
  ) then
    return 'already_bound';
  end if;

  select a.id into v_affiliate_id
  from public.affiliates a
  where upper(a.referrer_code) = upper(p_referrer_code)
    and a.status = 'active'
  limit 1;

  if v_affiliate_id is null then
    return 'invalid';
  end if;

  insert into public.affiliate_referrals (referrer_code, affiliate_id, purchaser_user_id)
  values (upper(p_referrer_code), v_affiliate_id, p_user_id)
  on conflict (purchaser_user_id) do nothing;

  select exists (
    select 1 from public.affiliate_referrals
    where purchaser_user_id = p_user_id and affiliate_id = v_affiliate_id
  ) into v_bound;

  if v_bound then
    return 'bound';
  else
    return 'already_bound';
  end if;
end;
$body$;

grant execute on function public.bind_affiliate_referral(text, text)
  to anon, authenticated;

-- ------------------------------------------------------------------
-- READ IT (run after launching the app once and signing in)
--
--   join it against both code spaces so the reason is immediate:
-- ------------------------------------------------------------------
-- select l.created_at,
--        l.user_id,
--        l.incoming_code,
--        (select rc.user_id from public.referral_codes rc
--          where upper(rc.code) = upper(trim(l.incoming_code))) as matches_referral_code,
--        (select a.id from public.affiliates a
--          where upper(a.referrer_code) = upper(trim(l.incoming_code))) as matches_affiliate,
--        (select count(*) from public.referral_attributions ra
--          where ra.referred_user_id = l.user_id) as user_already_attributed
-- from public.referral_bind_log l
-- order by l.created_at desc
-- limit 20;

-- ------------------------------------------------------------------
-- TEARDOWN (when the diagnosis is done): drops the log and restores the
-- function exactly as migration 040 left it - re-run the 040 body without the
-- logging block, then:
--
--   delete from public.referral_bind_log;
--   drop table if exists public.referral_bind_log;
-- ------------------------------------------------------------------
