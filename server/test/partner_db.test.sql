-- ============================================================================
-- End-to-end SQL test of the Partner Program
-- ============================================================================
-- Drives the REAL database functions (not a stub) through the complete partner
-- lifecycle, asserting the business rules and security properties that the
-- application depends on.
--
-- Every check RAISEs on failure, so `psql -v ON_ERROR_STOP=1` aborts the run
-- at the first broken invariant. A clean run means every assertion held.
--
-- Run:
--   psql -h 127.0.0.1 -p 55432 -U postgres -d sb_partner_test \
--        -v ON_ERROR_STOP=1 -f test/partner_db.test.sql
-- ============================================================================

\set ON_ERROR_STOP on
\pset pager off

-- ---------------------------------------------------------------------------
-- Start from a clean slate.
--
-- Without this the suite is not repeatable: a leftover row for the test email
-- makes `partner_register` correctly report a duplicate, and the very first
-- assertion then fails for a reason that has nothing to do with the code.
-- Truncating here keeps the suite idempotent and re-runnable.
-- ---------------------------------------------------------------------------
truncate table
  public.partner_audit_log,
  public.partner_email_events,
  public.partner_documents,
  public.partners,
  public.affiliate_commissions,
  public.affiliate_referrals,
  public.coupon_attributions,
  public.coupons,
  public.affiliates
restart identity cascade;

do $$
begin
  raise notice '====================================================';
  raise notice ' Partner Program — database behaviour tests';
  raise notice '====================================================';
end $$;

-- ---------------------------------------------------------------------------
-- Utility: a tiny assertion helper.
-- ---------------------------------------------------------------------------
create or replace function pg_temp.assert(cond boolean, label text)
returns void
language plpgsql
as $$
begin
  if cond is not true then
    raise exception 'ASSERTION FAILED: %', label;
  end if;
  raise notice '  PASS %', label;
end;
$$;

-- Equality assertion.
--
-- Implemented as (text, text, text), with typed overloads for the value kinds
-- this suite actually compares.
--
-- PostgreSQL's anyelement demands that BOTH arguments resolve to the SAME
-- type, which fails for `count(*)` (bigint) against a bare literal (integer).
-- Comparing rendered text is unambiguous, and the overloads keep call sites
-- readable without sprinkling casts through every assertion.
create or replace function pg_temp.assert_eq(actual text, expected text, label text)
returns void
language plpgsql
as $$
begin
  if actual is distinct from expected then
    raise exception 'ASSERTION FAILED: % (expected %, got %)', label, expected, actual;
  end if;
  raise notice '  PASS %', label;
end;
$$;

create or replace function pg_temp.assert_eq(actual boolean, expected boolean, label text)
returns void language sql as $$ select pg_temp.assert_eq(actual::text, expected::text, label); $$;

create or replace function pg_temp.assert_eq(actual bigint, expected bigint, label text)
returns void language sql as $$ select pg_temp.assert_eq(actual::text, expected::text, label); $$;

create or replace function pg_temp.assert_eq(actual integer, expected integer, label text)
returns void language sql as $$ select pg_temp.assert_eq(actual::text, expected::text, label); $$;

create or replace function pg_temp.assert_eq(actual numeric, expected numeric, label text)
returns void language sql as $$ select pg_temp.assert_eq(actual::text, expected::text, label); $$;

-- Mixed numeric widths (e.g. an integer variable against a bigint literal).
create or replace function pg_temp.assert_eq(actual bigint, expected integer, label text)
returns void language sql as $$ select pg_temp.assert_eq(actual::text, expected::text, label); $$;

create or replace function pg_temp.assert_eq(actual integer, expected bigint, label text)
returns void language sql as $$ select pg_temp.assert_eq(actual::text, expected::text, label); $$;

create or replace function pg_temp.assert_eq(actual uuid, expected uuid, label text)
returns void language sql as $$ select pg_temp.assert_eq(actual::text, expected::text, label); $$;

create or replace function pg_temp.assert_eq(actual timestamptz, expected timestamptz, label text)
returns void language sql as $$ select pg_temp.assert_eq(actual::text, expected::text, label); $$;

-- ===========================================================================
-- 1. REGISTRATION
-- ===========================================================================
do $$
declare
  v_id uuid;
  v_tok text;
  v_existing boolean;
begin
  raise notice '';
  raise notice '--- 1. Registration ---';

  select partner_id, portal_token, existing
    into v_id, v_tok, v_existing
  from public.partner_register('Test.Partner@Example.COM', 'iphash1');

  perform pg_temp.assert(v_id is not null, 'register returns a partner id');
  perform pg_temp.assert(v_tok is not null, 'register returns a portal token');
  perform pg_temp.assert_eq(v_existing, false, 'new email is not flagged existing');

  -- Email is normalised to lower case (one application per address).
  perform pg_temp.assert(
    (select email from public.partners where id = v_id) = 'test.partner@example.com',
    'email is normalised to lower case');

  -- The raw token must NOT be stored; only its SHA-256 hash.
  perform pg_temp.assert(
    (select portal_token_hash from public.partners where id = v_id)
      <> v_tok,
    'raw portal token is never stored');

  perform pg_temp.assert_eq(
    (select portal_token_hash from public.partners where id = v_id),
    encode(digest(v_tok, 'sha256'), 'hex'),
    'stored value is the SHA-256 of the token');

  -- A fresh row must carry the DPDP retention floor.
  perform pg_temp.assert(
    (select earliest_purge_at from public.partners where id = v_id) > now() + interval '360 days',
    'earliest_purge_at defaults to ~1 year out (DPDP r.8(3) floor)');

  perform pg_temp.assert_eq(
    (select status from public.partners where id = v_id), 'draft',
    'new application starts as draft');

  raise notice '  -> registered partner %', v_id;
end $$;

-- ===========================================================================
-- 2. USER-ENUMERATION RESISTANCE (ASVS 6.3.8)
-- ===========================================================================
do $$
declare
  v_tok text;
  v_existing boolean;
begin
  raise notice '';
  raise notice '--- 2. Registration is not an enumeration oracle ---';

  select portal_token, existing into v_tok, v_existing
  from public.partner_register('test.partner@example.com', 'iphash2');

  perform pg_temp.assert_eq(v_existing, true, 'duplicate email is flagged to the server');
  perform pg_temp.assert(v_tok is null, 'NO token is issued for a duplicate registration');

  perform pg_temp.assert_eq(
    (select count(*) from public.partners where lower(email) = 'test.partner@example.com'),
    1::bigint,
    'no second account is created for the same email');

  -- Case-insensitive: the same address in different case is still a duplicate.
  select portal_token, existing into v_tok, v_existing
  from public.partner_register('TEST.PARTNER@EXAMPLE.COM', 'iphash3');
  perform pg_temp.assert_eq(v_existing, true, 'duplicate detection is case-insensitive');
  perform pg_temp.assert(v_tok is null, 'no token for a case-variant duplicate');
end $$;

-- ===========================================================================
-- 3. EMAIL VERIFICATION — single use, expiring, CSPRNG
-- ===========================================================================
do $$
declare
  v_id uuid;
  v_tok text;
  v_res record;
  v_verify text;
begin
  raise notice '';
  raise notice '--- 3. Email verification ---';

  select id into v_id from public.partners where email = 'test.partner@example.com';

  -- An unverified partner must not be able to upload or submit. We need a
  -- token we control, so mint one through the service-role path (as the
  -- server does) and confirm the unverified gate first.
  v_tok := encode(gen_random_bytes(32), 'hex');
  update public.partners set portal_token_hash = encode(digest(v_tok, 'sha256'), 'hex')
  where id = v_id;

  select * into v_res from public.partner_submit(v_tok, 'ip');
  perform pg_temp.assert_eq(v_res.ok, false, 'an unverified partner cannot submit');
  perform pg_temp.assert_eq(v_res.status, 'email_not_verified', 'the gate reports email_not_verified');

  select * into v_res from public.partner_add_document(
    v_tok, 'pan_card', v_id || '/x.enc', 'x.pdf',
    'application/pdf', 'application/pdf', 100, repeat('9', 64),
    'i', 't', 'w', 'wi', 'wt');
  perform pg_temp.assert_eq(v_res.ok, false, 'an unverified partner cannot upload documents');
  perform pg_temp.assert_eq(v_res.reason, 'email_not_verified', 'upload gate reports email_not_verified');

  -- Mint a verification token and confirm only its hash is stored.
  v_verify := encode(gen_random_bytes(32), 'hex');
  perform public.partner_set_verification_token(v_id, v_verify, 1440);

  perform pg_temp.assert(
    (select email_verify_token_hash from public.partners where id = v_id)
      = encode(digest(v_verify, 'sha256'), 'hex'),
    'verification token is stored only as a SHA-256 hash');

  perform pg_temp.assert(
    (select email_verify_expires_at from public.partners where id = v_id) > now(),
    'verification token gets a future expiry');

  -- Consume it.
  select * into v_res from public.partner_consume_verification(v_verify);
  perform pg_temp.assert_eq(v_res.ok, true, 'valid verification token is accepted');
  perform pg_temp.assert_eq(v_res.reason, 'verified', 'first use reports "verified"');
  perform pg_temp.assert(
    (select email_verified from public.partners where id = v_id) = true,
    'email_verified is now true');

  perform pg_temp.assert(
    (select email_verify_token_hash from public.partners where id = v_id) is null,
    'token hash is burned after use (single-use)');

  -- Replay must be refused.
  select * into v_res from public.partner_consume_verification(v_verify);
  perform pg_temp.assert_eq(v_res.ok, false, 'a consumed token cannot be replayed');

  -- Unknown token must be refused.
  select * into v_res from public.partner_consume_verification('not-a-real-token');
  perform pg_temp.assert_eq(v_res.reason, 'invalid', 'unknown token is rejected');

  -- Empty token must not crash.
  select * into v_res from public.partner_consume_verification('');
  perform pg_temp.assert_eq(v_res.ok, false, 'empty token is rejected safely');
end $$;

-- An EXPIRED token must be refused.
do $$
declare
  v_id uuid;
  v_verify text;
  v_res record;
begin
  raise notice '';
  raise notice '--- 3b. Expired verification token ---';

  insert into public.partners (email, portal_token_hash, status)
  values ('expired@example.com', encode(digest('tok-expired', 'sha256'), 'hex'), 'draft')
  returning id into v_id;

  v_verify := encode(gen_random_bytes(32), 'hex');
  perform public.partner_set_verification_token(v_id, v_verify, 1440);

  -- Force expiry into the past.
  update public.partners set email_verify_expires_at = now() - interval '1 minute'
  where id = v_id;

  select * into v_res from public.partner_consume_verification(v_verify);
  perform pg_temp.assert_eq(v_res.ok, false, 'expired token is refused');
  perform pg_temp.assert_eq(v_res.reason, 'expired', 'expiry is reported as "expired"');
end $$;

-- ===========================================================================
-- 4. DRAFT SAVE — column allow-list
-- ===========================================================================
do $$
declare
  v_tok text;
  v_id uuid;
  v_res text;
  v_row public.partners;
begin
  raise notice '';
  raise notice '--- 4. Draft save allow-listing ---';

  -- Get a working session by minting a token we control.
  select id into v_id from public.partners where email = 'test.partner@example.com';
  v_tok := encode(gen_random_bytes(32), 'hex');
  update public.partners set portal_token_hash = encode(digest(v_tok, 'sha256'), 'hex')
  where id = v_id;

  -- Attempt to set PROTECTED columns alongside allowed ones.
  v_res := public.partner_save_draft(v_tok, jsonb_build_object(
    'legal_name', 'Test Partner',
    'applicant_type', 'individual',
    'status', 'approved',
    'affiliate_id', '00000000-0000-4000-8000-000000000000',
    'email_verified', true,
    'decision_note', 'self-approved',
    'commission_amount', 999999
  ));
  perform pg_temp.assert_eq(v_res, 'saved', 'draft save succeeds');

  select * into v_row from public.partners where id = v_id;
  perform pg_temp.assert_eq(v_row.legal_name, 'Test Partner', 'allowed field IS saved');
  perform pg_temp.assert_eq(v_row.status, 'draft', 'status can NOT be set by the client');
  perform pg_temp.assert(v_row.affiliate_id is null, 'affiliate_id can NOT be set by the client');
  perform pg_temp.assert_eq(v_row.email_verified, true, 'email_verified unchanged by draft save');
  perform pg_temp.assert(v_row.decision_note is null, 'decision_note can NOT be set by the client');
  perform pg_temp.assert(v_row.commission_amount is null, 'commission_amount can NOT be set by the client');

  -- An invalid token must not be able to write anything.
  v_res := public.partner_save_draft('bogus-token', jsonb_build_object('legal_name', 'Hacker'));
  perform pg_temp.assert_eq(v_res, 'invalid_session', 'a bad token is refused');
  perform pg_temp.assert(
    (select legal_name from public.partners where id = v_id) <> 'Hacker',
    'a bad token cannot modify any row');
end $$;

-- ===========================================================================
-- 5. CONSTRAINT ENFORCEMENT (the rules a stub cannot verify)
-- ===========================================================================
do $$
declare
  v_id uuid;
begin
  raise notice '';
  raise notice '--- 5. Database constraints ---';

  select id into v_id from public.partners where email = 'test.partner@example.com';

  -- 5a. Under-18 applicants must be rejected.
  begin
    update public.partners set date_of_birth = current_date - interval '10 years' where id = v_id;
    raise exception 'ASSERTION FAILED: a minor was accepted';
  exception when check_violation then
    raise notice '  PASS under-18 date of birth is rejected';
  end;

  -- 5b. Malformed PAN must be rejected.
  begin
    update public.partners set pan_number = 'NOTAPAN123' where id = v_id;
    raise exception 'ASSERTION FAILED: malformed PAN accepted';
  exception when check_violation then
    raise notice '  PASS malformed PAN is rejected';
  end;

  -- 5c. Malformed GSTIN must be rejected.
  begin
    update public.partners set gstin = '12345' where id = v_id;
    raise exception 'ASSERTION FAILED: malformed GSTIN accepted';
  exception when check_violation then
    raise notice '  PASS malformed GSTIN is rejected';
  end;

  -- 5d. An Aadhaar number field does not exist; only a 4-digit mask, and it
  --     requires consent.
  begin
    update public.partners set aadhaar_last4 = '12345' where id = v_id;
    raise exception 'ASSERTION FAILED: a 5-digit Aadhaar mask was accepted';
  exception when check_violation then
    raise notice '  PASS only a 4-digit Aadhaar mask is accepted';
  end;

  begin
    update public.partners set aadhaar_last4 = '1234', aadhaar_consent = false where id = v_id;
    raise exception 'ASSERTION FAILED: Aadhaar digits stored WITHOUT consent';
  exception when check_violation then
    raise notice '  PASS Aadhaar digits cannot be stored without consent';
  end;

  -- 5e. A business must declare its entity type.
  begin
    update public.partners set applicant_type = 'business', entity_type = null where id = v_id;
    raise exception 'ASSERTION FAILED: business accepted without an entity type';
  exception when check_violation then
    raise notice '  PASS a business must declare an entity type';
  end;
  update public.partners set entity_type = 'sole_proprietor' where id = v_id;

  -- 5f. AADHAAR AS A DOCUMENT IS STRUCTURALLY IMPOSSIBLE.
  begin
    insert into public.partner_documents
      (partner_id, doc_type, object_key, mime_type, size_bytes, sha256,
       enc_iv, enc_tag, dek_wrapped, dek_iv, dek_tag)
    values (v_id, 'aadhaar_card', 'k', 'application/pdf', 10, 's',
            'i', 't', 'w', 'wi', 'wt');
    raise exception 'ASSERTION FAILED: an Aadhaar document type was accepted';
  exception when check_violation then
    raise notice '  PASS Aadhaar CANNOT be recorded as a document type (structural)';
  end;

  -- 5g. Purging before the statutory retention floor must be impossible.
  begin
    update public.partners
       set purge_after = now() + interval '1 day'
     where id = v_id;
    raise exception 'ASSERTION FAILED: a purge was scheduled before the retention floor';
  exception when check_violation then
    raise notice '  PASS a purge before the 1-year floor is rejected';
  end;

  -- 5h. A non-draft status REQUIRES all three consent declarations.
  --     This is what makes consent non-bypassable by a crafted API call:
  --     the application cannot reach `submitted` without them.
  declare
    v_consent_ok boolean := false;
  begin
    begin
      insert into public.partners (email, portal_token_hash, status, email_verified)
      values ('no-consent@example.com', encode(digest('nc', 'sha256'), 'hex'), 'submitted', true);
    exception when check_violation then
      v_consent_ok := true;
    end;
    perform pg_temp.assert(v_consent_ok,
      'a submitted application CANNOT exist without all three consent declarations');
  end;

  -- 5i. A DRAFT application may exist without consent (the form is filled first).
  declare
    v_draft_id uuid;
  begin
    insert into public.partners (email, portal_token_hash, status)
    values ('draft-ok@example.com', encode(digest('do', 'sha256'), 'hex'), 'draft')
    returning id into v_draft_id;
    perform pg_temp.assert(v_draft_id is not null, 'a draft MAY exist without consent');
    delete from public.partners where id = v_draft_id;
  end;
end $$;

-- ===========================================================================
-- 6. AUDIT LOG IS APPEND-ONLY
-- ===========================================================================
do $$
declare
  v_id uuid;
  v_audit_id bigint;
  v_ok boolean;
begin
  raise notice '';
  raise notice '--- 6. Audit log is append-only ---';

  select id into v_id from public.partners where email = 'test.partner@example.com';
  select id into v_audit_id from public.partner_audit_log where partner_id = v_id limit 1;

  perform pg_temp.assert(v_audit_id is not null, 'registration was audited');

  -- UPDATE must fail.
  v_ok := false;
  begin
    update public.partner_audit_log set action = 'tampered' where id = v_audit_id;
  exception when others then
    v_ok := true;
  end;
  perform pg_temp.assert(v_ok, 'audit rows cannot be UPDATEd');

  -- DELETE must fail.
  v_ok := false;
  begin
    delete from public.partner_audit_log where id = v_audit_id;
  exception when others then
    v_ok := true;
  end;
  perform pg_temp.assert(v_ok, 'audit rows cannot be DELETEd');

  perform pg_temp.assert(
    (select action from public.partner_audit_log where id = v_audit_id) <> 'tampered',
    'the original audit row is intact');
end $$;

-- ===========================================================================
-- 7. DOCUMENT METADATA + SUPERSEDING
-- ===========================================================================
do $$
declare
  v_id uuid;
  v_tok text;
  v_res record;
  v_live integer;
begin
  raise notice '';
  raise notice '--- 7. Document registration ---';

  select id into v_id from public.partners where email = 'test.partner@example.com';
  v_tok := encode(gen_random_bytes(32), 'hex');
  update public.partners set portal_token_hash = encode(digest(v_tok, 'sha256'), 'hex')
  where id = v_id;

  -- First PAN upload.
  select * into v_res from public.partner_add_document(
    v_tok, 'pan_card', v_id || '/a.pdf.enc', 'pan.pdf',
    'application/pdf', 'application/pdf', 1234,
    repeat('a', 64), 'iv1', 'tag1', 'wr1', 'wiv1', 'wtag1');
  perform pg_temp.assert_eq(v_res.ok, true, 'a PAN document registers');

  -- Re-uploading the same type supersedes rather than deletes.
  select * into v_res from public.partner_add_document(
    v_tok, 'pan_card', v_id || '/b.pdf.enc', 'pan-v2.pdf',
    'application/pdf', 'application/pdf', 2345,
    repeat('b', 64), 'iv2', 'tag2', 'wr2', 'wiv2', 'wtag2');
  perform pg_temp.assert_eq(v_res.ok, true, 'a replacement PAN registers');

  select count(*) into v_live from public.partner_documents
  where partner_id = v_id and doc_type = 'pan_card' and superseded_at is null;
  perform pg_temp.assert_eq(v_live,   1::bigint, 'only ONE live PAN exists after re-upload');

  perform pg_temp.assert(
    (select count(*) from public.partner_documents
      where partner_id = v_id and doc_type = 'pan_card') = 2,
    'the superseded document is retained for the audit trail');

  -- The partner-facing list must expose metadata but never the object key, so
  -- the ciphertext cannot be reached directly by the applicant.
  perform pg_temp.assert(
    (select count(*) from public.partner_list_documents(v_tok)) >= 1,
    'the partner can list their own documents');

  -- Add address proof so submission can succeed.
  select * into v_res from public.partner_add_document(
    v_tok, 'address_proof', v_id || '/addr.png.enc', 'addr.png',
    'image/png', 'image/png', 999,
    repeat('c', 64), 'iv3', 'tag3', 'wr3', 'wiv3', 'wtag3');
  perform pg_temp.assert_eq(v_res.ok, true, 'an address proof registers');
end $$;

-- ===========================================================================
-- 8. SUBMISSION COMPLETENESS
-- ===========================================================================
do $$
declare
  v_id uuid;
  v_tok text;
  v_res record;
  v_missing text[];
begin
  raise notice '';
  raise notice '--- 8. Submission validation ---';

  select id into v_id from public.partners where email = 'test.partner@example.com';
  v_tok := encode(gen_random_bytes(32), 'hex');
  update public.partners set portal_token_hash = encode(digest(v_tok, 'sha256'), 'hex')
  where id = v_id;

  -- Fill everything EXCEPT the consent declarations.
  update public.partners set
    applicant_type = 'individual',
    legal_name = 'Test Partner',
    gender = 'male',
    date_of_birth = '1990-05-04',
    phone = '+919876543210',
    address_line1 = '1 Test Road',
    city = 'Hyderabad',
    state = 'Telangana',
    postal_code = '500001',
    pan_number = 'ABCDE1234F',
    terms_accepted = false,
    privacy_accepted = false,
    truthfulness_declared = false
  where id = v_id;

  select * into v_res from public.partner_submit(v_tok, 'ip');
  perform pg_temp.assert_eq(v_res.ok, false, 'submit is refused without consent');
  perform pg_temp.assert_eq(v_res.status, 'incomplete', 'status reports "incomplete"');
  perform pg_temp.assert('consent' = any(v_res.missing), 'the missing consent is reported');

  -- Now accept the declarations, but remove the required documents.
  update public.partners set
    terms_accepted = true, privacy_accepted = true, truthfulness_declared = true
  where id = v_id;
  update public.partner_documents set superseded_at = now() where partner_id = v_id;

  select * into v_res from public.partner_submit(v_tok, 'ip');
  perform pg_temp.assert_eq(v_res.ok, false, 'submit is refused without documents');
  perform pg_temp.assert('doc:pan_card' = any(v_res.missing), 'missing PAN document is reported');
  perform pg_temp.assert('doc:address_proof' = any(v_res.missing), 'missing address proof is reported');
end $$;

-- ===========================================================================
-- 9. HAPPY PATH TO SUBMISSION
-- ===========================================================================
do $$
declare
  v_id uuid;
  v_tok text;
  v_res record;
begin
  raise notice '';
  raise notice '--- 9. Successful submission ---';

  select id into v_id from public.partners where email = 'test.partner@example.com';
  v_tok := encode(gen_random_bytes(32), 'hex');
  update public.partners set portal_token_hash = encode(digest(v_tok, 'sha256'), 'hex')
  where id = v_id;

  -- Re-add the required documents (the previous ones were superseded).
  perform public.partner_add_document(
    v_tok, 'pan_card', v_id || '/pan3.enc', 'pan.pdf',
    'application/pdf', 'application/pdf', 1000,
    repeat('d', 64), 'i', 't', 'w', 'wi', 'wt');
  perform public.partner_add_document(
    v_tok, 'address_proof', v_id || '/addr3.enc', 'addr.png',
    'image/png', 'image/png', 1000,
    repeat('e', 64), 'i', 't', 'w', 'wi', 'wt');

  select * into v_res from public.partner_submit(v_tok, 'ip');
  perform pg_temp.assert_eq(v_res.ok, true, 'a complete application submits');
  perform pg_temp.assert_eq(v_res.status, 'submitted', 'status becomes "submitted"');
  perform pg_temp.assert(
    (select submitted_at from public.partners where id = v_id) is not null,
    'submitted_at is recorded');

  -- Submission is idempotent.
  select * into v_res from public.partner_submit(v_tok, 'ip');
  perform pg_temp.assert_eq(v_res.ok, true, 're-submitting is not an error');
end $$;

-- ===========================================================================
-- 10. ADMIN REVIEW + APPROVAL (the critical path)
-- ===========================================================================
do $$
declare
  v_id uuid;
  v_res record;
  v_ref text;
  v_coupon text;
  v_aff uuid;
  v_affiliate_count integer;
  v_coupon_count integer;
begin
  raise notice '';
  raise notice '--- 10. Approval issues the partner kit ---';

  select id into v_id from public.partners where email = 'test.partner@example.com';

  select * into v_res from public.partner_admin_list(null);
  perform pg_temp.assert(v_res.id is not null, 'admin list returns applications');

  select * into v_res from public.partner_approve(
    v_id, 'admin@test', 100, null, null, 500, null);
  perform pg_temp.assert_eq(v_res.ok, true, 'approval succeeds');
  perform pg_temp.assert(v_res.referrer_code is not null, 'a referrer code was issued');
  perform pg_temp.assert(v_res.coupon_code is not null, 'a coupon code was issued');
  perform pg_temp.assert(
    v_res.referrer_code ~ '^[A-Z0-9][A-Z0-9-]{2,31}$',
    'the generated referrer code matches the shape the app accepts');
  perform pg_temp.assert(
    left(v_res.referrer_code, 4) = 'SB-P',
    'generated partner referrer codes are prefixed SB-P');

  v_ref := v_res.referrer_code;
  v_coupon := v_res.coupon_code;
  v_aff := v_res.affiliate_id;

  -- The affiliate must exist and be active, because the SHIPPED app reads it.
  perform pg_temp.assert(
    (select status from public.affiliates where id = v_aff) = 'active',
    'the created affiliate is active (the app pipeline needs this)');
  perform pg_temp.assert_eq(
    (select commission_amount from public.affiliates where id = v_aff), 100::numeric,
    'the admin-set commission is stored on the affiliate');
  perform pg_temp.assert(
    (select referrer_code from public.affiliates where id = v_aff) = v_ref,
    'the affiliate carries the referrer code');
  perform pg_temp.assert(
    (select code from public.coupons where affiliate_id = v_aff) = v_coupon,
    'the coupon is linked to the affiliate');
  perform pg_temp.assert_eq(
    (select max_redemptions from public.coupons where affiliate_id = v_aff), 500,
    'the coupon redemption cap is applied');

  perform pg_temp.assert_eq(
    (select status from public.partners where id = v_id), 'approved',
    'the partner is approved');
  perform pg_temp.assert(
    (select approved_at from public.partners where id = v_id) is not null,
    'approved_at is recorded');

  -- IDEMPOTENCY — this is the property that stops duplicate QRs/coupons.
  select count(*) into v_affiliate_count from public.affiliates;
  select count(*) into v_coupon_count from public.coupons;

  select * into v_res from public.partner_approve(v_id, 'admin@test', 100, null, null, null, null);
  perform pg_temp.assert_eq(v_res.ok, true, 're-approving succeeds');
  perform pg_temp.assert_eq(v_res.reason, 'already_approved', 're-approval is reported as idempotent');
  perform pg_temp.assert_eq(v_res.referrer_code, v_ref, 'the SAME referrer code is returned');
  perform pg_temp.assert_eq(v_res.coupon_code, v_coupon, 'the SAME coupon is returned');
  perform pg_temp.assert_eq((select count(*) from public.affiliates), v_affiliate_count,
    'no second affiliate was created');
  perform pg_temp.assert_eq((select count(*) from public.coupons), v_coupon_count,
    'no second coupon was created');
end $$;

-- ===========================================================================
-- 11. APPROVAL GUARDS
-- ===========================================================================
do $$
declare
  v_id uuid;
  v_res record;
  v_dup uuid;
begin
  raise notice '';
  raise notice '--- 11. Approval cannot be abused ---';

  -- A DRAFT application must not be approvable.
  insert into public.partners (email, portal_token_hash, status, email_verified)
  values ('draft-only@example.com', encode(digest('d1', 'sha256'), 'hex'), 'draft', true)
  returning id into v_dup;

  select * into v_res from public.partner_approve(v_dup, 'admin@test', 50, null, null, null, null);
  perform pg_temp.assert_eq(v_res.ok, false, 'a draft application cannot be approved');
  perform pg_temp.assert(v_res.reason like 'invalid_state:%', 'the refusal names the state');

  -- A submitted but UNVERIFIED application must not be approvable.
  -- Consent flags are set because the DB requires them for a `submitted` row.
  update public.partners
     set status = 'submitted', email_verified = false,
         terms_accepted = true, privacy_accepted = true, truthfulness_declared = true
   where id = v_dup;
  select * into v_res from public.partner_approve(v_dup, 'admin@test', 50, null, null, null, null);
  perform pg_temp.assert_eq(v_res.ok, false, 'an unverified applicant cannot be approved');
  perform pg_temp.assert_eq(v_res.reason, 'email_not_verified', 'the reason is email_not_verified');

  -- A duplicate referrer code must be refused.
  update public.partners set email_verified = true where id = v_dup;
  select * into v_res from public.partner_approve(
    v_dup, 'admin@test', 50,
    (select referrer_code from public.affiliates limit 1), null, null, null);
  perform pg_temp.assert_eq(v_res.ok, false, 'a taken referrer code is refused');
  perform pg_temp.assert_eq(v_res.reason, 'referrer_code_taken', 'reason is referrer_code_taken');

  -- A malformed referrer code must be refused.
  select * into v_res from public.partner_approve(v_dup, 'admin@test', 50, 'ab', null, null, null);
  perform pg_temp.assert_eq(v_res.ok, false, 'a too-short referrer code is refused');
  perform pg_temp.assert_eq(v_res.reason, 'invalid_referrer_code', 'reason is invalid_referrer_code');

  -- Clean up the throwaway application so later sections are unaffected.
  delete from public.partners where id = v_dup;
end $$;

-- ===========================================================================
-- 12. DECISIONS: reject / needs_info
-- ===========================================================================
do $$
declare
  v_id uuid;
  v_res record;
  v_purge timestamptz;
  v_floor timestamptz;
begin
  raise notice '';
  raise notice '--- 12. Reject and request-more-info ---';

  -- NOTE: the consent flags are included because `partners_consent_check`
  -- requires them for any non-draft status. That constraint firing here is
  -- itself a useful signal — this fixture is what a real submitted row looks
  -- like, and a row WITHOUT consent cannot exist in a submitted state.
  insert into public.partners
    (email, portal_token_hash, status, email_verified,
     terms_accepted, privacy_accepted, truthfulness_declared)
  values ('reject@example.com', encode(digest('r1', 'sha256'), 'hex'), 'submitted', true,
          true, true, true)
  returning id into v_id;

  select * into v_res from public.partner_decide(v_id, 'admin@test', 'needs_info', 'Please send a clearer PAN.');
  perform pg_temp.assert_eq(v_res.ok, true, 'needs_info is recorded');
  perform pg_temp.assert_eq(v_res.status, 'needs_info', 'status is needs_info');
  perform pg_temp.assert_eq(
    (select decision_note from public.partners where id = v_id),
    'Please send a clearer PAN.', 'the reviewer note is stored');

  select * into v_res from public.partner_decide(v_id, 'admin@test', 'reject', 'Not eligible.');
  perform pg_temp.assert_eq(v_res.status, 'rejected', 'rejection is recorded');

  select purge_after, earliest_purge_at into v_purge, v_floor
  from public.partners where id = v_id;
  perform pg_temp.assert(v_purge is not null, 'a rejection schedules a purge');
  perform pg_temp.assert(v_purge >= v_floor,
    'the purge is NOT earlier than the DPDP retention floor');

  -- An approved application cannot be un-approved by a later decision.
  declare
    v_late record;
  begin
    select * into v_late from public.partner_decide(
      (select id from public.partners where email = 'test.partner@example.com'),
      'admin@test', 'reject', 'too late');
    perform pg_temp.assert_eq(v_late.ok, false, 'an approved application cannot be rejected afterwards');
    perform pg_temp.assert_eq(v_late.reason, 'already_approved', 'the refusal reason is already_approved');
  end;
end $$;

-- ===========================================================================
-- 13. WITHDRAWAL (DPDP s.6(4)) + RETENTION FLOOR
-- ===========================================================================
do $$
declare
  v_id uuid;
  v_tok text;
  v_res record;
  v_floor timestamptz;
begin
  raise notice '';
  raise notice '--- 13. Partner withdrawal ---';

  -- Consent flags are required for a non-draft status (partners_consent_check).
  insert into public.partners
    (email, portal_token_hash, status, email_verified,
     terms_accepted, privacy_accepted, truthfulness_declared)
  values ('withdraw@example.com', encode(digest('w1', 'sha256'), 'hex'), 'submitted', true,
          true, true, true)
  returning id into v_id;

  v_tok := 'w1';

  select * into v_res from public.partner_withdraw(v_tok, 'changed my mind');
  perform pg_temp.assert_eq(v_res.ok, true, 'withdrawal succeeds');
  perform pg_temp.assert_eq(v_res.status, 'withdrawn', 'status becomes withdrawn');
  perform pg_temp.assert(v_res.purge_after is not null, 'the partner is told the purge date');

  select earliest_purge_at into v_floor from public.partners where id = v_id;
  perform pg_temp.assert(v_res.purge_after >= v_floor,
    'purge respects the DPDP one-year retention floor');

  -- The session must be burned so the token cannot be reused.
  select * into v_res from public.partner_get_self(v_tok);
  -- partner_get_self is a setof; handle via count.
  perform pg_temp.assert(
    (select count(*) from public.partner_get_self(v_tok)) = 0,
    'the withdrawn portal session no longer resolves');

  -- Withdrawal is idempotent for a still-valid session.
  update public.partners set portal_token_hash = encode(digest('w2', 'sha256'), 'hex')
  where id = v_id;
  select * into v_res from public.partner_withdraw('w2', null);
  perform pg_temp.assert_eq(v_res.reason, 'already_withdrawn', 'repeat withdrawal is idempotent');
end $$;

-- ===========================================================================
-- 13b. REGRESSION: withdrawal must work WITHOUT consent
-- ===========================================================================
-- A previous revision of partners_consent_check required consent for every
-- status except 'draft'. That made `withdrawn` unreachable for a partner who
-- had never consented — so a partner who withdrew BEFORE agreeing to the terms
-- got a 500. That inverts DPDP Act 2023 s.6(4), where withdrawing must be as
-- easy as giving. This test pins the correct behaviour.
do $$
declare
  v_id uuid;
  v_res record;
begin
  raise notice '';
  raise notice '--- 13b. Withdrawal without prior consent (regression) ---';

  -- A DRAFT row with NO consent declarations at all.
  insert into public.partners (email, portal_token_hash, status)
  values ('withdraw-no-consent@example.com',
          encode(digest('wnc', 'sha256'), 'hex'), 'draft')
  returning id into v_id;

  perform pg_temp.assert(
    (select terms_accepted from public.partners where id = v_id) = false,
    'the fixture has NOT consented');

  select * into v_res from public.partner_withdraw('wnc', 'never agreed');
  perform pg_temp.assert_eq(v_res.ok, true,
    'a partner who never consented CAN still withdraw');
  perform pg_temp.assert_eq(v_res.status, 'withdrawn', 'status is withdrawn');

  perform pg_temp.assert_eq(
    (select status from public.partners where id = v_id), 'withdrawn',
    'the real row is withdrawn');

  -- An active status still REQUIRES consent (the constraint must not have
  -- been weakened for the states that matter).
  declare
    v_blocked boolean := false;
  begin
    begin
      insert into public.partners (email, portal_token_hash, status, email_verified)
      values ('still-blocked@example.com', encode(digest('sb', 'sha256'), 'hex'), 'submitted', true);
    exception when check_violation then
      v_blocked := true;
    end;
    perform pg_temp.assert(v_blocked,
      'a submitted application STILL requires consent (constraint not weakened)');
  end;
end $$;

-- ===========================================================================
-- 14. ADMIN LIST SHAPE
-- ===========================================================================
do $$
declare
  v_count integer;
  v_row record;
begin
  raise notice '';
  raise notice '--- 14. Admin review queue ---';

  select count(*) into v_count from public.partner_admin_list(null);
  perform pg_temp.assert(v_count >= 3, 'the queue lists all applications');

  select count(*) into v_count from public.partner_admin_list('approved');
  perform pg_temp.assert_eq(v_count,   1::bigint, 'status filtering works');

  select * into v_row from public.partner_admin_list('approved') limit 1;
  perform pg_temp.assert(v_row.referrer_code is not null, 'issued referrer code appears in the queue');
  perform pg_temp.assert(v_row.coupon_code is not null, 'issued coupon appears in the queue');
  perform pg_temp.assert(v_row.document_count >= 0, 'document count is reported');
end $$;

-- ===========================================================================
-- 15. GRANT / PRIVILEGE POSTURE
-- ===========================================================================
do $$
declare
  v_ok boolean;
begin
  raise notice '';
  raise notice '--- 15. Privilege posture ---';

  -- The commission-crediting function must NOT be executable by anon.
  select has_function_privilege('anon',
    'public.partner_approve(uuid,text,numeric,text,text,integer,timestamptz)', 'EXECUTE')
  into v_ok;
  perform pg_temp.assert(v_ok = false, 'anon CANNOT execute partner_approve');

  select has_function_privilege('authenticated',
    'public.partner_approve(uuid,text,numeric,text,text,integer,timestamptz)', 'EXECUTE')
  into v_ok;
  perform pg_temp.assert(v_ok = false, 'authenticated CANNOT execute partner_approve');

  select has_function_privilege('service_role',
    'public.partner_approve(uuid,text,numeric,text,text,integer,timestamptz)', 'EXECUTE')
  into v_ok;
  perform pg_temp.assert(v_ok = true, 'service_role CAN execute partner_approve');

  -- Verification-token minting is server-only.
  select has_function_privilege('anon',
    'public.partner_set_verification_token(uuid,text,integer)', 'EXECUTE') into v_ok;
  perform pg_temp.assert(v_ok = false, 'anon CANNOT mint verification tokens');

  -- The public portal CAN register and read itself.
  select has_function_privilege('anon', 'public.partner_register(text,text)', 'EXECUTE') into v_ok;
  perform pg_temp.assert(v_ok = true, 'anon CAN register (public portal)');

  select has_function_privilege('anon', 'public.partner_get_self(text)', 'EXECUTE') into v_ok;
  perform pg_temp.assert(v_ok = true, 'anon CAN read its own application by token');

  -- Credit functions from the affiliate pipeline remain service-only.
  select has_function_privilege('anon',
    'public.credit_affiliate_commission(text,text,numeric,numeric,text)', 'EXECUTE') into v_ok;
  perform pg_temp.assert(v_ok = false, 'anon CANNOT self-credit commissions');
end $$;

-- ===========================================================================
-- 16. CROSS-PARTNER ISOLATION
-- ===========================================================================
do $$
declare
  v_a uuid;
  v_b uuid;
  v_tok_a text;
  v_tok_b text;
begin
  raise notice '';
  raise notice '--- 16. A partner token cannot reach another partner ---';

  v_tok_a := 'iso-a'; v_tok_b := 'iso-b';

  insert into public.partners (email, portal_token_hash, status, email_verified, legal_name)
  values ('iso-a@example.com', encode(digest(v_tok_a, 'sha256'), 'hex'), 'draft', true, 'Partner A')
  returning id into v_a;
  insert into public.partners (email, portal_token_hash, status, email_verified, legal_name)
  values ('iso-b@example.com', encode(digest(v_tok_b, 'sha256'), 'hex'), 'draft', true, 'Partner B')
  returning id into v_b;

  perform pg_temp.assert_eq(
    (select count(*) from public.partner_get_self(v_tok_a)), 1::bigint,
    'partner A resolves exactly one row');
  perform pg_temp.assert_eq(
    (select id from public.partner_get_self(v_tok_a)), v_a,
    'partner A resolves to partner A');

  -- Partner A's token must NOT grant access to partner B's data.
  perform pg_temp.assert(
    not exists (select 1 from public.partner_get_self(v_tok_a) where id = v_b),
    'partner A CANNOT resolve partner B');

  -- A guessed/forged token resolves nothing.
  perform pg_temp.assert_eq(
    (select count(*) from public.partner_get_self('forged-token')), 0::bigint,
    'a forged token resolves nothing');

  -- A partner cannot delete another partner's document.
  perform public.partner_add_document(
    v_tok_b, 'pan_card', v_b || '/pan.enc', 'pan.pdf',
    'application/pdf', 'application/pdf', 10,
    repeat('f', 64), 'i', 't', 'w', 'wi', 'wt');
  declare
    v_doc uuid;
    v_res record;
  begin
    select id into v_doc from public.partner_documents where partner_id = v_b limit 1;
    select * into v_res from public.partner_delete_document(v_tok_a, v_doc);
    perform pg_temp.assert_eq(v_res.ok, false, 'partner A CANNOT delete partner B''s document');
    perform pg_temp.assert(
      exists (select 1 from public.partner_documents where id = v_doc),
      'partner B''s document is still present');
  end;
end $$;

do $$
begin
  raise notice '';
  raise notice '====================================================';
  raise notice ' ALL DATABASE TESTS PASSED';
  raise notice '====================================================';
end $$;
