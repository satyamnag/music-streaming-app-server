-- Full partner lifecycle against the "your project" database: pgcrypto in the
-- `extensions` schema, and migrations 003/008/009 never applied.
\set ON_ERROR_STOP on
\timing off

do $$
declare
  v_id uuid;
  v_tok text;
  v_res record;
  v_aff uuid;
  v_ref text;
  v_coupon text;
begin
  raise notice '';
  raise notice '=== FULL LIFECYCLE (repaired project) ===';

  -- 1. register
  select partner_id, portal_token into v_id, v_tok
  from public.partner_register('live@example.com', 'ip');
  raise notice '1. register: id=% token_len=%', v_id is not null, length(v_tok);

  -- 2. verify email
  perform public.partner_set_verification_token(v_id, 'tok1', 1440);
  select * into v_res from public.partner_consume_verification('tok1');
  raise notice '2. verify email: ok=% reason=%', v_res.ok, v_res.reason;

  -- 3. fill in and attach documents
  update public.partners set
    applicant_type = 'individual', legal_name = 'Live Partner',
    date_of_birth = '1991-02-02', gender = 'female', phone = '+919000000011',
    address_line1 = '9 Live Rd', city = 'Pune', state = 'Maharashtra',
    postal_code = '411001', pan_number = 'ABCDE1234F',
    terms_accepted = true, privacy_accepted = true, truthfulness_declared = true
  where id = v_id;

  perform public.partner_add_document(
    v_tok, 'pan_card', v_id || '/k1.enc', 'pan.pdf',
    'application/pdf', 'application/pdf', 100, repeat('a',64),
    'i','t','w','wi','wt');
  perform public.partner_add_document(
    v_tok, 'address_proof', v_id || '/k2.enc', 'addr.png',
    'image/png', 'image/png', 100, repeat('b',64),
    'i','t','w','wi','wt');

  -- 4. submit
  select * into v_res from public.partner_submit(v_tok, 'ip');
  raise notice '4. submit: ok=% status=%', v_res.ok, v_res.status;

  -- 5. approve -> issues referrer code + coupon
  select * into v_res from public.partner_approve(v_id, 'admin', 100, null, null, 500, null);
  raise notice '5. approve: ok=% referrer=% coupon=% reason=%',
    v_res.ok, v_res.referrer_code, v_res.coupon_code, v_res.reason;

  v_aff := v_res.affiliate_id;
  v_ref := v_res.referrer_code;
  v_coupon := v_res.coupon_code;

  -- 6. the SHIPPED app RPCs must accept these artefacts
  raise notice '6. app RPC bind_affiliate_referral: %',
    (select public.bind_affiliate_referral(v_ref, 'clerk_live_user'));
  raise notice '   app RPC validate_coupon: %',
    (select valid from public.validate_coupon(v_coupon));
  raise notice '   app RPC redeem_coupon: %',
    (select public.redeem_coupon(v_coupon, 'clerk_live_user'));

  -- 7. the QR deep link the app parses
  raise notice '7. install URL: %',
    'https://play.google.com/store/apps/details?id=com.soulfulbhakti.app&referrer=utm_source=' || v_ref;

  if v_res.ok is not true then
    raise exception 'APPROVAL FAILED: %', v_res.reason;
  end if;
  if v_res.referrer_code is null or v_res.coupon_code is null then
    raise exception 'approval did not issue both artefacts';
  end if;

  raise notice '';
  raise notice '=== LIFECYCLE COMPLETE AND CORRECT ===';
end $$;

-- Final state
select 'affiliates' as tbl, count(*)::text as n from public.affiliates
union all select 'coupons', count(*)::text from public.coupons
union all select 'partners', count(*)::text from public.partners
union all select 'partner_documents', count(*)::text from public.partner_documents
union all select 'audit_log', count(*)::text from public.partner_audit_log
order by 1;
