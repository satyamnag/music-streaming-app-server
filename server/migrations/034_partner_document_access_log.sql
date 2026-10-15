-- ============================================================================
-- 034_partner_document_access_log.sql
-- ============================================================================
-- Adds the RPC that records WHO READ WHICH KYC DOCUMENT, and WHEN.
--
-- WHY THIS MIGRATION EXISTS
-- server/partner_routes.mjs calls `partner_log_document_access` on every
-- document view — success and denial alike — and discards the error:
--
--     const { error } = await supabase.rpc('partner_log_document_access', {...})
--     if (error) log.error('[admin] document access log failed:', error.message)
--
-- That function was never created. Migration 033 defines 27 functions and none
-- of them log document access; `document_access` appears nowhere in it. So the
-- call has been failing silently in production, and document reads have been
-- unaudited.
--
-- This is not cosmetic. The stated reason for proxying document bytes through
-- the server instead of issuing a Supabase signed URL is auditability:
--
--     "Proxying gives a single chokepoint where every access is audited."
--     "a leaked URL is a bearer credential for its whole lifetime"
--
-- Reason 1 traded away revocability in exchange for an audit trail. Without
-- this function that trade bought nothing: there was no record of a read.
--
-- WHY THE ARGUMENTS ARE NAMED p_result / p_reason
-- The calling code passes exactly eight named arguments. The names and order
-- here must match, or PostgREST resolves no function and the call fails again —
-- silently, which is the failure mode being fixed. The TypeScript port
-- (libs/adminPartnerShared.ts) uses the same eight names.
--
-- DESIGN NOTES, all deliberate:
--
--  1. record_type is 'document_access', NOT one of 033's existing action
--     values. The existing partner_audit_log rows describe lifecycle changes
--     (submitted, approved, email_attested). A document read is a different
--     kind of event — a security audit of privileged access — and conflating
--     them would make "who changed this application" and "who looked at this
--     PAN card" impossible to query apart.
--
--  2. NO DOCUMENT CONTENT AND NO PII in `detail`. The table's own comment
--     requires this: "Free-form, non-sensitive detail (NEVER raw PII or
--     document content)." Only the document id, the outcome and a coarse
--     reason code are stored — enough to answer "who saw this", nothing more.
--     The document id is a uuid reference, not content.
--
--  3. The reason is normalised to a CLOSED SET. A free-text reason could carry
--     incidental detail (a filename, a storage key, a decryption error string)
--     into an append-only table that can never be edited to remove it.
--     Unknown reasons collapse to 'other' so the column stays queryable.
--
--  4. It NEVER RAISES for an unknown partner. The caller treats a denied
--     access for a non-existent partner as un-loggable (the FK would reject it)
--     and logs to the console instead. Returning ok=false mirrors that, rather
--     than throwing an error the caller would discard anyway.
--
--  5. It is APPEND-ONLY by construction: the function only ever INSERTs. The
--     partner_audit_log_no_update trigger from 033 raises on UPDATE or DELETE,
--     so even a later bug cannot rewrite history through this path.
--
--  6. service_role ONLY. Document-access records name the admin who looked, so
--     they must not be writable by the anon or authenticated roles, which would
--     let a client forge an access record or flood the log. The partner-facing
--     surface never calls this.
--
-- IDEMPOTENT: safe to re-run. `create or replace` plus `drop ... if exists`
-- for the trigger-free parts, and no data changes.
-- ============================================================================

create or replace function public.partner_log_document_access(
  p_partner_id  uuid,
  p_document_id uuid,
  p_admin       text,
  p_action      text default 'document.view',
  p_result      text default 'success',
  p_reason      text default null,
  p_ip_hash     text default null,
  p_user_agent  text default null
)
returns table (ok boolean, reason text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_action text;
  v_result text;
  v_reason text;
  v_admin  text;
begin
  -- ---- action: closed set ------------------------------------------------
  v_action := coalesce(nullif(trim(coalesce(p_action, '')), ''), 'document.view');
  if v_action not in (
    'document.view',
    'document.review',
    'document.delete',
    'document.upload'
  ) then
    return query select false, 'invalid_action'::text;
    return;
  end if;

  -- ---- result: closed set ------------------------------------------------
  v_result := coalesce(nullif(trim(coalesce(p_result, '')), ''), 'success');
  if v_result not in ('success', 'denied') then
    return query select false, 'invalid_result'::text;
    return;
  end if;

  -- ---- reason: closed set, defaulted per result --------------------------
  -- 'other' rather than the raw string, so an unexpected reason cannot smuggle
  -- free text (a key, a filename, a driver error) into an immutable row.
  v_reason := nullif(trim(coalesce(p_reason, '')), '');
  if v_reason is not null and v_reason not in (
    'not_found',
    'storage_error',
    'decrypt_failed',
    'checksum_mismatch',
    'error',
    'superseded',
    'forbidden'
  ) then
    v_reason := 'other';
  end if;
  if v_result = 'success' then
    -- A success has no failure reason; keeping one would misreport the outcome.
    v_reason := null;
  end if;

  -- ---- actor: an admin identity is REQUIRED ------------------------------
  -- Matches partner_attest_email's rule: a record with no actor is an
  -- unattributable entry in a security log, which is the thing this table
  -- exists to prevent. The caller always has an identity (it falls back to
  -- 'admin-token'), so an empty value here means a caller bug, not a normal
  -- path — refuse rather than write an anonymous row.
  v_admin := nullif(trim(coalesce(p_admin, '')), '');
  if v_admin is null then
    return query select false, 'admin_required'::text;
    return;
  end if;

  -- ---- ids must be present ----------------------------------------------
  if p_partner_id is null or p_document_id is null then
    return query select false, 'invalid_id'::text;
    return;
  end if;

  -- ---- the partner must exist -------------------------------------------
  -- The FK on partner_audit_log.partner_id would reject the insert anyway;
  -- checking first returns a clean reason instead of a raw FK violation, and
  -- keeps the function total. A DENIED access for a partner id that does not
  -- exist lands here — the caller already logs that case to the console,
  -- because an audit row cannot be attributed to a row that is not there.
  if not exists (select 1 from public.partners p where p.id = p_partner_id) then
    return query select false, 'not_found'::text;
    return;
  end if;

  -- ---- append the record -------------------------------------------------
  -- `detail` carries ONLY ids, the outcome and the reason. `left(..., N)`
  -- bounds every text column so an oversized user agent cannot bloat an
  -- append-only table that is never pruned.
  insert into public.partner_audit_log (
    partner_id,
    actor_type,
    actor,
    action,
    detail,
    ip_hash,
    user_agent
  )
  values (
    p_partner_id,
    'admin',
    left(v_admin, 200),
    v_action,
    jsonb_build_object(
      'record_type', 'document_access',
      'document_id', p_document_id,
      'result', v_result,
      'reason', v_reason
    ),
    nullif(left(coalesce(p_ip_hash, ''), 128), ''),
    nullif(left(coalesce(p_user_agent, ''), 400), '')
  );

  return query select true, 'ok'::text;
end;
$$;

comment on function public.partner_log_document_access(uuid, uuid, text, text, text, text, text, text) is
  'Append-only record of an admin reading, reviewing, deleting or uploading a partner KYC document. Stores ids, outcome and a closed-set reason only — never document content or PII. service_role only.';

-- service_role ONLY: these rows name the admin who accessed a document, so the
-- anon/authenticated roles must not be able to forge or flood them. Revoke
-- first so a re-run cannot leave a stale grant in place.
revoke all on function public.partner_log_document_access(uuid, uuid, text, text, text, text, text, text)
  from public, anon, authenticated;
grant execute on function public.partner_log_document_access(uuid, uuid, text, text, text, text, text, text)
  to service_role;

-- ============================================================================
-- VERIFY (run manually; see the accompanying test suite for the automated form)
-- ============================================================================
-- 1. The function exists with the exact 8-argument signature:
--
--      select p.proname, pg_get_function_identity_arguments(p.oid)
--        from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--       where n.nspname = 'public'
--         and p.proname = 'partner_log_document_access';
--
-- 2. A write lands and is attributable:
--
--      select public.partner_log_document_access(
--        '<partner-uuid>'::uuid, '<doc-uuid>'::uuid, 'reviewer@soulfulbhakti.com',
--        'document.view', 'success', null, 'iphash', 'test-agent');
--      select * from public.partner_audit_log
--       where action = 'document.view' order by created_at desc limit 1;
--
-- 3. Immutability still holds (must RAISE):
--
--      update public.partner_audit_log set action = 'tampered'
--       where action = 'document.view';
-- ============================================================================
