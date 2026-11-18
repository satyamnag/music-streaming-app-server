-- ============================================================
-- OPTIONAL verification for migration 040.
--
-- Run this AFTER 040_referral_install_bridge.sql, and only if you want proof
-- that the new branch behaves. It is a separate file because Postgres executes
-- a multi-statement script in ONE implicit transaction: a ROLLBACK placed in
-- the migration itself would also have undone the function replacement.
--
-- Nothing here is destructive. It writes two probe rows into
-- referral_attributions inside an explicit transaction, prints what it saw, and
-- then ROLLBACKs the entire transaction, so the probe rows never persist and no
-- DELETE is needed. The probe user ids are 'migration-040-probe' and
-- 'migration-040-probe2' and can never collide with a real Clerk user id.
--
-- EXPECT in the Messages tab:
--   user_code_found=SB...
--   first_call=invalid                <- attribution still written
--   attributed_row=1
--   attributed_to_expected_referrer=true
--   second_call=invalid
--   second_call_idempotent=1          <- still exactly one row
--   unknown_code=invalid
--   unknown_wrote_rows=0
--   self_code=invalid
--   self_rows_for_referrer=0
-- and one result row: rolled_back=ok
-- ============================================================

begin;

do $$
declare
  v_code text;
  v_referrer text;
  v_count integer;
begin
  select rc.code, rc.user_id into v_code, v_referrer
  from public.referral_codes rc
  order by rc.code
  limit 1;

  if v_code is null then
    raise notice 'no referral_codes rows yet - branch not exercised.';
    return;
  end if;

  raise notice 'user_code_found=%', v_code;

  raise notice 'first_call=%',
    public.bind_affiliate_referral(v_code, 'migration-040-probe');

  select count(*) into v_count from public.referral_attributions
  where referred_user_id = 'migration-040-probe';
  raise notice 'attributed_row=%', v_count;

  raise notice 'attributed_to_expected_referrer=%',
    (select referrer_user_id = v_referrer from public.referral_attributions
     where referred_user_id = 'migration-040-probe');

  raise notice 'second_call=%',
    public.bind_affiliate_referral(v_code, 'migration-040-probe');

  select count(*) into v_count from public.referral_attributions
  where referred_user_id = 'migration-040-probe';
  raise notice 'second_call_idempotent=%', v_count;

  raise notice 'unknown_code=%',
    public.bind_affiliate_referral('NOTAREALCODE040', 'migration-040-probe2');
  select count(*) into v_count from public.referral_attributions
  where referred_user_id = 'migration-040-probe2';
  raise notice 'unknown_wrote_rows=%', v_count;

  raise notice 'self_code=%',
    public.bind_affiliate_referral(v_code, v_referrer);
  select count(*) into v_count from public.referral_attributions
  where referred_user_id = v_referrer;
  raise notice 'self_rows_for_referrer=%', v_count;
end $$;

-- Discards every probe row written above. No DELETE is used anywhere.
rollback;

select 'rolled_back=ok - no probe rows persisted' as result;
