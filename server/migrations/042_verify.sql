-- ============================================================
-- OPTIONAL verification for migration 042.
-- Run AFTER 042_referral_flat_play_commission.sql.
--
-- Everything runs between begin and rollback, so the probe commission row is
-- discarded and never persists. No DELETE is used anywhere.
--
-- EXPECT in Messages:
--   flat_amount_config=51
--   probe_referred=<a user id>  probe_referrer=<your active referrer's id>
--   first_call=true
--   credited_amount=51
--   stored_rate_percent=0
--   credited_status=pending
--   second_call_same_pair=false     <- first-payment-only guard
--   rows_for_pair=1
-- and one result row: rolled_back=ok
-- ============================================================

begin;

do $$
declare
  v_referred text;
  v_referrer text;
  v_cfg numeric;
  v_first boolean;
  v_second boolean;
  v_amount numeric;
  v_rate numeric;
  v_status text;
  v_rows integer;
begin
  select cfg.commission_amount into v_cfg
  from public.referral_program_config cfg where cfg.id = true;
  raise notice 'flat_amount_config=%', v_cfg;

  -- An attributed friend whose referrer is currently an active subscriber,
  -- and who has no Play commission yet: exactly the situation a real Play
  -- purchase presents.
  select ra.referred_user_id, ra.referrer_user_id
    into v_referred, v_referrer
  from public.referral_attributions ra
  where coalesce((select se.active from public.subscription_entitlement(ra.referrer_user_id) se limit 1), false)
    and not exists (
      select 1 from public.commissions c
      where c.referred_user_id = ra.referred_user_id
        and c.product_id in ('soulful_yearly', 'soulful_monthly')
    )
  order by ra.created_at desc
  limit 1;

  if v_referred is null then
    raise notice 'no eligible attributed friend with an active referrer - nothing to probe';
    return;
  end if;

  raise notice 'probe_referred=%  probe_referrer=%', v_referred, v_referrer;

  v_first := public.credit_referral_commission(
    v_referred, 'soulful_yearly', 120, 25, 'migration-042-probe-1');
  raise notice 'first_call=%', v_first;

  select c.commission_amount, c.rate_percent, c.status
    into v_amount, v_rate, v_status
  from public.commissions c
  where c.referred_user_id = v_referred
    and c.product_id = 'soulful_yearly'
  order by c.created_at desc
  limit 1;

  raise notice 'credited_amount=%', v_amount;
  raise notice 'stored_rate_percent=%', v_rate;
  raise notice 'credited_status=%', v_status;

  -- A renewal would arrive as a different event id. It must NOT credit again.
  v_second := public.credit_referral_commission(
    v_referred, 'soulful_yearly', 120, 25, 'migration-042-probe-2');
  raise notice 'second_call_same_pair=%', v_second;

  select count(*) into v_rows
  from public.commissions c
  where c.referred_user_id = v_referred
    and c.product_id in ('soulful_yearly', 'soulful_monthly');
  raise notice 'rows_for_pair=%', v_rows;
end $$;

rollback;

select 'rolled_back=ok - no probe rows persisted' as result;
