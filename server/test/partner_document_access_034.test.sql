-- ============================================================================
-- Behavioural test for public.partner_log_document_access (migration 034).
-- ============================================================================
-- Run against a database with the shim + prerequisite migrations + 033 + 034:
--   psql -p 55432 -U postgres -d sb_partner_test -v ON_ERROR_STOP=1 \
--     -f server/test/partner_document_access_034.test.sql
-- Exit code 0 means every check passed; any failure raises and exits non-zero.
--
-- ---------------------------------------------------------------------------
-- WHAT THIS TESTS, AND WHY IT LOOKS LIKE THIS
-- ---------------------------------------------------------------------------
-- The function returns VOID and is a fire-and-forget audit write. An earlier
-- draft migration replaced it with a table-returning version of my own design,
-- which raised 42P13 in production and would have discarded a working
-- implementation. So this test asserts the contract that ACTUALLY EXISTS:
--
--   * it returns void, so it is called with PERFORM and its effect is observed
--     in partner_audit_log, not in a returned row
--   * p_action and p_result are REQUIRED (no defaults); the body coalesces NULL
--     to 'document.access' and 'unknown' respectively
--   * the row is attributed to actor_type 'admin' with the caller's identity
--   * the user agent is sanitised against log injection and length-bounded
--   * the table stays append-only
--
-- Privileges are checked too, because the function is SECURITY DEFINER: EXECUTE
-- is the security boundary, and rows written this way can never be edited or
-- deleted afterwards.
-- ============================================================================

\set ON_ERROR_STOP on
\pset pager off

do $$
declare
  v_partner uuid;
  v_doc     uuid := gen_random_uuid();
  v_count   int;
  v_detail  jsonb;
  v_actor   text;
  v_action  text;
  v_agent   text;
  v_result  text;
begin
  -- ---- fixture -----------------------------------------------------------
  -- Required columns/constraints discovered by running this against the real
  -- schema rather than guessing:
  --   * portal_token_hash is NOT NULL with no default
  --   * partners_consent_check requires the three consent booleans for any
  --     status other than draft/withdrawn, so 'draft' keeps this focused on the
  --     audit RPC rather than on consent
  insert into public.partners (email, legal_name, status, portal_token_hash)
  values ('audit034@example.com', 'Audit 034 Test', 'draft',
          encode(digest('audit034-fixture', 'sha256'), 'hex'))
  returning id into v_partner;

  raise notice '--- 1. a SUCCESS view is recorded and attributable ---';
  perform public.partner_log_document_access(
    v_partner, v_doc, 'reviewer@soulfulbhakti.com',
    'document.view', 'success', null, 'iphash123', 'test-agent/1.0');

  select count(*) into v_count from public.partner_audit_log
   where partner_id = v_partner and action = 'document.view';
  if v_count <> 1 then raise exception 'expected 1 audit row, got %', v_count; end if;

  select detail, actor into v_detail, v_actor
    from public.partner_audit_log where partner_id = v_partner order by id desc limit 1;

  if v_actor <> 'reviewer@soulfulbhakti.com' then
    raise exception 'actor not recorded: %', v_actor;
  end if;
  if (v_detail->>'document_id')::uuid <> v_doc then
    raise exception 'document_id not recorded: %', v_detail;
  end if;
  if v_detail->>'result' <> 'success' then
    raise exception 'result not recorded: %', v_detail;
  end if;
  raise notice '    ok: row written, actor and document id recorded';

  raise notice '--- 2. actor_type is admin, action is the caller''s value ---';
  select actor_type, action into v_actor, v_action
    from public.partner_audit_log where partner_id = v_partner order by id desc limit 1;
  if v_actor <> 'admin' then
    raise exception 'actor_type should be admin, got %', v_actor;
  end if;
  if v_action <> 'document.view' then
    raise exception 'action should be the caller value, got %', v_action;
  end if;
  raise notice '    ok: actor_type=admin, action=%', v_action;

  raise notice '--- 3. a DENIED view records its reason ---';
  perform public.partner_log_document_access(
    v_partner, v_doc, 'reviewer@soulfulbhakti.com',
    'document.view', 'denied', 'checksum_mismatch', 'iphash123', 'test-agent/1.0');

  select detail into v_detail from public.partner_audit_log
   where partner_id = v_partner order by id desc limit 1;
  if v_detail->>'result' <> 'denied' then
    raise exception 'result not recorded as denied: %', v_detail;
  end if;
  if v_detail->>'reason' <> 'checksum_mismatch' then
    raise exception 'reason not recorded: %', v_detail;
  end if;
  raise notice '    ok: denial audited with result=denied and its reason';

  raise notice '--- 4. a NULL action falls back to document.access ---';
  -- p_action has NO default, but the body coalesces a NULL. Both behaviours are
  -- part of the live contract, so both are pinned.
  perform public.partner_log_document_access(
    v_partner, v_doc, 'reviewer@soulfulbhakti.com',
    null, 'success', null, null, null);
  select action into v_action from public.partner_audit_log
   where partner_id = v_partner order by id desc limit 1;
  if v_action <> 'document.access' then
    raise exception 'null action should fall back to document.access, got %', v_action;
  end if;
  raise notice '    ok: NULL action recorded as document.access';

  raise notice '--- 5. a NULL result falls back to unknown ---';
  perform public.partner_log_document_access(
    v_partner, v_doc, 'reviewer@soulfulbhakti.com', 'document.view', null, null, null, null);
  select detail->>'result' into v_result from public.partner_audit_log
   where partner_id = v_partner order by id desc limit 1;
  if v_result <> 'unknown' then
    raise exception 'null result should fall back to unknown, got %', v_result;
  end if;
  raise notice '    ok: NULL result recorded as unknown';

  raise notice '--- 6. LOG INJECTION: control characters are stripped ---';
  -- An OWASP control carried over from production. A newline or tab in the user
  -- agent could forge a second line in a log reader.
  perform public.partner_log_document_access(
    v_partner, v_doc, 'reviewer@soulfulbhakti.com',
    'document.view', 'success', null, 'iphash', E'evil\r\nINJECTED\tLINE');
  select user_agent into v_agent from public.partner_audit_log
   where partner_id = v_partner order by id desc limit 1;
  if v_agent <> 'evilINJECTEDLINE' then
    raise exception 'control chars not stripped: %', quote_literal(v_agent);
  end if;
  if v_agent ~ '[[:cntrl:]]' then
    raise exception 'control characters survived: %', quote_literal(v_agent);
  end if;
  raise notice '    ok: stored=%, no control characters', quote_literal(v_agent);

  raise notice '--- 7. the user agent is bounded to 300 chars ---';
  perform public.partner_log_document_access(
    v_partner, v_doc, 'reviewer@soulfulbhakti.com',
    'document.view', 'success', null, null, repeat('A', 1000));
  select length(user_agent) into v_count from public.partner_audit_log
   where partner_id = v_partner order by id desc limit 1;
  if v_count <> 300 then
    raise exception 'user agent not bounded to 300, got %', v_count;
  end if;
  raise notice '    ok: truncated to 300 chars';

  raise notice '--- 8. the table is still APPEND-ONLY ---';
  begin
    update public.partner_audit_log set action = 'tampered' where partner_id = v_partner;
    raise exception 'IMMUTABILITY BROKEN: an update succeeded';
  exception
    when others then
      if sqlerrm not like '%append-only%' then raise; end if;
      raise notice '    ok: update rejected';
  end;

  begin
    delete from public.partner_audit_log where partner_id = v_partner;
    raise exception 'IMMUTABILITY BROKEN: a delete succeeded';
  exception
    when others then
      if sqlerrm not like '%append-only%' then raise; end if;
      raise notice '    ok: delete rejected';
  end;

  raise notice '--- 9. no document CONTENT, filename or storage key in detail ---';
  select detail into v_detail from public.partner_audit_log
   where partner_id = v_partner limit 1;
  if v_detail ? 'object_key' or v_detail ? 'file_name' or v_detail ? 'filename'
     or v_detail ? 'content' or v_detail ? 'pan_number' or v_detail ? 'aadhaar' then
    raise exception 'detail carries a sensitive key: %', v_detail;
  end if;
  -- Only these three keys are written by the live function.
  if (select array_agg(k order by k) from jsonb_object_keys(v_detail) k)
     <> array['document_id','reason','result'] then
    raise exception 'unexpected detail keys: %', v_detail;
  end if;
  raise notice '    ok: detail has exactly document_id, reason, result';

  raise notice '';
  raise notice 'ALL 034 BEHAVIOURAL CHECKS PASSED';
end $$;

-- ---------------------------------------------------------------------------
-- 10. Privileges. Checked in its own block because a role-privilege failure is
--     a grant problem, not a function-behaviour problem, and separating them
--     makes the failure message say which.
-- ---------------------------------------------------------------------------
do $$
declare
  v_anon boolean;
  v_auth boolean;
  v_svc  boolean;
begin
  raise notice '--- 10. EXECUTE is restricted to service_role ---';
  select has_function_privilege('anon',
           'public.partner_log_document_access(uuid,uuid,text,text,text,text,text,text)',
           'EXECUTE') into v_anon;
  select has_function_privilege('authenticated',
           'public.partner_log_document_access(uuid,uuid,text,text,text,text,text,text)',
           'EXECUTE') into v_auth;
  select has_function_privilege('service_role',
           'public.partner_log_document_access(uuid,uuid,text,text,text,text,text,text)',
           'EXECUTE') into v_svc;

  if v_anon then raise exception 'anon CAN execute the audit RPC - it must not'; end if;
  if v_auth then raise exception 'authenticated CAN execute the audit RPC - it must not'; end if;
  if not v_svc then raise exception 'service_role CANNOT execute the audit RPC'; end if;

  raise notice '    ok: anon=false authenticated=false service_role=true';
end $$;
