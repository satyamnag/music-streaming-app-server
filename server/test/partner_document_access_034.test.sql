-- ============================================================================
-- Behavioural test for migration 034's partner_log_document_access.
-- Run against a database with the shim + prerequisite migrations + 033 + 034:
--   psql -p 55432 -U postgres -d sb_partner_test -v ON_ERROR_STOP=1 \
--     -f server/test/partner_document_access_034.test.sql
-- Exit code 0 means every check passed; any failure raises and exits non-zero.
-- Fails loudly via `raise exception` so a non-zero exit is visible.
-- ============================================================================

\set ON_ERROR_STOP on
\pset pager off

do $$
declare
  v_partner uuid;
  v_doc     uuid := gen_random_uuid();
  v_ok      boolean;
  v_reason  text;
  v_count   int;
  v_detail  jsonb;
  v_actor   text;
  v_action  text;
begin
  -- ---- fixture -----------------------------------------------------------
  -- Required columns/constraints discovered by running this against the real
  -- schema (not guessed):
  --   * `portal_token_hash` is NOT NULL with no default, so a direct insert
  --     must supply it. A placeholder hash is fine: the token is not what is
  --     under test, and nothing here resolves a partner from it.
  --   * `partners_consent_check` requires terms_accepted, privacy_accepted and
  --     truthfulness_declared to all be true for any status other than
  --     draft/withdrawn. Using 'draft' keeps this fixture focused on the audit
  --     RPC rather than on consent, which 033 already tests elsewhere.
  insert into public.partners (email, legal_name, status, portal_token_hash)
  values ('mig034test@example.com', 'Migration 034 Test', 'draft',
          encode(digest('mig034-fixture-token', 'sha256'), 'hex'))
  returning id into v_partner;

  raise notice '--- 1. a SUCCESS view is recorded and attributable ---';
  select ok, reason into v_ok, v_reason
    from public.partner_log_document_access(
      v_partner, v_doc, 'reviewer@soulfulbhakti.com',
      'document.view', 'success', null, 'iphash123', 'test-agent/1.0');

  if not v_ok then raise exception 'expected ok=true, got ok=% reason=%', v_ok, v_reason; end if;

  select count(*) into v_count from public.partner_audit_log
   where partner_id = v_partner and action = 'document.view';
  if v_count <> 1 then raise exception 'expected 1 audit row, got %', v_count; end if;

  select detail, actor, action into v_detail, v_actor, v_action
    from public.partner_audit_log where partner_id = v_partner and action = 'document.view';

  if v_actor <> 'reviewer@soulfulbhakti.com' then
    raise exception 'actor not recorded: %', v_actor;
  end if;
  if v_detail->>'record_type' <> 'document_access' then
    raise exception 'record_type missing: %', v_detail;
  end if;
  if (v_detail->>'document_id')::uuid <> v_doc then
    raise exception 'document_id not recorded: %', v_detail;
  end if;
  if v_detail->>'result' <> 'success' then
    raise exception 'result not recorded: %', v_detail;
  end if;
  if v_detail->>'reason' is not null then
    raise exception 'a SUCCESS must have no failure reason, got %', v_detail->>'reason';
  end if;
  raise notice '    ok: row written, actor + document id + result recorded, reason null';

  raise notice '--- 2. a DENIED view records its reason ---';
  select ok into v_ok from public.partner_log_document_access(
    v_partner, v_doc, 'reviewer@soulfulbhakti.com',
    'document.view', 'denied', 'checksum_mismatch', 'iphash123', 'test-agent/1.0');
  if not v_ok then raise exception 'denied access should still be logged'; end if;

  select detail into v_detail from public.partner_audit_log
   where partner_id = v_partner and action = 'document.view'
   order by id desc limit 1;
  if v_detail->>'reason' <> 'checksum_mismatch' then
    raise exception 'reason not recorded: %', v_detail;
  end if;
  if v_detail->>'result' <> 'denied' then
    raise exception 'result not recorded as denied: %', v_detail;
  end if;
  raise notice '    ok: denial is audited with its reason';

  raise notice '--- 3. an UNKNOWN reason collapses to other (no free text in an immutable table) ---';
  select ok into v_ok from public.partner_log_document_access(
    v_partner, v_doc, 'reviewer@soulfulbhakti.com',
    'document.view', 'denied', 'leaked /etc/passwd and s3://bucket/key', null, null);
  select detail into v_detail from public.partner_audit_log
   where partner_id = v_partner and action = 'document.view'
   order by id desc limit 1;
  if v_detail->>'reason' <> 'other' then
    raise exception 'free-text reason was NOT collapsed: %', v_detail->>'reason';
  end if;
  raise notice '    ok: unknown reason normalised to "other"';

  raise notice '--- 4. a blank admin is REFUSED (no unattributable rows) ---';
  select ok, reason into v_ok, v_reason from public.partner_log_document_access(
    v_partner, v_doc, '   ', 'document.view', 'success', null, null, null);
  if v_ok then raise exception 'blank admin was accepted'; end if;
  if v_reason <> 'admin_required' then raise exception 'wrong reason: %', v_reason; end if;
  raise notice '    ok: refused with reason=%', v_reason;

  raise notice '--- 5. an unknown partner is refused, not raised ---';
  select ok, reason into v_ok, v_reason from public.partner_log_document_access(
    gen_random_uuid(), v_doc, 'reviewer@soulfulbhakti.com', 'document.view', 'denied', 'not_found', null, null);
  if v_ok then raise exception 'unknown partner was accepted'; end if;
  if v_reason <> 'not_found' then raise exception 'wrong reason: %', v_reason; end if;
  raise notice '    ok: unknown partner refused with reason=%', v_reason;

  raise notice '--- 6. invalid action / result are refused ---';
  select ok, reason into v_ok, v_reason from public.partner_log_document_access(
    v_partner, v_doc, 'a@soulfulbhakti.com', 'document.exfiltrate', 'success', null, null, null);
  if v_ok or v_reason <> 'invalid_action' then
    raise exception 'invalid action accepted: ok=% reason=%', v_ok, v_reason;
  end if;

  select ok, reason into v_ok, v_reason from public.partner_log_document_access(
    v_partner, v_doc, 'a@soulfulbhakti.com', 'document.view', 'maybe', null, null, null);
  if v_ok or v_reason <> 'invalid_result' then
    raise exception 'invalid result accepted: ok=% reason=%', v_ok, v_reason;
  end if;
  raise notice '    ok: closed sets enforced for action and result';

  raise notice '--- 7. null ids are refused ---';
  select ok, reason into v_ok, v_reason from public.partner_log_document_access(
    null, v_doc, 'a@soulfulbhakti.com', 'document.view', 'success', null, null, null);
  if v_ok or v_reason <> 'invalid_id' then
    raise exception 'null partner id accepted: ok=% reason=%', v_ok, v_reason;
  end if;
  raise notice '    ok: null id refused';

  raise notice '--- 8. the actor is BOUNDED at 200 chars ---';
  select ok into v_ok from public.partner_log_document_access(
    v_partner, v_doc, repeat('x', 500) || '@soulfulbhakti.com',
    'document.view', 'success', null, null, null);
  select length(actor) into v_count from public.partner_audit_log
   where partner_id = v_partner and action = 'document.view'
   order by id desc limit 1;
  if v_count <> 200 then raise exception 'actor not bounded to 200, got %', v_count; end if;
  raise notice '    ok: actor truncated to 200 chars';

  raise notice '--- 9. the table is still APPEND-ONLY (update must raise) ---';
  begin
    update public.partner_audit_log set action = 'tampered' where partner_id = v_partner;
    raise exception 'IMMUTABILITY BROKEN: an update succeeded';
  exception
    when others then
      if sqlerrm not like '%append-only%' then raise; end if;
      raise notice '    ok: update rejected (%)', sqlerrm;
  end;

  begin
    delete from public.partner_audit_log where partner_id = v_partner;
    raise exception 'IMMUTABILITY BROKEN: a delete succeeded';
  exception
    when others then
      if sqlerrm not like '%append-only%' then raise; end if;
      raise notice '    ok: delete rejected (%)', sqlerrm;
  end;

  raise notice '--- 10. no document CONTENT or PII in detail ---';
  select detail into v_detail from public.partner_audit_log
   where partner_id = v_partner and action = 'document.view' limit 1;
  if v_detail ? 'object_key' or v_detail ? 'file_name' or v_detail ? 'filename'
     or v_detail ? 'content' or v_detail ? 'pan_number' or v_detail ? 'aadhaar' then
    raise exception 'detail carries a sensitive key: %', v_detail;
  end if;
  -- The only keys present must be the four expected ones.
  if (select array_agg(k order by k) from jsonb_object_keys(v_detail) k)
     <> array['document_id','reason','record_type','result'] then
    raise exception 'unexpected detail keys: %', v_detail;
  end if;
  raise notice '    ok: detail has exactly the 4 expected keys, no content or PII';

  -- cleanup (audit rows cannot be deleted — the fixture partner cascades, but
  -- the trigger blocks it, so this DO block deliberately leaves them in place
  -- and the database is disposable).
  raise notice '';
  raise notice 'ALL 034 BEHAVIOURAL CHECKS PASSED';
end $$;
