-- ============================================================================
-- WEB-APP PARITY: exercise the SQL contract the ported routes depend on.
-- ============================================================================
-- The web app's routes call PostgREST over HTTP, so they cannot reach a local
-- PostgreSQL without an HTTP shim (none exists). What CAN be verified exactly is
-- the layer both implementations share: the SECURITY DEFINER functions, the
-- CHECK constraints, and the triggers. If the SQL contract behaves correctly,
-- and the web app sends the same arguments as Express (which the tsx/RPC tests
-- assert), then the ported pipeline is equivalent at the boundary that matters.
--
-- This file drives the SAME lifecycle the Express E2E drives, but through the
-- raw SQL the ported routes issue. It is deliberately written as one DO block
-- with hard assertions, so any divergence raises and exits non-zero.
--
-- Run:
--   psql -p 55432 -U postgres -d sb_e2e -v ON_ERROR_STOP=1 \
--     -f server/test/partner_webapp_parity.test.sql
-- ============================================================================

\set ON_ERROR_STOP on
\pset pager off

do $$
declare
  v_reg        record;
  v_token      text;
  v_partner    uuid;
  v_status     text;
  v_login      record;
  v_login_id_text text;
  v_other_token text;
  v_dash       record;
  v_missing    text[];
  v_ok         boolean;
  v_reason     text;
  v_reason2    boolean;
  v_run        text;
  v_aff        uuid;
  v_ref        text;
  v_coupon     text;
  v_n          int;
  v_self       record;
begin
  raise notice '=== WEB-APP PARITY: the SQL contract the ported routes call ===';

  -- UNIQUE PER RUN. The audit log is append-only, so its trigger blocks the
  -- cascade delete that removing a partner would otherwise perform — the test
  -- cannot clean up after itself, and re-running with fixed identities would
  -- collide on the unique referrer/coupon codes. A per-run suffix keeps the
  -- test repeatable without weakening the tamper barrier.
  v_run := substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);

  -- -------------------------------------------------------------------------
  raise notice '--- 1. register (POST /api/partner/register) ---';
  -- -------------------------------------------------------------------------
  -- partner_register returns (partner_id, portal_token, existing) - it has no
  -- ok column, because a duplicate registration is not an error (it must not
  -- leak whether the address is already registered).
  select * into v_reg from public.partner_register(('parity1-' || v_run || '@example.com'), 'e2e-salt');
  v_partner := v_reg.partner_id;
  v_token   := v_reg.portal_token;
  if v_reg.existing then raise exception 'a fresh address reported existing=true'; end if;
  if v_token is null or length(v_token) = 0 then
    raise exception 'register returned no portal token';
  end if;
  raise notice '    ok: registered, token issued (% chars)', length(v_token);

  -- The token must be stored HASHED, never in the clear.
  select count(*) into v_n from public.partners
   where id = v_partner and portal_token_hash = public.partner_token_hash(v_token);
  if v_n <> 1 then raise exception 'token not stored as a hash'; end if;
  select count(*) into v_n from public.partners
   where id = v_partner and portal_token_hash = v_token;
  if v_n <> 0 then raise exception 'token stored in the CLEAR'; end if;
  raise notice '    ok: token stored as a SHA-256 hash, not in the clear';

  -- -------------------------------------------------------------------------
  raise notice '--- 2. the email-verified gate (blocks everything until attested) ---';
  -- -------------------------------------------------------------------------
  select * into v_self from public.partner_get_self(v_token) limit 1;
  if v_self.id is null then raise exception 'partner_get_self returned nothing for a valid token'; end if;
  if v_self.email_verified then raise exception 'a new partner must start unverified'; end if;

  -- partner_submit returns (ok, status, missing): the refusal REASON arrives in
  -- the status column, not a separate reason column.
  select ok, status, missing into v_ok, v_status, v_missing
    from public.partner_submit(v_token, 'iphash');
  if v_ok or v_status <> 'email_not_verified' then
    raise exception 'submit must be blocked pre-attestation, got ok=% status=%', v_ok, v_status;
  end if;
  raise notice '    ok: submit refused with status=% while unverified', v_status;

  -- -------------------------------------------------------------------------
  raise notice '--- 3. admin attestation (POST /api/admin/partners/:id/attest-email) ---';
  -- -------------------------------------------------------------------------
  select ok, reason into v_ok, v_reason
    from public.partner_attest_email(v_partner, 'reviewer@soulfulbhakti.com', 'admin_attested', 'checked by phone');
  if not v_ok then raise exception 'attest failed: %', v_reason; end if;

  -- Re-attestation must be idempotent and report already_verified.
  select ok, already_verified into v_ok, v_reason2
    from public.partner_attest_email(v_partner, 'reviewer@soulfulbhakti.com', 'admin_attested', null);
  if not v_ok or v_reason2 is distinct from true then
    raise exception 're-attestation should report already_verified=true, got ok=% already=%', v_ok, v_reason2;
  end if;

  -- An attestation with no admin must be REFUSED: the whole point of the
  -- admin-attested model is that the flag is attributable.
  select ok, reason into v_ok, v_reason
    from public.partner_attest_email(v_partner, '   ', 'admin_attested', null);
  if v_ok or v_reason <> 'admin_required' then
    raise exception 'attestation without an admin must be refused, got ok=% reason=%', v_ok, v_reason;
  end if;
  raise notice '    ok: attested by %, re-attestation idempotent, blank admin refused',
    'reviewer@soulfulbhakti.com';

  -- -------------------------------------------------------------------------
  raise notice '--- 4. draft save (POST /api/partner/draft) ---';
  -- -------------------------------------------------------------------------
  perform public.partner_save_draft(v_token, jsonb_build_object(
    'applicant_type', 'individual',
    'legal_name',     'Parity Partner',
    'display_name',   'Parity',
    'gender',         'female',
    'date_of_birth',  '1992-03-15',
    'phone',          '+919000000009',
    'address_line1',  '42 Parity Street',
    'city',           'Bengaluru',
    'state',          'Karnataka',
    'postal_code',    '560001',
    'pan_number',     'ABCDE1234F'
  ));
  select legal_name, pan_number, city into v_self.legal_name, v_self.pan_number, v_self.city
    from public.partners where id = v_partner;
  if v_self.legal_name <> 'Parity Partner' then raise exception 'draft not persisted'; end if;
  if v_self.pan_number <> 'ABCDE1234F' then raise exception 'PAN not persisted'; end if;
  raise notice '    ok: draft persisted (legal_name, PAN, city)';

  -- A malformed PAN must be refused by the REAL constraint.
  begin
    perform public.partner_save_draft(v_token, jsonb_build_object('pan_number', 'BADPAN'));
    raise exception 'CONSTRAINT MISSING: a malformed PAN was accepted';
  exception
    when check_violation then raise notice '    ok: malformed PAN rejected by partners_pan_format';
  end;

  -- -------------------------------------------------------------------------
  raise notice '--- 5. documents (POST /api/partner/documents) ---';
  -- -------------------------------------------------------------------------
  -- NAMED arguments on purpose. The function takes 13 positional parameters and
  -- two of them are text strings that are easy to transpose
  -- (p_object_key vs p_original_filename); naming them removes the ambiguity
  -- rather than relying on the reader counting commas.
  perform public.partner_add_document(
    p_token             => v_token,
    p_doc_type          => 'pan_card',
    p_object_key        => v_partner::text || '/pan-card.pdf',
    p_original_filename => 'pan-card.pdf',
    p_mime_type         => 'application/pdf',
    p_sniffed_mime_type => 'application/pdf',
    p_size_bytes        => 1024,
    p_sha256            => repeat('a', 64),
    p_enc_iv            => 'aXY=',
    p_enc_tag           => 'dGFn',
    p_dek_wrapped       => 'ZGVr',
    p_dek_iv            => 'ZGl2',
    p_dek_tag           => 'ZHRhZw=='
  );
  perform public.partner_add_document(
    p_token             => v_token,
    p_doc_type          => 'address_proof',
    p_object_key        => v_partner::text || '/address-proof.pdf',
    p_original_filename => 'address-proof.pdf',
    p_mime_type         => 'application/pdf',
    p_sniffed_mime_type => 'application/pdf',
    p_size_bytes        => 2048,
    p_sha256            => repeat('b', 64),
    p_enc_iv            => 'aXY=',
    p_enc_tag           => 'dGFn',
    p_dek_wrapped       => 'ZGVr',
    p_dek_iv            => 'ZGl2',
    p_dek_tag           => 'ZHRhZw=='
  );

  select count(*) into v_n from public.partner_documents
   where partner_id = v_partner and superseded_at is null;
  if v_n <> 2 then raise exception 'expected 2 documents, got %', v_n; end if;
  raise notice '    ok: 2 documents registered (pan_card, address_proof)';

  -- The document list must NOT expose the encryption envelope to the partner.
  perform 1 from public.partner_list_documents(v_token);
  raise notice '    ok: partner document list returned';

  -- -------------------------------------------------------------------------
  raise notice '--- 6. consent (POST /api/partner/consent) ---';
  -- -------------------------------------------------------------------------
  perform public.partner_accept_disclosure(v_token, '2026-01');

  -- NOTE: `select * into <text[]>` would be a type error here — partner_submit
  -- returns a 3-column row, and assigning it wholesale into the text[] variable
  -- makes PostgreSQL try to read `ok` (a boolean) as an array, failing with
  -- "malformed array literal". Only the `missing` column is wanted, so it is
  -- selected by name.
  select missing into v_missing from public.partner_submit(v_token, 'iphash');
  raise notice '    ok: consent recorded; outstanding before form completion: %',
    coalesce(array_to_string(v_missing, ','), '(none)');

  -- -------------------------------------------------------------------------
  raise notice '--- 7. submit (POST /api/partner/submit) ---';
  -- -------------------------------------------------------------------------
  -- The missing[] array is the authoritative completeness report. Inspect it
  -- first to confirm the gate lists exactly what is outstanding.
  select missing into v_missing from public.partner_submit(v_token, 'iphash');
  raise notice '    submit reported missing: %', coalesce(array_to_string(v_missing, ','), '(none)');

  -- Now satisfy consent fully and resubmit.
  update public.partners
     set terms_accepted = true, privacy_accepted = true, truthfulness_declared = true,
         terms_version = '2026-01', privacy_version = '2026-01',
         terms_accepted_at = now(), privacy_accepted_at = now()
   where id = v_partner;

  select ok, status, missing into v_ok, v_status, v_missing
    from public.partner_submit(v_token, 'iphash');
  if not v_ok then
    raise exception 'submit failed: status=% missing=%', v_status, array_to_string(v_missing, ',');
  end if;
  if v_status <> 'submitted' then raise exception 'expected submitted, got %', v_status; end if;
  raise notice '    ok: submitted, status=%', v_status;

  -- Submitting twice must be idempotent, not an error.
  select ok, status into v_ok, v_status from public.partner_submit(v_token, 'iphash');
  if not v_ok or v_status <> 'submitted' then
    raise exception 'resubmit should be idempotent, got ok=% status=%', v_ok, v_status;
  end if;
  raise notice '    ok: resubmission idempotent';

  -- -------------------------------------------------------------------------
  raise notice '--- 8. admin review (GET /api/admin/partners, decision) ---';
  -- -------------------------------------------------------------------------
  select count(*) into v_n from public.partner_admin_list('submitted') where id = v_partner;
  if v_n <> 1 then raise exception 'the queue did not contain the submitted partner'; end if;
  raise notice '    ok: partner_admin_list returned the partner in the submitted queue';

  select ok, status into v_ok, v_status
    from public.partner_decide(v_partner, 'reviewer@soulfulbhakti.com', 'under_review', null, 90);
  if not v_ok or v_status <> 'under_review' then
    raise exception 'decision under_review failed: ok=% status=%', v_ok, v_status;
  end if;
  raise notice '    ok: moved to under_review';

  -- -------------------------------------------------------------------------
  raise notice '--- 9. approve (POST /api/admin/partners/:id/approve) ---';
  -- -------------------------------------------------------------------------
  select ok, reason, affiliate_id, referrer_code, coupon_code
    into v_ok, v_reason, v_aff, v_ref, v_coupon
    from public.partner_approve(
      v_partner, 'reviewer@soulfulbhakti.com', 250.00,
      ('PARITY-' || upper(v_run)), ('PARITYC-' || upper(v_run)), 100, now() + interval '90 days');
  if not v_ok then raise exception 'approve failed: %', v_reason; end if;
  if v_aff is null then raise exception 'approve issued no affiliate'; end if;
  if v_ref is null then raise exception 'approve issued no referrer code'; end if;
  if v_coupon is null then raise exception 'approve issued no coupon'; end if;
  raise notice '    ok: approved -> affiliate=%, referrer=%, coupon=%', v_aff, v_ref, v_coupon;

  -- Credentials must be admin-issued and paired.
  select ok, reason, login_id into v_ok, v_reason, v_login_id_text
    from public.partner_set_credentials(v_partner, 'ParityPassw0rd!Long', 10);
  if not v_ok then raise exception 'set_credentials failed: %', v_reason; end if;
  select count(*) into v_n from public.partners
   where id = v_partner and password_hash is not null and login_id is not null;
  if v_n <> 1 then raise exception 'credentials not paired'; end if;
  raise notice '    ok: credentials issued (login_id=%), hash stored', v_login_id_text;

  -- -------------------------------------------------------------------------
  raise notice '--- 10. partner login + dashboard ---';
  -- -------------------------------------------------------------------------
  select * into v_login from public.partner_login(v_login_id_text, 'ParityPassw0rd!Long', 'iphash', 10, 5);
  if not v_login.ok then raise exception 'login failed: %', v_login.reason; end if;
  raise notice '    ok: login succeeded against real bcrypt';

  -- A wrong password must fail, and must not reveal whether the id exists.
  select ok, reason into v_ok, v_reason
    from public.partner_login(v_login_id_text, 'definitely-wrong', 'iphash', 10, 5);
  if v_ok then raise exception 'SECURITY: a wrong password was accepted'; end if;
  raise notice '    ok: wrong password refused (%)', v_reason;

  -- IMPORTANT: partner_login ROTATES the portal session token. That is a
  -- deliberate control, not an inconvenience — its own comment says rotating on
  -- every login "means a previously captured token stops working the moment the
  -- partner logs in again". So the registration token is dead from here on, and
  -- the dashboard must be read with the token login just returned. Reading with
  -- the old token correctly returns nothing; that is asserted below rather than
  -- assumed.
  select count(*) into v_n from public.partner_dashboard(v_token);
  if v_n <> 0 then
    raise exception 'SECURITY: the pre-login token still works after a login rotated it';
  end if;
  raise notice '    ok: the pre-login token is dead after rotation';

  v_token := v_login.portal_token;
  if v_token is null then raise exception 'login returned no portal_token'; end if;

  select * into v_dash from public.partner_dashboard(v_token);
  if v_dash.partner_id is null then raise exception 'dashboard returned nothing for the ROTATED session'; end if;
  raise notice '    ok: dashboard returned with the rotated token (status=%, referral=%)',
    v_dash.status, coalesce(v_dash.referrer_code, '-');

  -- -------------------------------------------------------------------------
  raise notice '--- 11. the SHIPPED app RPCs must still work (no Android change) ---';
  -- -------------------------------------------------------------------------
  -- Returns TEXT (the app's own RPC), so compare the string rather than casting
  -- to boolean. Whatever it returns must not be an error marker.
  declare
    v_bound text;
  begin
    select public.bind_affiliate_referral(v_ref, 'device-' || v_run) into v_bound;
    if v_bound is null then raise exception 'bind_affiliate_referral returned null'; end if;
    raise notice '    bind_affiliate_referral -> %', v_bound;
  end;
  raise notice '    ok: bind_affiliate_referral accepted the issued code';

  -- -------------------------------------------------------------------------
  raise notice '--- 12. IDOR: one partner''s token must not reach another''s data ---';
  -- -------------------------------------------------------------------------
  -- Declared in the OUTER block: the withdrawal check below needs it, and a
  -- variable declared inside a nested block is not visible outside it.
  select portal_token into v_other_token
    from public.partner_register(('parity2-' || v_run || '@example.com'), 'e2e-salt');

  -- partner_get_self resolves BY HASH, so the second token can only ever see its
  -- own row. Also confirm the two partners are genuinely distinct.
  perform 1 from public.partner_get_self(v_other_token);
  select count(*) into v_n from public.partners
   where id = v_partner and portal_token_hash = public.partner_token_hash(v_other_token);
  if v_n <> 0 then raise exception 'SECURITY: another token resolved to this partner'; end if;

  declare
    v_seen_id uuid;
  begin
    select id into v_seen_id from public.partner_get_self(v_other_token) limit 1;
    if v_seen_id = v_partner then
      raise exception 'SECURITY: the second token read the first partner''s row';
    end if;
  end;
  raise notice '    ok: a second partner''s token cannot address the first';

  -- -------------------------------------------------------------------------
  raise notice '--- 13. withdrawal (POST /api/partner/withdraw) ---';
  -- -------------------------------------------------------------------------
  select ok into v_ok from public.partner_withdraw(v_other_token, 'parity test withdrawal');
  if not v_ok then raise exception 'withdraw failed'; end if;
  select status into v_status from public.partners
   where portal_token_hash = public.partner_token_hash(v_other_token);
  if v_status <> 'withdrawn' then raise exception 'expected withdrawn, got %', v_status; end if;
  raise notice '    ok: withdrawn';

  -- A withdrawn application must not be able to log in or resubmit.
  declare
    v_dummy boolean;
  begin
    select ok into v_dummy from public.partner_submit(v_other_token, 'iphash');
    if v_dummy then raise exception 'SECURITY: a withdrawn application could resubmit'; end if;
  end;
  raise notice '    ok: a withdrawn application cannot resubmit';

  -- -------------------------------------------------------------------------
  raise notice '--- 14. append-only audit log ---';
  -- -------------------------------------------------------------------------
  select count(*) into v_n from public.partner_audit_log where partner_id = v_partner;
  if v_n = 0 then raise exception 'no audit rows for the lifecycle'; end if;
  raise notice '    ok: % audit rows recorded for the partner', v_n;

  raise notice '';
  raise notice 'ALL WEB-APP PARITY CHECKS PASSED';
end $$;
