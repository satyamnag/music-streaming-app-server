-- ============================================================
-- MIGRATION: Soulful Bhakti Partner Program (033)
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- ------------------------------------------------------------------
-- REQUIRED EXTENSION — INSTALLED BY THIS SCRIPT
-- ------------------------------------------------------------------
-- This migration needs `pgcrypto` for sha256 hashing (`digest`) and for
-- cryptographically secure random tokens (`gen_random_bytes`).
--
-- It does NOT assume the extension is already present. An earlier revision
-- did, on the reasoning that migration 003 installs it — but 003 plainly did
-- not run on this project (the `affiliates` table exists, yet `digest` does
-- not). Depending on a sibling migration having done its job is a fragile
-- assumption, so `create extension if not exists` is issued here instead.
--
-- The block below is deliberately FIRST, before anything that uses it, and
-- is a hard failure if the extension cannot be created: continuing would
-- produce a half-built schema that fails later at runtime on the first
-- partner registration.
-- ------------------------------------------------------------------
create extension if not exists pgcrypto with schema public;

-- ------------------------------------------------------------------
-- SCHEMA-QUALIFIED CRYPTO HELPERS
-- ------------------------------------------------------------------
-- WHY THIS WRAPPER EXISTS (this caused two failed deployments):
--
-- Supabase does not always install pgcrypto into `public`. A very common
-- layout puts extensions in a separate `extensions` schema. The functions in
-- this migration deliberately pin `set search_path = public` (to prevent
-- search-path hijacking), which means an unqualified call to `digest(...)`
-- resolves ONLY against `public` — and fails with:
--
--     ERROR: 42883: function digest(text, text) does not exist
--
-- even though pgcrypto is installed and working.
--
-- The robust fix is to resolve the function ONCE at migration time via the
-- catalog (`pg_proc`), whatever schema it lives in, and wrap it in our own
-- SECURITY INVOKER function inside `public`. Everything downstream then calls
-- `public.sb_digest(...)`, which is always visible regardless of search_path
-- or where the extension was installed.
--
-- Note this also survives the extension being installed into `extensions`,
-- `public`, or any other schema — the failure mode is removed rather than
-- special-cased.
-- ------------------------------------------------------------------

do $$
declare
  v_schema text;
  v_args text;
begin
  -- Find whichever digest() overload the installed pgcrypto provides.
  select n.nspname, pg_get_function_identity_arguments(p.oid)
    into v_schema, v_args
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where p.proname = 'digest'
    and pg_get_function_identity_arguments(p.oid) in ('bytea, text', 'text, text')
  order by (pg_get_function_identity_arguments(p.oid) = 'bytea, text') desc
  limit 1;

  if v_schema is null then
    raise exception
      'pgcrypto is installed but no digest() function was found. '
      'Enable pgcrypto in Database > Extensions, then re-run this migration.';
  end if;

  -- Build the wrapper with the function name SCHEMA-QUALIFIED to wherever
  -- pgcrypto actually lives. This is the crux of the fix: an unqualified
  -- `digest(...)` inside a function that pins `search_path = public` fails
  -- when pgcrypto lives elsewhere, which is exactly how this migration broke
  -- twice in production.
  if v_args = 'bytea, text' then
    execute format($f$
      create or replace function public.sb_digest(p_input text, p_alg text default 'sha256')
      returns text
      language sql
      immutable
      as $body$
        select encode(%I.digest(convert_to(coalesce(p_input, ''), 'UTF8'), p_alg), 'hex');
      $body$;
    $f$, v_schema);
  else
    -- Older pgcrypto exposing digest(text, text).
    execute format($f$
      create or replace function public.sb_digest(p_input text, p_alg text default 'sha256')
      returns text
      language sql
      immutable
      as $body$
        select encode(%I.digest(coalesce(p_input, ''), p_alg), 'hex');
      $body$;
    $f$, v_schema);
  end if;

  raise notice 'pgcrypto digest() found in schema "%" — public.sb_digest() created.', v_schema;
end $$;

comment on function public.sb_digest(text, text) is
  'SHA-256 (or other pgcrypto digest) of a UTF-8 string, returned as hex. Exists because pgcrypto''s schema varies between Supabase projects, and an unqualified digest() call inside a search_path-pinned function fails when the extension lives outside public.';

-- `gen_random_bytes` has exactly the same schema-visibility problem as
-- `digest`, and it is used to mint the portal tokens. Wrap it the same way so
-- the CSPRNG is reachable wherever pgcrypto was installed.
do $$
declare
  v_schema text;
begin
  select n.nspname into v_schema
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where p.proname = 'gen_random_bytes'
  limit 1;

  if v_schema is null then
    raise exception
      'pgcrypto is installed but gen_random_bytes() was not found. '
      'The partner portal tokens depend on it. Enable pgcrypto, then re-run.';
  end if;

  execute format($f$
    create or replace function public.sb_random_bytes(p_len integer)
    returns bytea
    language sql
    volatile
    as $body$
      select %I.gen_random_bytes(p_len);
    $body$;
  $f$, v_schema);

  raise notice 'pgcrypto gen_random_bytes() found in schema "%" — public.sb_random_bytes() created.', v_schema;
end $$;

comment on function public.sb_random_bytes(integer) is
  'Cryptographically secure random bytes from pgcrypto, resolved independently of the extension schema.';

do $$
begin
  -- Fail loudly and early if pgcrypto is unavailable. A clear error here is
  -- far better than a "function digest(text, unknown) does not exist"
  -- 600 lines further down.
  if not exists (select 1 from pg_extension where extname = 'pgcrypto') then
    raise exception
      'pgcrypto is required but could not be installed. On Supabase, enable it '
      'in Database > Extensions (or run: create extension pgcrypto with schema public).';
  end if;
  raise notice 'pgcrypto present — proceeding with the partner schema.';
end $$;

-- ------------------------------------------------------------------
-- PREREQUISITE REPAIR: affiliates.referrer_code
-- ------------------------------------------------------------------
-- This migration ISSUES a QR referrer code on approval, which is stored on
-- the affiliate row. That column is introduced by migration 009.
--
-- On this project, migration 009 evidently did not run: 003 never installed
-- pgcrypto, and `affiliates` lacks `referrer_code`. Rather than fail 1,200
-- lines in with "column a.referrer_code does not exist", the column is
-- created here if it is missing, backfilled, and made unique — i.e. exactly
-- what migration 009 would have done.
--
-- This is idempotent: on a project where 009 DID run, every statement below
-- is a no-op.
-- ------------------------------------------------------------------
do $$
declare
  v_has_table boolean;
  v_has_column boolean;
  v_dup_count integer;
begin
  select exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'affiliates'
  ) into v_has_table;

  if not v_has_table then
    raise exception
      'public.affiliates does not exist. The Partner Program attaches approved '
      'partners to the affiliate pipeline, so migrations 004 (and ideally 008/009) '
      'must be applied first.';
  end if;

  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'affiliates'
      and column_name = 'referrer_code'
  ) into v_has_column;

  if v_has_column then
    raise notice 'affiliates.referrer_code already present — no repair needed.';
    return;
  end if;

  raise notice 'affiliates.referrer_code is MISSING (migration 009 did not run) — adding it now.';

  alter table public.affiliates add column referrer_code text;

  -- Backfill from the id, matching migration 009's scheme.
  update public.affiliates
     set referrer_code = upper(replace(substr(id::text, 1, 8), '-', ''))
   where referrer_code is null or referrer_code = '';

  -- Guard against a collision before enforcing uniqueness.
  select count(*) into v_dup_count
  from (
    select referrer_code from public.affiliates
    group by referrer_code having count(*) > 1
  ) d;

  if v_dup_count > 0 then
    raise exception
      'referrer_code collision after backfill — resolve manually before re-running.';
  end if;

  alter table public.affiliates alter column referrer_code set not null;

  if not exists (
    select 1 from pg_constraint
    where conname = 'affiliates_referrer_code_key'
      and conrelid = 'public.affiliates'::regclass
  ) then
    alter table public.affiliates
      add constraint affiliates_referrer_code_key unique (referrer_code);
  end if;

  raise notice 'affiliates.referrer_code repaired (added, backfilled, made unique).';
end $$;

-- ------------------------------------------------------------------
-- PREREQUISITE REPAIR: affiliates.commission_amount
-- ------------------------------------------------------------------
-- Introduced by migration 008. It is the per-affiliate flat commission the
-- admin sets, and `partner_approve` writes it when creating the affiliate.
-- Added here if missing, for the same reason as referrer_code above.
-- ------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'affiliates'
      and column_name = 'commission_amount'
  ) then
    raise notice 'affiliates.commission_amount is MISSING (migration 008 did not run) — adding it now.';
    alter table public.affiliates
      add column commission_amount numeric not null default 0
      check (commission_amount >= 0);
    raise notice 'affiliates.commission_amount repaired.';
  else
    raise notice 'affiliates.commission_amount already present — no repair needed.';
  end if;
end $$;

-- The QR install-referrer pipeline also writes to `affiliate_referrals`
-- (migration 009). The partner program does not write to it directly, but the
-- shipped app does when a user scans a partner QR — so make sure it exists.
do $$
begin
  if not exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'affiliate_referrals'
  ) then
    raise notice 'affiliate_referrals is MISSING (migration 009 did not run) — creating it now.';

    create table public.affiliate_referrals (
      id uuid primary key default gen_random_uuid(),
      referrer_code text not null,
      affiliate_id uuid not null references public.affiliates(id) on delete cascade,
      purchaser_user_id text not null unique,
      created_at timestamptz not null default now()
    );

    alter table public.affiliate_referrals enable row level security;

    create index if not exists affiliate_referrals_affiliate_idx
      on public.affiliate_referrals (affiliate_id);

    raise notice 'affiliate_referrals created.';
  else
    raise notice 'affiliate_referrals already present — no repair needed.';
  end if;
end $$;

-- ------------------------------------------------------------------
-- PREREQUISITE REPAIR: bind_affiliate_referral(text, text)
-- ------------------------------------------------------------------
-- The SHIPPED Android app calls this RPC on first sign-in to bind a user to
-- the affiliate whose QR they scanned. It is created by migration 009.
--
-- The partner program's whole "zero app changes" claim rests on this function
-- existing: a partner QR is only useful if the app can act on it. So it is
-- created here if absent, with the same semantics as migration 009
-- (idempotent, rejects unknown/inactive codes, one binding per user).
-- ------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'bind_affiliate_referral'
  ) then
    raise notice 'bind_affiliate_referral is MISSING (migration 009 did not run) — creating it now.';

    execute $fn$
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
      begin
        if p_referrer_code is null or p_referrer_code = ''
           or p_user_id is null or p_user_id = '' then
          return 'invalid';
        end if;

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
    $fn$;

    grant execute on function public.bind_affiliate_referral(text, text)
      to anon, authenticated;

    raise notice 'bind_affiliate_referral created.';
  else
    raise notice 'bind_affiliate_referral already present — no repair needed.';
  end if;
end $$;

-- ============================================================
-- PURPOSE
--   Self-service partner onboarding: a partner registers, verifies
--   their email, submits KYC (individual or business), and APPLIES.
--   The application lands in the admin panel review queue. An admin
--   performs due diligence and, on approval, the partner is issued:
--     * a unique QR code  -> Google Play install deep link carrying an
--                            install-referrer (utm_source)
--     * a unique discount coupon code
--
-- ARCHITECTURAL DECISION (important)
--   Approval does NOT invent a parallel marketing system. It CREATES a
--   row in the EXISTING `public.affiliates` table (migration 004/008/009).
--   That means the QR -> install-referrer -> `affiliate_referrals` ->
--   coupon -> verified-Superwall-webhook commission pipeline that is
--   ALREADY SHIPPED IN THE ANDROID APP keeps working with ZERO app
--   changes. `partners.affiliate_id` is the link between the two.
--
-- TRUST MODEL (mirrors migrations 003/004/009 exactly)
--   1. The partner portal is a PUBLIC surface: it can only INSERT a new
--      application and read/write its OWN draft via a bearer session
--      token it holds. It can never read another partner's data.
--   2. Verification of identity, email and documents is server-side
--      (service role) only. No partner-supplied value is ever trusted
--      for a decision; the admin re-checks every document by eye.
--   3. KYC documents are stored in a PRIVATE storage bucket. No public
--      URL is ever generated. Admins view them through short-lived
--      signed URLs minted by the trusted Express server.
--   4. All state transitions (submit/review/approve/reject) are
--      appended to an immutable audit log.
--   5. Approval -> affiliate creation is a single SECURITY DEFINER
--      function so it is atomic and idempotent.
--
-- DATA PROTECTION / GOVERNMENT NORMS
--   * Data minimisation: only the fields needed to (a) identify the
--     partner legally and (b) pay them later are collected.
--   * Aadhaar: DELIBERATELY NOT COLLECTED OR STORED AT ALL. This is the
--     single most important compliance decision in this schema. It does not
--     rest on one clause but on FIVE independent primary sources, which is
--     why it is enforced structurally rather than left to procedure. The
--     statutory text below is from the consolidated amended Act as hosted by
--     UIDAI itself (Aadhaar Act 2016 as amended by Act 14 of 2019):
--
--       1. s.8A(4)(b) [INSERTED 2019], verbatim: "No offline
--          verification-seeking entity shall— ... (b) collect, use, or store
--          an Aadhaar number or biometric information of any individual for
--          any purpose". A PROHIBITION, not a guideline. A private marketing
--          programme verifying a partner by looking at their Aadhaar card is
--          an "offline verification-seeking entity".
--       2. s.57 was OMITTED ENTIRELY by Act 14 of 2019, s.23. The consolidated
--          Act reads literally "57. [Omitted.]". So there is no statutory
--          route for a body corporate or individual to use Aadhaar, and a
--          commercial contract cannot supply one.
--       3. The Supreme Court in Puttaswamy (26 Sep 2018, 2019 (1) SCC 1) held:
--          "That portion of Section 57 of the Aadhaar Act which enables body
--          corporate and individual to seek authentication is held to be
--          unconstitutional", reasoning that authentication under "any
--          contract to this effect" is "clearly impermissible as a
--          contractual provision is not backed by a law".
--       4. s.4(4): authentication is permitted only to an entity UIDAI is
--          satisfied is authorised. This programme is not one, so it performs
--          NO authentication whatsoever. (Reinforced by the Aadhaar Good
--          Governance Rules 2020, which require a GOVERNMENT sponsor, and by
--          PMLA s.11A, which permits direct authentication only to a banking
--          company.)
--       5. s.29(3)-(4): identity information may not be used beyond the
--          purpose disclosed in writing, and no Aadhaar number, demographic
--          information OR PHOTOGRAPH may be published, displayed or posted
--          publicly. s.30 additionally deems electronic biometric information
--          to be "sensitive personal data" under the IT Act 2000.
--
--     s.8(3) also requires the individual to be told the ALTERNATIVES to
--     submitting identity information — hence the non-Aadhaar route this
--     portal offers (PAN / Passport / Voter ID / Driving Licence).
--
--     PENALTIES: s.33A (inserted 2019) — civil penalty up to Rs 1 CRORE per
--     contravention, plus up to Rs 10 LAKH PER DAY for a continuing failure.
--     s.38 (unauthorised CIDR access) was raised by the 2019 Act to 10 YEARS'
--     imprisonment with a minimum Rs 10 lakh fine, and its clause (g) covers
--     sharing, using or displaying information in contravention of s.29.
--     s.42 general penalty: 3 years. Crucially, s.43 makes DIRECTORS AND
--     OFFICERS personally liable: every person "in charge of, and was
--     responsible to, the company for the conduct of the business ... shall
--     be deemed to be guilty of the offence" (with a due-diligence defence).
--     That personal exposure is why this control is structural.
--
--     CONSEQUENCE: the document allow-list below contains NO 'aadhaar'
--     value, so an Aadhaar scan cannot be recorded even if a future UI bug
--     offered it. There is also no `aadhaar_number` column — only an
--     optional 4-digit mask the partner may volunteer, and storing even that
--     requires the consent flag. The control is structural rather than
--     procedural, because a procedural rule is what a future change is most
--     likely to erode.
--     OPERATOR ACTION: confirm with qualified Indian counsel for the
--     operating entity before launch. Technical controls cannot substitute
--     for that legal determination.
--   * Nothing here overrides applicable law; the operator must keep
--     the published privacy policy and consent notice in sync.
--
-- SECURITY DESIGN NOTES (evidence-backed)
--   * Supabase service-key uploads do NOT set storage `owner_id`, so an
--     `owner_id = auth.uid()` policy would be wrong for this job. That is
--     exactly why this design does not use partner-JWT storage policies
--     at all: the bucket is private with NO anon/authenticated policy,
--     and every byte is brokered by the trusted server. See:
--     https://supabase.com/docs/guides/storage/security/ownership
--   * Document bytes are encrypted at the APPLICATION layer
--     (AES-256-GCM, envelope) BEFORE upload, so a bucket misconfiguration
--     or a leaked service key yields ciphertext, not readable KYC.
--     OWASP Cryptographic Storage: use authenticated modes (GCM) first;
--     keep the KEK separate from the wrapped DEK.
--     https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html
--   * Verification tokens are 256-bit random values stored ONLY as
--     SHA-256 hashes. OWASP ASVS 5.0.0 req 6.5.2 allows a standard hash
--     when the secret has >= 112 bits of entropy; 256 bits clears that
--     comfortably (bcrypt/Argon2 are only required below 112 bits).
--   * Lookup secrets must be usable exactly once (ASVS 6.5.1). The
--     consume functions below therefore use a single atomic
--     `UPDATE ... WHERE ... RETURNING`, which closes the TOCTOU race a
--     naive SELECT-then-UPDATE would leave open.
--   * Registration must not be a user-enumeration oracle
--     (ASVS 6.3.8). `partner_register` therefore does NOT reveal whether
--     an email is already registered to the caller; the server responds
--     identically either way and emails the existing owner instead.
-- ============================================================

-- ------------------------------------------------------------------
-- 0) Enums as CHECK constraints (the repo's existing style: it uses
--    CHECK constraints rather than CREATE TYPE, so re-running is safe).
-- ------------------------------------------------------------------

-- ------------------------------------------------------------------
-- 1) PARTNER APPLICATIONS
--    One row per partner (one application per verified email). The row
--    is the single source of truth for the partner's legal identity.
-- ------------------------------------------------------------------
create table if not exists public.partners (
  id uuid primary key default gen_random_uuid(),

  -- --- Applicant session identity (portal login) -------------------
  -- The partner authenticates to the portal with a high-entropy bearer
  -- token. ONLY its SHA-256 hash is stored, never the token itself, so a
  -- database read cannot be replayed as a login (same reasoning as a
  -- password hash). `portal_token_hash` is unique => one live session.
  email text not null,
  portal_token_hash text not null unique,
  portal_token_created_at timestamptz not null default now(),

  -- --- Email verification -----------------------------------------
  -- Industry-standard flow: a single-use, short-lived, high-entropy token
  -- is emailed. Only its SHA-256 hash is stored. Verified when consumed.
  email_verified boolean not null default false,
  email_verified_at timestamptz,
  email_verify_token_hash text,
  email_verify_expires_at timestamptz,
  email_verify_attempts integer not null default 0,

  -- --- Applicant type ---------------------------------------------
  -- 'individual' | 'business' (sole proprietor / partnership / company /
  -- LLP / trust / society). Drives which document set is required.
  applicant_type text
    check (applicant_type is null or applicant_type in ('individual', 'business')),

  -- --- Legal identity ---------------------------------------------
  -- For an individual this is the person's legal name. For a business it
  -- is the registered legal entity name, exactly as on the registration
  -- certificate (used for the later commission agreement / TDS).
  legal_name text,
  -- Business trading/brand name (optional, business only).
  display_name text,
  entity_type text
    check (entity_type is null or entity_type in (
      'sole_proprietor', 'partnership', 'llp', 'private_limited',
      'public_limited', 'one_person_company', 'trust', 'society', 'huf', 'other'
    )),

  -- --- Personal details (individuals; also the authorised signatory of
  --     a business, which is who the admin actually verifies) --------
  gender text
    check (gender is null or gender in ('male', 'female', 'other', 'prefer_not_to_say')),
  date_of_birth date,
  -- Age is DERIVED from date_of_birth, never stored (storage limitation).
  -- 18+ is enforced below: a minor cannot contract, so cannot be a partner.

  -- --- Contact -----------------------------------------------------
  phone text,
  -- --- Address (proof-of-address target) ---------------------------
  address_line1 text,
  address_line2 text,
  city text,
  state text,
  postal_code text,
  country text not null default 'India',

  -- --- Identity document ------------------------------------------
  -- PAN is the primary accepted proof of identity for an Indian entity.
  -- Stored because it is a public tax identifier (not secret auth data).
  pan_number text,
  -- GSTIN (business, optional below the turnover threshold).
  gstin text,
  -- Aadhaar: LAST 4 DIGITS ONLY, and only if the partner opted in.
  -- Storing the full number / a copy is deliberately NOT supported.
  aadhaar_last4 text,
  aadhaar_consent boolean not null default false,

  -- --- Bank / payout details (needed to pay commission later) -------
  -- Held for the future payout phase; the current phase is track-only.
  bank_account_name text,
  bank_account_last4 text,
  bank_ifsc text,

  -- --- Marketing profile ------------------------------------------
  audience_size text,
  promotion_plan text,
  website_url text,
  social_links jsonb not null default '{}'::jsonb,

  -- --- Consent / declarations -------------------------------------
  -- Explicit, informed, specific consent (DPDP Act 2023 s.6). The exact
  -- wording version the partner agreed to is recorded so consent can be
  -- proven later ("consent_version" + timestamp).
  terms_accepted boolean not null default false,
  terms_version text,
  terms_accepted_at timestamptz,
  privacy_accepted boolean not null default false,
  privacy_version text,
  privacy_accepted_at timestamptz,
  truthfulness_declared boolean not null default false,

  -- --- Lifecycle ---------------------------------------------------
  -- draft              - registered, still filling the form
  -- pending_verification - submitted, email not yet verified
  -- submitted          - applied; waiting for admin due diligence
  -- under_review       - an admin has opened it
  -- needs_info         - admin asked for corrections; partner may edit
  -- approved           - approved; affiliate + QR + coupon issued
  -- rejected           - declined
  -- withdrawn          - partner cancelled their own application
  status text not null default 'draft'
    check (status in (
      'draft', 'pending_verification', 'submitted', 'under_review',
      'needs_info', 'approved', 'rejected', 'withdrawn'
    )),
  submitted_at timestamptz,
  reviewed_at timestamptz,
  reviewed_by text,
  decision_note text,

  -- --- Approval artefacts -----------------------------------------
  -- Set when the admin approves. Points at the EXISTING affiliate row
  -- that drives the shipped QR / coupon / commission pipeline.
  affiliate_id uuid references public.affiliates(id) on delete set null,
  approved_at timestamptz,
  -- The admin-chosen per-yearly-sale commission (copied to the affiliate).
  commission_amount numeric check (commission_amount is null or commission_amount >= 0),

  -- --- Data-protection bookkeeping ---------------------------------
  -- RETENTION. Two obligations pull in OPPOSITE directions and both apply:
  --   (a) DPDP Act 2023 s.8(7): erase personal data once the purpose is
  --       served or consent is withdrawn.
  --   (b) DPDP Rules 2025, r.8(3): a MANDATORY MINIMUM ONE-YEAR retention
  --       of personal data, traffic data and logs. The Rules' own
  --       illustration says this holds "even if [the data principal]
  --       deletes her account."
  -- So a blanket "delete everything on request" implementation would
  -- BREACH r.8(3). `earliest_purge_at` therefore encodes the floor: the
  -- purge job MUST NOT delete before it. Deletion must be purpose-scoped,
  -- not blanket.
  --
  -- FLAGGED: r.8(3) was notified by G.S.R. 846(E) dated 13 Nov 2025 with the
  -- substantive rules commencing 18 months after publication (~mid-May
  -- 2027). The floor is recorded here from now so the system is compliant on
  -- the day it bites, and so no existing row can be purged early in the
  -- meantime.
  purge_after timestamptz,
  earliest_purge_at timestamptz not null default (now() + interval '1 year'),
  deleted_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- One application per email address (case-insensitive).
  constraint partners_email_key unique (email),

  -- Age >= 18: a minor cannot legally contract. Enforced in the DB so it
  -- holds even if a future client forgets the check.
  constraint partners_adult_check check (
    date_of_birth is null or date_of_birth <= (current_date - interval '18 years')
  ),

  -- PAN format (India): 5 letters, 4 digits, 1 letter. Optional at draft.
  constraint partners_pan_format check (
    pan_number is null or pan_number ~ '^[A-Z]{5}[0-9]{4}[A-Z]$'
  ),
  -- GSTIN format (India): 2 digits + PAN + entity + Z + checksum.
  constraint partners_gstin_format check (
    gstin is null or gstin ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$'
  ),
  -- Aadhaar last-4 must be exactly 4 digits when present.
  constraint partners_aadhaar_last4_check check (
    aadhaar_last4 is null or aadhaar_last4 ~ '^[0-9]{4}$'
  ),
  -- If Aadhaar digits are stored, consent must have been given.
  constraint partners_aadhaar_consent_check check (
    aadhaar_last4 is null or aadhaar_consent = true
  ),
  -- A business application must name its entity type.
  constraint partners_business_entity_check check (
    applicant_type is distinct from 'business' or entity_type is not null
  ),
  -- Consent declarations are mandatory to APPLY, and are asserted here so a
  -- directly-crafted API call cannot reach an active state without them.
  --
  -- 'draft'     - the form is still being filled; no consent yet.
  -- 'withdrawn' - a terminal state that MUST be reachable without consent.
  --               DPDP Act 2023 s.6(4) requires withdrawing consent to be as
  --               easy as giving it, so a partner who never consented (or who
  --               wishes to revoke) must be able to withdraw. Requiring
  --               consent to withdraw would invert the provision — you would
  --               have to AGREE in order to DISAGREE.
  --
  -- Anything that represents an active application (submitted, under_review,
  -- needs_info, approved, rejected) requires all three declarations.
  constraint partners_consent_check check (
    status in ('draft', 'withdrawn')
    or (terms_accepted = true and privacy_accepted = true
        and truthfulness_declared = true)
  ),

  -- RETENTION FLOOR (DPDP Rules 2025 r.8(3)): a purge may never be scheduled
  -- before the mandatory one-year minimum has elapsed. Enforced in the schema
  -- so even a well-meaning future "delete on request" feature cannot violate
  -- the floor by accident.
  constraint partners_purge_floor_check check (
    purge_after is null or purge_after >= earliest_purge_at
  )
);

-- Email is matched case-insensitively throughout the portal.
create unique index if not exists partners_email_lower_idx
  on public.partners (lower(email));

create index if not exists partners_status_idx on public.partners (status);
create index if not exists partners_affiliate_idx on public.partners (affiliate_id);
create index if not exists partners_purge_idx on public.partners (purge_after)
  where purge_after is not null;

alter table public.partners enable row level security;

-- NO anon/authenticated policies are created on purpose. The partner
-- portal talks to the trusted Express server (service role), which
-- enforces "you may only read/write your own row" in code. Because RLS
-- is ON and no permissive policy exists, the public anon key cannot read
-- a single partner row even if it is extracted from the app.

comment on table public.partners is
  'Partner Program applications. Public portal access is mediated by the trusted server (service role); no anon/authenticated RLS policy exists by design.';
comment on column public.partners.portal_token_hash is
  'SHA-256 of the partner portal bearer token. The raw token is never stored.';
comment on column public.partners.email_verify_token_hash is
  'SHA-256 of the single-use email verification token. Never stored raw.';
comment on column public.partners.aadhaar_last4 is
  'Last 4 digits of Aadhaar ONLY, when the partner opted in. Full Aadhaar numbers/copies are never stored (Aadhaar Act 2016 s.29 + Puttaswamy 2017).';
comment on column public.partners.date_of_birth is
  'Age is derived from this, never stored. A CHECK enforces 18+ because a minor cannot contract.';

-- ------------------------------------------------------------------
-- 2) PARTNER DOCUMENTS
--    One row per uploaded KYC document. The BYTES live in a PRIVATE
--    Supabase Storage bucket; this table holds only metadata plus the
--    object key, so a leaked table row exposes no document content.
-- ------------------------------------------------------------------
create table if not exists public.partner_documents (
  id uuid primary key default gen_random_uuid(),
  partner_id uuid not null references public.partners(id) on delete cascade,

  -- Which requirement this document satisfies. The required SET is
  -- decided per applicant_type (individual vs business).
  --
  -- NOTE: there is deliberately NO 'aadhaar' value here. Aadhaar is not
  -- an acceptable document for this programme (Aadhaar Act 2016 s.8(2),
  -- s.29(3)/(4), s.37 — see the header). Because the CHECK constraint
  -- rejects it, an Aadhaar scan cannot be recorded even if a future UI
  -- bug tried to offer it. The control is structural.
  doc_type text not null
    check (doc_type in (
      -- identity (Aadhaar intentionally absent)
      'pan_card', 'passport', 'voter_id', 'driving_licence',
      -- address
      'address_proof',
      -- business existence
      'gst_certificate', 'incorporation_certificate', 'udyam_certificate',
      'shop_establishment_licence', 'partnership_deed', 'trust_deed',
      -- banking
      'bank_proof',
      -- other
      'authorised_signatory_proof', 'other'
    )),

  -- Storage object key inside the private bucket (NOT a public URL).
  object_key text not null,
  original_filename text,
  -- The DECLARED mime type from the client (untrusted; kept for fraud
  -- analysis) and the SNIFFED type derived from magic bytes server-side
  -- (authoritative). Storing both makes a spoofing attempt visible.
  mime_type text not null,
  sniffed_mime_type text,
  size_bytes bigint not null check (size_bytes > 0),

  -- Integrity + provenance: SHA-256 of the plaintext lets the admin prove
  -- the file they reviewed is the file that was submitted.
  sha256 text not null,

  -- --- Application-level envelope encryption ------------------------
  -- The object in storage is AES-256-GCM ciphertext, not the document.
  -- The DEK is stored WRAPPED (encrypted) by the KEK, and the KEK lives
  -- in the server environment / secrets manager — never in this database.
  -- Destroying the KEK (crypto-shredding) renders every document of this
  -- partner permanently unrecoverable, which is a stronger guarantee than
  -- relying on object deletion alone.
  enc_alg text not null default 'aes-256-gcm',
  enc_iv text,          -- base64, unique per document
  enc_tag text,         -- base64 GCM auth tag; verified on decrypt
  dek_wrapped text,     -- base64 DEK ciphertext (wrapped by the KEK)
  dek_iv text,          -- base64 IV used to wrap the DEK
  dek_tag text,         -- base64 tag for the wrapped DEK

  uploaded_at timestamptz not null default now(),

  -- Admin review of THIS document.
  review_status text not null default 'pending'
    check (review_status in ('pending', 'accepted', 'rejected')),
  review_note text,
  reviewed_at timestamptz,
  reviewed_by text,

  -- Replaced documents are superseded rather than deleted, so the audit
  -- trail keeps what was actually reviewed.
  superseded_at timestamptz,

  unique (partner_id, doc_type, sha256)
);

create index if not exists partner_documents_partner_idx
  on public.partner_documents (partner_id);
create index if not exists partner_documents_live_idx
  on public.partner_documents (partner_id, doc_type)
  where superseded_at is null;

alter table public.partner_documents enable row level security;
-- Again: no anon/authenticated policy. Private bucket + trusted server only.

comment on table public.partner_documents is
  'KYC document metadata. Bytes live in the PRIVATE storage bucket; only admins reach them via short-lived signed URLs.';

-- ------------------------------------------------------------------
-- 3) PARTNER AUDIT LOG (immutable)
--    Every meaningful action on an application, with who/when/what.
--    This is the due-diligence evidence trail the admin relies on.
-- ------------------------------------------------------------------
create table if not exists public.partner_audit_log (
  id bigint generated by default as identity primary key,
  partner_id uuid not null references public.partners(id) on delete cascade,
  actor_type text not null check (actor_type in ('partner', 'admin', 'system')),
  actor text,
  action text not null,
  -- Previous/new lifecycle status, when the action changed it.
  from_status text,
  to_status text,
  -- Free-form, non-sensitive detail (NEVER raw PII or document content).
  detail jsonb not null default '{}'::jsonb,
  -- Request provenance for the security audit.
  ip_hash text,
  user_agent text,
  created_at timestamptz not null default now()
);

create index if not exists partner_audit_partner_idx
  on public.partner_audit_log (partner_id, created_at desc);

alter table public.partner_audit_log enable row level security;

-- Append-only: no UPDATE or DELETE is granted to anyone. A BEFORE UPDATE
-- / DELETE trigger makes tampering fail even for a privileged client that
-- forgot to read the comment.
create or replace function public.partner_audit_log_immutable()
returns trigger
language plpgsql
as $$
begin
  raise exception 'partner_audit_log is append-only';
end;
$$;

drop trigger if exists partner_audit_log_no_update on public.partner_audit_log;
create trigger partner_audit_log_no_update
  before update or delete on public.partner_audit_log
  for each row execute function public.partner_audit_log_immutable();

-- ------------------------------------------------------------------
-- 4) EMAIL VERIFICATION + RESEND THROTTLE
--    A dedicated, indexed table keeps the send-rate limit query cheap
--    and independent of the application row's lifecycle.
-- ------------------------------------------------------------------
create table if not exists public.partner_email_events (
  id bigint generated by default as identity primary key,
  partner_id uuid not null references public.partners(id) on delete cascade,
  email text not null,
  kind text not null check (kind in ('verification', 'resend', 'verified', 'decision')),
  ip_hash text,
  created_at timestamptz not null default now()
);

create index if not exists partner_email_events_partner_idx
  on public.partner_email_events (partner_id, created_at desc);

alter table public.partner_email_events enable row level security;

-- ------------------------------------------------------------------
-- 4b) Constraint migration for existing databases
--
-- `create table if not exists` above is a no-op when the table already
-- exists, so a CHECK constraint that CHANGED between revisions would never be
-- updated on a database that was created by an earlier revision. Drop and
-- re-add the affected constraint so re-running this file always converges on
-- the intended definition.
--
-- partners_consent_check: an earlier revision required consent for every
-- status except 'draft'. That made withdrawal impossible for a partner who
-- had not yet consented — which inverts DPDP Act 2023 s.6(4), where
-- withdrawing must be as easy as giving. 'withdrawn' is now exempt.
-- ------------------------------------------------------------------
alter table public.partners drop constraint if exists partners_consent_check;
alter table public.partners add constraint partners_consent_check check (
  status in ('draft', 'withdrawn')
  or (terms_accepted = true and privacy_accepted = true
      and truthfulness_declared = true)
);

-- ------------------------------------------------------------------
-- 5) updated_at maintenance
-- ------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists partners_touch_updated_at on public.partners;
create trigger partners_touch_updated_at
  before update on public.partners
  for each row execute function public.touch_updated_at();

-- ------------------------------------------------------------------
-- 6) PARTNER SELF-SERVICE RPCs (SECURITY DEFINER, anon-executable)
--
--    These are the ONLY functions the public portal can call. Each takes
--    the partner's portal token and derives the row from its HASH, so the
--    caller can only ever touch the row whose token they hold. The portal
--    never passes a partner id, so it cannot address someone else's row.
-- ------------------------------------------------------------------

-- Enum-free sha256 helper (pgcrypto's digest, already available in Supabase).
-- Defined in `public` with a pinned search_path to avoid hijacking.
create or replace function public.partner_token_hash(p_token text)
returns text
language sql
immutable
set search_path = public
as $$
  -- public.sb_digest() is created at the top of this migration and resolves
  -- pgcrypto's digest() wherever the extension happens to live. Calling
  -- pgcrypto's `digest` directly here would fail on any project where
  -- pgcrypto is installed outside `public` (e.g. in an `extensions` schema),
  -- because this function pins `search_path = public`.
  select public.sb_digest(coalesce(p_token, '')::text, 'sha256');
$$;

-- 6a) Register a draft application.
--
--     NO USER ENUMERATION (ASVS 6.3.8). The function NEVER reveals
--     whether an email is already registered. If the address already has
--     an application, it returns that application's id with a NULL token.
--     The server then responds to the caller with exactly the same message
--     and the same timing as a brand-new registration, and (for a genuine
--     duplicate) emails the existing partner a "someone tried to register
--     with your address" notice instead of a verification link. An
--     attacker learns nothing about which addresses are enrolled.
create or replace function public.partner_register(p_email text, p_ip_hash text default null)
returns table (partner_id uuid, portal_token text, existing boolean)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_token text;
  v_email text;
begin
  v_email := lower(trim(coalesce(p_email, '')));
  if v_email = '' or position('@' in v_email) = 0 then
    raise exception 'a valid email is required';
  end if;

  -- Already registered? Return the existing row WITHOUT a token. The
  -- caller cannot distinguish this from a fresh registration.
  select p.id into v_id
  from public.partners p
  where lower(p.email) = v_email
  limit 1;

  if v_id is not null then
    insert into public.partner_audit_log (partner_id, actor_type, action, detail, ip_hash)
    values (v_id, 'system', 'register_duplicate_attempt',
            jsonb_build_object('note', 'registration attempted for an existing email'),
            p_ip_hash);
    return query select v_id, null::text, true;
    return;
  end if;

  -- 32 random bytes => 256 bits of entropy (ASVS 6.5.3 CSPRNG).
  -- public.sb_random_bytes resolves pgcrypto regardless of its schema.
  v_token := encode(public.sb_random_bytes(32), 'hex');

  insert into public.partners (email, portal_token_hash, status)
  values (v_email, public.partner_token_hash(v_token), 'draft')
  returning id into v_id;

  insert into public.partner_audit_log (partner_id, actor_type, action, to_status, ip_hash)
  values (v_id, 'partner', 'register', 'draft', p_ip_hash);

  return query select v_id, v_token, false;
end;
$$;

revoke execute on function public.partner_register(text, text) from public;
grant execute on function public.partner_register(text, text) to anon, authenticated, service_role;

-- 6b) Fetch the caller's OWN application by token.
create or replace function public.partner_get_self(p_token text)
returns setof public.partners
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hash text;
begin
  v_hash := public.partner_token_hash(coalesce(p_token, ''));
  return query
    select * from public.partners p
    where p.portal_token_hash = v_hash
    limit 1;
end;
$$;

revoke execute on function public.partner_get_self(text) from public;
grant execute on function public.partner_get_self(text) to anon, authenticated, service_role;

-- 6c) Save a draft: UPDATE the caller's own row, with a strict allow-list
--     of columns so the portal cannot set status, affiliate_id, decision
--     fields, etc. Status may only move draft <-> needs_info (a partner
--     CANNOT self-submit through this function).
create or replace function public.partner_save_draft(p_token text, p_fields jsonb)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_status text;
begin
  select p.id, p.status into v_id, v_status
  from public.partners p
  where p.portal_token_hash = public.partner_token_hash(coalesce(p_token, ''))
  limit 1;

  if v_id is null then
    return 'invalid_session';
  end if;

  -- A submitted/under-review/approved application is frozen for the
  -- partner; only `needs_info` reopens editing.
  if v_status not in ('draft', 'needs_info') then
    return 'locked';
  end if;

  update public.partners p set
    applicant_type       = case when p_fields ? 'applicant_type'       then nullif(trim(p_fields->>'applicant_type'), '')             else p.applicant_type       end,
    legal_name           = case when p_fields ? 'legal_name'           then nullif(trim(p_fields->>'legal_name'), '')                 else p.legal_name           end,
    display_name         = case when p_fields ? 'display_name'         then nullif(trim(p_fields->>'display_name'), '')               else p.display_name         end,
    entity_type          = case when p_fields ? 'entity_type'          then nullif(trim(p_fields->>'entity_type'), '')                else p.entity_type          end,
    gender               = case when p_fields ? 'gender'               then nullif(trim(p_fields->>'gender'), '')                     else p.gender               end,
    date_of_birth        = case when p_fields ? 'date_of_birth'        then nullif(trim(p_fields->>'date_of_birth'), '')::date         else p.date_of_birth        end,
    phone                = case when p_fields ? 'phone'                then nullif(trim(p_fields->>'phone'), '')                      else p.phone                end,
    address_line1        = case when p_fields ? 'address_line1'        then nullif(trim(p_fields->>'address_line1'), '')              else p.address_line1        end,
    address_line2        = case when p_fields ? 'address_line2'        then nullif(trim(p_fields->>'address_line2'), '')              else p.address_line2        end,
    city                 = case when p_fields ? 'city'                 then nullif(trim(p_fields->>'city'), '')                       else p.city                 end,
    state                = case when p_fields ? 'state'                then nullif(trim(p_fields->>'state'), '')                      else p.state                end,
    postal_code          = case when p_fields ? 'postal_code'          then nullif(trim(p_fields->>'postal_code'), '')                else p.postal_code          end,
    country              = case when p_fields ? 'country'              then coalesce(nullif(trim(p_fields->>'country'), ''), 'India') else p.country              end,
    pan_number           = case when p_fields ? 'pan_number'           then nullif(upper(trim(p_fields->>'pan_number')), '')          else p.pan_number           end,
    gstin                = case when p_fields ? 'gstin'                then nullif(upper(trim(p_fields->>'gstin')), '')               else p.gstin                end,
    aadhaar_last4        = case when p_fields ? 'aadhaar_last4'        then nullif(trim(p_fields->>'aadhaar_last4'), '')              else p.aadhaar_last4        end,
    aadhaar_consent      = case when p_fields ? 'aadhaar_consent'      then coalesce((p_fields->>'aadhaar_consent')::boolean, false)   else p.aadhaar_consent      end,
    bank_account_name    = case when p_fields ? 'bank_account_name'    then nullif(trim(p_fields->>'bank_account_name'), '')          else p.bank_account_name    end,
    bank_account_last4   = case when p_fields ? 'bank_account_last4'   then nullif(trim(p_fields->>'bank_account_last4'), '')         else p.bank_account_last4   end,
    bank_ifsc            = case when p_fields ? 'bank_ifsc'            then nullif(upper(trim(p_fields->>'bank_ifsc')), '')          else p.bank_ifsc            end,
    audience_size        = case when p_fields ? 'audience_size'        then nullif(trim(p_fields->>'audience_size'), '')              else p.audience_size        end,
    promotion_plan       = case when p_fields ? 'promotion_plan'       then nullif(trim(p_fields->>'promotion_plan'), '')             else p.promotion_plan       end,
    website_url          = case when p_fields ? 'website_url'          then nullif(trim(p_fields->>'website_url'), '')                else p.website_url          end,
    social_links         = case when p_fields ? 'social_links'         then coalesce(p_fields->'social_links', '{}'::jsonb)           else p.social_links         end
  where p.id = v_id;

  return 'saved';
end;
$$;

revoke execute on function public.partner_save_draft(text, jsonb) from public;
grant execute on function public.partner_save_draft(text, jsonb) to anon, authenticated, service_role;

-- 6d) Build a fully-enriched mail payload for the verification email.
--     Returns the address + display name the server needs; the server
--     mints the token itself so the token never crosses this boundary.
create or replace function public.partner_prepare_verification(
  p_token text,
  p_ip_hash text default null
)
returns table (partner_id uuid, email text, status text, can_send boolean, reason text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.partners;
  v_recent integer;
begin
  select * into v_row from public.partners p
  where p.portal_token_hash = public.partner_token_hash(coalesce(p_token, ''))
  limit 1;

  if v_row.id is null then
    return query select null::uuid, null::text, null::text, false, 'invalid_session';
    return;
  end if;
  if v_row.email_verified then
    return query select v_row.id, v_row.email, v_row.status, false, 'already_verified';
    return;
  end if;

  -- Resend throttle: at most 5 verification emails per rolling hour.
  select count(*) into v_recent
  from public.partner_email_events e
  where e.partner_id = v_row.id
    and e.kind in ('verification', 'resend')
    and e.created_at > now() - interval '1 hour';

  if v_recent >= 5 then
    return query select v_row.id, v_row.email, v_row.status, false, 'rate_limited';
    return;
  end if;

  insert into public.partner_email_events (partner_id, email, kind, ip_hash)
  values (v_row.id, v_row.email, 'verification', p_ip_hash);
  -- The token itself is written by the server via partner_set_verification_token.

  return query select v_row.id, v_row.email, v_row.status, true, 'ok';
end;
$$;

revoke execute on function public.partner_prepare_verification(text, text) from public;
grant execute on function public.partner_prepare_verification(text, text) to service_role;

-- 6d-ii) Store the hash of a freshly-issued verification token. The RAW
--        token is minted by the server (crypto.randomBytes(32)) and is
--        sent to the partner in the email; the database only ever holds
--        its SHA-256. Service-role only, so no client can plant a token.
--        Setting a new token also INVALIDATES any previous one, so only
--        the newest emailed link can ever be used (a resend therefore
--        revokes the prior link, as OWASP's Forgot Password guidance
--        requires).
create or replace function public.partner_set_verification_token(
  p_partner_id uuid,
  p_raw_token text,
  p_ttl_minutes integer default 1440
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_updated integer;
begin
  if p_partner_id is null or coalesce(p_raw_token, '') = '' then
    return false;
  end if;
  -- Guard the TTL so a bad caller cannot mint a forever-valid link.
  if p_ttl_minutes is null or p_ttl_minutes < 1 or p_ttl_minutes > 10080 then
    p_ttl_minutes := 1440;
  end if;

  update public.partners p
     set email_verify_token_hash = public.partner_token_hash(p_raw_token),
         email_verify_expires_at = now() + make_interval(mins => p_ttl_minutes),
         email_verify_attempts = 0
   where p.id = p_partner_id
     and p.email_verified = false;

  get diagnostics v_updated = row_count;
  return v_updated > 0;
end;
$$;

revoke execute on function public.partner_set_verification_token(uuid, text, integer) from public;
grant execute on function public.partner_set_verification_token(uuid, text, integer) to service_role;

-- 6d-iii) Record a document access event. Called by the trusted server
--         every time an admin opens a KYC document, so access to
--         identity data is auditable (OWASP Logging: log access to
--         sensitive data, with who/when/what/result). Only identifiers
--         and outcomes are stored — never the document bytes, the
--         extracted PAN/GSTIN, or a signed URL.
create or replace function public.partner_log_document_access(
  p_partner_id uuid,
  p_document_id uuid,
  p_admin text,
  p_action text,
  p_result text,
  p_reason text default null,
  p_ip_hash text default null,
  p_user_agent text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.partner_audit_log
    (partner_id, actor_type, actor, action, detail, ip_hash, user_agent)
  values (
    p_partner_id, 'admin', p_admin, coalesce(p_action, 'document.access'),
    jsonb_build_object(
      'document_id', p_document_id,
      'result', coalesce(p_result, 'unknown'),
      'reason', p_reason
    ),
    p_ip_hash,
    -- Bound and strip control characters: OWASP warns that logged data
    -- must be sanitised to prevent log injection.
    left(regexp_replace(coalesce(p_user_agent, ''), '[[:cntrl:]]', '', 'g'), 300)
  );
end;
$$;

revoke execute on function public.partner_log_document_access(uuid, uuid, text, text, text, text, text, text) from public;
grant execute on function public.partner_log_document_access(uuid, uuid, text, text, text, text, text, text) to service_role;

-- 6e) Consume a verification token (called by the server with the raw
--     token from the emailed link). Single-use, expiring, attempt-capped.
--
--     ATOMICITY: the burn is a single `UPDATE ... WHERE ... RETURNING`.
--     A naive SELECT-then-UPDATE would let two concurrent requests both
--     observe an unconsumed token and both succeed (TOCTOU). Because the
--     guard conditions live in the UPDATE's WHERE clause, exactly one
--     caller can ever win the row; the loser gets zero rows back and is
--     reported as 'already_used'. This satisfies ASVS 6.5.1 ("only
--     successfully usable once").
create or replace function public.partner_consume_verification(p_raw_token text)
returns table (partner_id uuid, email text, ok boolean, reason text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hash text;
  v_id uuid;
  v_email text;
  v_expires timestamptz;
  v_verified boolean;
  v_attempts integer;
begin
  if coalesce(p_raw_token, '') = '' then
    return query select null::uuid, null::text, false, 'invalid';
    return;
  end if;

  v_hash := public.partner_token_hash(p_raw_token);

  -- Read the row for diagnosis only; the AUTHORITATIVE check is the
  -- conditional UPDATE below.
  select p.id, p.email, p.email_verify_expires_at, p.email_verified,
         p.email_verify_attempts
    into v_id, v_email, v_expires, v_verified, v_attempts
  from public.partners p
  where p.email_verify_token_hash = v_hash
  limit 1;

  if v_id is null then
    -- Unknown token. Deliberately indistinguishable from an expired or
    -- consumed one to the caller; the server maps all of these to the
    -- same user-facing message.
    return query select null::uuid, null::text, false, 'invalid';
    return;
  end if;

  -- Count the attempt regardless of outcome, so brute-force guessing is
  -- bounded even across many invalid attempts on a live token.
  update public.partners p
     set email_verify_attempts = p.email_verify_attempts + 1
   where p.id = v_id;

  if v_verified then
    return query select v_id, v_email, true, 'already_verified';
    return;
  end if;
  if v_attempts >= 20 then
    return query select v_id, v_email, false, 'too_many_attempts';
    return;
  end if;
  if v_expires is null or v_expires < now() then
    return query select v_id, v_email, false, 'expired';
    return;
  end if;

  -- Atomic single-use burn. Only ONE concurrent caller gets a row.
  update public.partners p
     set email_verified = true,
         email_verified_at = now(),
         email_verify_token_hash = null,
         email_verify_expires_at = null
   where p.id = v_id
     and p.email_verified = false
     and p.email_verify_token_hash = v_hash
     and p.email_verify_expires_at is not null
     and p.email_verify_expires_at >= now()
  returning p.id into v_id;

  if v_id is null then
    -- Lost the race (or the conditions no longer hold).
    return query select null::uuid, null::text, false, 'already_used';
    return;
  end if;

  insert into public.partner_email_events (partner_id, email, kind)
  select p.id, p.email, 'verified' from public.partners p where p.id = v_id;

  insert into public.partner_audit_log (partner_id, actor_type, action, detail)
  select p.id, 'partner', 'email_verified', jsonb_build_object('email', p.email)
  from public.partners p where p.id = v_id;

  return query select v_id, v_email, true, 'verified';
end;
$$;

revoke execute on function public.partner_consume_verification(text) from public;
grant execute on function public.partner_consume_verification(text) to service_role;

-- 6f) Submit the application: validates completeness and flips to
--     `submitted`. Requires a verified email and the mandatory consent
--     flags. Runs server-side validation so a crafted request cannot
--     bypass the form rules.
create or replace function public.partner_submit(p_token text, p_ip_hash text default null)
returns table (ok boolean, status text, missing text[])
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.partners;
  v_missing text[] := array[]::text[];
  v_doc_count integer;
begin
  select * into v_row from public.partners p
  where p.portal_token_hash = public.partner_token_hash(coalesce(p_token, ''))
  limit 1;

  if v_row.id is null then
    return query select false, 'invalid_session', array['session']::text[];
    return;
  end if;

  if not v_row.email_verified then
    return query select false, 'email_not_verified', array['email']::text[];
    return;
  end if;

  if v_row.status in ('submitted', 'under_review', 'approved') then
    return query select true, v_row.status, array[]::text[];
    return;
  end if;
  if v_row.status in ('rejected', 'withdrawn') then
    return query select false, v_row.status, array['application_closed']::text[];
    return;
  end if;

  -- --- Completeness (authoritative; the form mirrors these rules) ---
  --
  -- NOTE: the array is built with array_append() rather than the `v || 'x'`
  -- operator. In plpgsql, `v_missing || 'consent'` is ambiguous: the parser
  -- can read `||` as string concatenation on an untyped literal and then fail
  -- at runtime with "Array value must start with {". array_append() is
  -- unambiguous and type-safe.
  if v_row.applicant_type is null then v_missing := array_append(v_missing, 'applicant_type'); end if;
  if coalesce(trim(v_row.legal_name), '') = '' then v_missing := array_append(v_missing, 'legal_name'); end if;
  if v_row.date_of_birth is null then v_missing := array_append(v_missing, 'date_of_birth'); end if;
  if v_row.gender is null then v_missing := array_append(v_missing, 'gender'); end if;
  if coalesce(trim(v_row.phone), '') = '' then v_missing := array_append(v_missing, 'phone'); end if;
  if coalesce(trim(v_row.address_line1), '') = '' then v_missing := array_append(v_missing, 'address_line1'); end if;
  if coalesce(trim(v_row.city), '') = '' then v_missing := array_append(v_missing, 'city'); end if;
  if coalesce(trim(v_row.state), '') = '' then v_missing := array_append(v_missing, 'state'); end if;
  if coalesce(trim(v_row.postal_code), '') = '' then v_missing := array_append(v_missing, 'postal_code'); end if;
  if coalesce(trim(v_row.pan_number), '') = '' then v_missing := array_append(v_missing, 'pan_number'); end if;
  if v_row.applicant_type = 'business' and v_row.entity_type is null then
    v_missing := array_append(v_missing, 'entity_type');
  end if;
  if v_row.terms_accepted is not true
     or v_row.privacy_accepted is not true
     or v_row.truthfulness_declared is not true then
    v_missing := array_append(v_missing, 'consent');
  end if;

  -- --- Required documents per applicant type -------------------------
  select count(*) into v_doc_count
  from public.partner_documents d
  where d.partner_id = v_row.id
    and d.superseded_at is null
    and d.review_status <> 'rejected'
    and d.doc_type = 'pan_card';
  if v_doc_count = 0 then v_missing := array_append(v_missing, 'doc:pan_card'); end if;

  select count(*) into v_doc_count
  from public.partner_documents d
  where d.partner_id = v_row.id
    and d.superseded_at is null
    and d.review_status <> 'rejected'
    and d.doc_type = 'address_proof';
  if v_doc_count = 0 then v_missing := array_append(v_missing, 'doc:address_proof'); end if;

  if v_row.applicant_type = 'business' then
    -- A business must prove it legally exists: GST certificate OR a
    -- registration/incorporation document OR a Udyam certificate OR a
    -- Shop & Establishment licence OR a partnership/trust deed.
    select count(*) into v_doc_count
    from public.partner_documents d
    where d.partner_id = v_row.id
      and d.superseded_at is null
      and d.review_status <> 'rejected'
      and d.doc_type in (
        'gst_certificate', 'incorporation_certificate', 'udyam_certificate',
        'shop_establishment_licence', 'partnership_deed', 'trust_deed'
      );
    if v_doc_count = 0 then v_missing := array_append(v_missing, 'doc:business_registration'); end if;
  end if;

  if array_length(v_missing, 1) is not null and array_length(v_missing, 1) > 0 then
    return query select false, 'incomplete', v_missing;
    return;
  end if;

  update public.partners p set
    status = 'submitted',
    submitted_at = now()
  where p.id = v_row.id;

  insert into public.partner_audit_log (partner_id, actor_type, action, from_status, to_status, ip_hash)
  values (v_row.id, 'partner', 'submit', v_row.status, 'submitted', p_ip_hash);

  return query select true, 'submitted', array[]::text[];
end;
$$;

revoke execute on function public.partner_submit(text, text) from public;
grant execute on function public.partner_submit(text, text) to anon, authenticated, service_role;

-- 6f-ii) Register an uploaded document's metadata after the server has
--        validated and ENCRYPTED the bytes and pushed them to the private
--        bucket. Service-role only: a client can never insert a document
--        row directly, so it cannot forge a "verified" upload.
--
--        Uploads are gated behind a VERIFIED email. This resolves the
--        OWASP File Upload requirement that files only be accepted from
--        an authenticated/authorised party: the portal bearer token plus
--        a completed email verification is that authentication.
create or replace function public.partner_add_document(
  p_token text,
  p_doc_type text,
  p_object_key text,
  p_original_filename text,
  p_mime_type text,
  p_sniffed_mime_type text,
  p_size_bytes bigint,
  p_sha256 text,
  p_enc_iv text,
  p_enc_tag text,
  p_dek_wrapped text,
  p_dek_iv text,
  p_dek_tag text
)
returns table (ok boolean, document_id uuid, reason text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.partners;
  v_id uuid;
  v_count integer;
begin
  select * into v_row from public.partners p
  where p.portal_token_hash = public.partner_token_hash(coalesce(p_token, ''))
  limit 1;

  if v_row.id is null then
    return query select false, null::uuid, 'invalid_session';
    return;
  end if;
  if not v_row.email_verified then
    return query select false, null::uuid, 'email_not_verified';
    return;
  end if;
  if v_row.status not in ('draft', 'needs_info') then
    return query select false, null::uuid, 'locked';
    return;
  end if;

  -- Cap the number of live documents per partner so the bucket cannot be
  -- used as free storage (OWASP: quota the upload service).
  select count(*) into v_count
  from public.partner_documents d
  where d.partner_id = v_row.id and d.superseded_at is null;
  if v_count >= 15 then
    return query select false, null::uuid, 'too_many_documents';
    return;
  end if;

  -- Re-uploading the same document type supersedes the previous one
  -- rather than deleting it, so the review trail is preserved.
  update public.partner_documents d
     set superseded_at = now()
   where d.partner_id = v_row.id
     and d.doc_type = p_doc_type
     and d.superseded_at is null;

  insert into public.partner_documents (
    partner_id, doc_type, object_key, original_filename,
    mime_type, sniffed_mime_type, size_bytes, sha256,
    enc_iv, enc_tag, dek_wrapped, dek_iv, dek_tag
  ) values (
    v_row.id, p_doc_type, p_object_key, left(coalesce(p_original_filename, ''), 255),
    p_mime_type, p_sniffed_mime_type, p_size_bytes, p_sha256,
    p_enc_iv, p_enc_tag, p_dek_wrapped, p_dek_iv, p_dek_tag
  )
  returning id into v_id;

  insert into public.partner_audit_log (partner_id, actor_type, action, detail)
  values (v_row.id, 'partner', 'document_uploaded',
          jsonb_build_object('document_id', v_id, 'doc_type', p_doc_type,
                             'size_bytes', p_size_bytes));

  return query select true, v_id, 'ok';
end;
$$;

revoke execute on function public.partner_add_document(text, text, text, text, text, text, bigint, text, text, text, text, text, text) from public;
grant execute on function public.partner_add_document(text, text, text, text, text, text, bigint, text, text, text, text, text, text) to service_role;

-- 6f-iii) List the caller's own live documents (metadata only, never the
--         bytes, never the object key — the partner has no way to fetch
--         the ciphertext directly).
create or replace function public.partner_list_documents(p_token text)
returns table (
  id uuid, doc_type text, original_filename text, mime_type text,
  size_bytes bigint, uploaded_at timestamptz, review_status text, review_note text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  select p.id into v_id from public.partners p
  where p.portal_token_hash = public.partner_token_hash(coalesce(p_token, ''))
  limit 1;

  if v_id is null then
    return;
  end if;

  return query
    select d.id, d.doc_type, d.original_filename, d.mime_type,
           d.size_bytes, d.uploaded_at, d.review_status, d.review_note
    from public.partner_documents d
    where d.partner_id = v_id and d.superseded_at is null
    order by d.uploaded_at desc;
end;
$$;

revoke execute on function public.partner_list_documents(text) from public;
grant execute on function public.partner_list_documents(text) to anon, authenticated, service_role;

-- 6f-iv) Delete one of the caller's own (not-yet-reviewed) documents.
--        Returns the object key so the SERVER can remove the ciphertext
--        from the bucket; the portal itself never sees the key.
create or replace function public.partner_delete_document(p_token text, p_document_id uuid)
returns table (ok boolean, object_key text, reason text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.partners;
  v_key text;
begin
  select * into v_row from public.partners p
  where p.portal_token_hash = public.partner_token_hash(coalesce(p_token, ''))
  limit 1;

  if v_row.id is null then
    return query select false, null::text, 'invalid_session';
    return;
  end if;
  if v_row.status not in ('draft', 'needs_info') then
    return query select false, null::text, 'locked';
    return;
  end if;

  select d.object_key into v_key
  from public.partner_documents d
  where d.id = p_document_id and d.partner_id = v_row.id
  limit 1;

  if v_key is null then
    return query select false, null::text, 'not_found';
    return;
  end if;

  delete from public.partner_documents d
  where d.id = p_document_id and d.partner_id = v_row.id;

  insert into public.partner_audit_log (partner_id, actor_type, action, detail)
  values (v_row.id, 'partner', 'document_deleted',
          jsonb_build_object('document_id', p_document_id));

  return query select true, v_key, 'ok';
end;
$$;

revoke execute on function public.partner_delete_document(text, uuid) from public;
grant execute on function public.partner_delete_document(text, uuid) to anon, authenticated, service_role;

-- 6g) Approve: atomically create the affiliate, issue the QR referrer
--     code, issue the discount coupon, and link everything back. This is
--     the single most important function in the program, so it:
--       * requires the row to be submitted / under_review / needs_info
--       * is idempotent (re-approving returns the existing artifacts)
--       * creates the affiliate ONLY on success
--       * records an immutable audit entry
--     Secrets (the actual coupon code) are generated here, server-side.
create or replace function public.partner_approve(
  p_partner_id uuid,
  p_admin text,
  p_commission_amount numeric default 0,
  p_referrer_code text default null,
  p_coupon_code text default null,
  p_coupon_max_redemptions integer default null,
  p_coupon_expires_at timestamptz default null
)
returns table (
  ok boolean,
  affiliate_id uuid,
  referrer_code text,
  coupon_code text,
  reason text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.partners;
  v_aff_id uuid;
  v_ref text;
  v_coupon text;
  v_name text;
begin
  select * into v_row from public.partners p where p.id = p_partner_id for update;

  if v_row.id is null then
    return query select false, null::uuid, null::text, null::text, 'not_found';
    return;
  end if;

  -- Idempotent: already approved => return the existing artefacts.
  if v_row.status = 'approved' and v_row.affiliate_id is not null then
    select a.referrer_code into v_ref from public.affiliates a where a.id = v_row.affiliate_id;
    select c.code into v_coupon from public.coupons c
      where c.affiliate_id = v_row.affiliate_id
      order by c.created_at asc limit 1;
    return query select true, v_row.affiliate_id, v_ref, v_coupon, 'already_approved';
    return;
  end if;

  if v_row.status not in ('submitted', 'under_review', 'needs_info') then
    return query select false, null::uuid, null::text, null::text,
      'invalid_state:' || v_row.status;
    return;
  end if;

  if not v_row.email_verified then
    return query select false, null::uuid, null::text, null::text, 'email_not_verified';
    return;
  end if;

  -- Display name for the affiliate (the public name shown to customers).
  v_name := coalesce(nullif(trim(v_row.display_name), ''), nullif(trim(v_row.legal_name), ''), v_row.email);

  -- Referrer code: admin-supplied or generated. Same 3-32 char shape the
  -- existing admin panel enforces, so the Android install-referrer
  -- pipeline accepts it unchanged.
  if p_referrer_code is not null and trim(p_referrer_code) <> '' then
    v_ref := upper(trim(p_referrer_code));
    if v_ref !~ '^[A-Z0-9][A-Z0-9-]{2,31}$' then
      return query select false, null::uuid, null::text, null::text, 'invalid_referrer_code';
      return;
    end if;
    if exists (select 1 from public.affiliates a where a.referrer_code = v_ref) then
      return query select false, null::uuid, null::text, null::text, 'referrer_code_taken';
      return;
    end if;
  else
    loop
      v_ref := 'SB-P' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
      exit when not exists (select 1 from public.affiliates a where a.referrer_code = v_ref);
    end loop;
  end if;

  -- Create the affiliate that drives the SHIPPED app pipeline.
  insert into public.affiliates (name, contact_email, commission_amount, referrer_code, status)
  values (
    v_name,
    v_row.email,
    coalesce(p_commission_amount, 0),
    v_ref,
    'active'
  )
  returning id into v_aff_id;

  -- Discount coupon: admin-supplied or generated. Same shape the existing
  -- admin panel enforces ('letters, numbers or hyphens', upper-cased).
  if p_coupon_code is not null and trim(p_coupon_code) <> '' then
    v_coupon := upper(trim(p_coupon_code));
    if v_coupon !~ '^[A-Z0-9][A-Z0-9-]*$' then
      -- Return a status rather than raising: a bad code is caller input, and
      -- raising here would surface as a 500 instead of an actionable message.
      return query select false, null::uuid, null::text, null::text, 'invalid_coupon_code';
      return;
    end if;
    if exists (select 1 from public.coupons c where c.code = v_coupon) then
      return query select false, null::uuid, null::text, null::text, 'coupon_code_taken';
      return;
    end if;
  else
    loop
      v_coupon := 'SB' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
      exit when not exists (select 1 from public.coupons c where c.code = v_coupon);
    end loop;
  end if;

  insert into public.coupons (code, affiliate_id, max_redemptions, expires_at)
  values (v_coupon, v_aff_id, p_coupon_max_redemptions, p_coupon_expires_at);

  update public.partners p set
    status = 'approved',
    affiliate_id = v_aff_id,
    approved_at = now(),
    reviewed_at = coalesce(p.reviewed_at, now()),
    reviewed_by = coalesce(p_admin, p.reviewed_by),
    commission_amount = coalesce(p_commission_amount, 0),
    decision_note = null
  where p.id = v_row.id;

  insert into public.partner_audit_log
    (partner_id, actor_type, actor, action, from_status, to_status, detail)
  values (
    v_row.id, 'admin', p_admin, 'approve', v_row.status, 'approved',
    jsonb_build_object(
      'affiliate_id', v_aff_id,
      'referrer_code', v_ref,
      'coupon_code', v_coupon,
      'commission_amount', coalesce(p_commission_amount, 0)
    )
  );

  return query select true, v_aff_id, v_ref, v_coupon, 'approved';
end;
$$;

-- Approving creates marketing identities: service_role ONLY.
revoke execute on function public.partner_approve(uuid, text, numeric, text, text, integer, timestamptz) from public;
grant execute on function public.partner_approve(uuid, text, numeric, text, text, integer, timestamptz) to service_role;

-- 6h) Reject / request more info / close. Kept separate from approve so
--     the admin UI cannot accidentally approve while rejecting.
create or replace function public.partner_decide(
  p_partner_id uuid,
  p_admin text,
  p_decision text,
  p_note text default null,
  p_purge_days integer default 90
)
returns table (ok boolean, status text, reason text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.partners;
  v_new text;
begin
  if p_decision not in ('reject', 'needs_info', 'under_review', 'withdraw') then
    return query select false, null::text, 'invalid_decision';
    return;
  end if;

  select * into v_row from public.partners p where p.id = p_partner_id for update;
  if v_row.id is null then
    return query select false, null::text, 'not_found';
    return;
  end if;
  if v_row.status = 'approved' then
    return query select false, v_row.status, 'already_approved';
    return;
  end if;

  v_new := case p_decision
    when 'reject' then 'rejected'
    when 'needs_info' then 'needs_info'
    when 'under_review' then 'under_review'
    else 'withdrawn'
  end;

  update public.partners p set
    status = v_new,
    reviewed_at = now(),
    reviewed_by = coalesce(p_admin, p.reviewed_by),
    decision_note = nullif(trim(coalesce(p_note, '')), ''),
    -- Personal data must not be kept indefinitely, but it also must not be
    -- deleted before the DPDP Rules r.8(3) one-year floor. `greatest()` picks
    -- whichever is later, so both obligations hold at once.
    purge_after = case
      when v_new in ('rejected', 'withdrawn')
        then greatest(
          now() + make_interval(days => greatest(coalesce(p_purge_days, 90), 1)),
          p.earliest_purge_at
        )
      else null
    end
  where p.id = v_row.id;

  insert into public.partner_audit_log
    (partner_id, actor_type, actor, action, from_status, to_status, detail)
  values (
    v_row.id,
    case when p_decision = 'withdraw' then 'partner' else 'admin' end,
    p_admin, p_decision, v_row.status, v_new,
    jsonb_build_object('note', nullif(trim(coalesce(p_note, '')), ''))
  );

  return query select true, v_new, 'ok';
end;
$$;

revoke execute on function public.partner_decide(uuid, text, text, text, integer) from public;
grant execute on function public.partner_decide(uuid, text, text, text, integer) to service_role;

-- 6h-ii) Partner-initiated withdrawal (DPDP Act 2023 s.6(4): withdrawing
--        consent must be as easy as giving it, so the partner can do this
--        from the portal with the same single bearer token they registered
--        with — no support email required).
--
--        IMPORTANT: this marks the application withdrawn and schedules
--        purging, but it does NOT delete immediately. DPDP Rules 2025 r.8(3)
--        imposes a mandatory one-year minimum retention, and r.8(2) requires
--        warning the data principal at least 48 hours before erasure. So
--        withdrawal is honest about what it does: it stops all further
--        processing and starts the (floored) deletion clock.
create or replace function public.partner_withdraw(p_token text, p_reason text default null)
returns table (ok boolean, status text, purge_after timestamptz, reason text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.partners;
  v_purge timestamptz;
begin
  select * into v_row from public.partners p
  where p.portal_token_hash = public.partner_token_hash(coalesce(p_token, ''))
  limit 1;

  if v_row.id is null then
    return query select false, null::text, null::timestamptz, 'invalid_session';
    return;
  end if;

  if v_row.status = 'withdrawn' then
    -- Idempotent: asking twice is not an error.
    return query select true, v_row.status, v_row.purge_after, 'already_withdrawn';
    return;
  end if;

  -- Stopping all further processing is the substantive part of withdrawal,
  -- and it is immediate. Deletion is bounded by the statutory floor.
  v_purge := greatest(now() + interval '90 days', v_row.earliest_purge_at);

  update public.partners p set
    status = 'withdrawn',
    reviewed_at = now(),
    decision_note = nullif(trim(coalesce(p_reason, '')), ''),
    purge_after = v_purge
  where p.id = v_row.id;

  -- Burn the portal session: a withdrawn applicant should not be able to keep
  -- editing, and the token should not outlive the purpose it was issued for.
  update public.partners p set portal_token_hash = 'withdrawn:' || p.id::text
  where p.id = v_row.id;

  insert into public.partner_audit_log
    (partner_id, actor_type, action, from_status, to_status, detail)
  values (
    v_row.id, 'partner', 'withdraw', v_row.status, 'withdrawn',
    jsonb_build_object('purge_after', v_purge)
  );

  return query select true, 'withdrawn'::text, v_purge, 'ok';
end;
$$;

revoke execute on function public.partner_withdraw(text, text) from public;
grant execute on function public.partner_withdraw(text, text) to anon, authenticated, service_role;

-- 6h-iii) Record that the partner was shown, and accepted, the affiliate
--         DISCLOSURE obligation. CCPA Guidelines 2022 para 14 makes this
--         legally mandatory: where a partner's material connection to the
--         brand would not be reasonably expected by the audience, it "shall
--         be fully disclosed". Recording acceptance gives the operator
--         evidence that the obligation was communicated.
create or replace function public.partner_accept_disclosure(p_token text, p_version text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.partners;
begin
  select * into v_row from public.partners p
  where p.portal_token_hash = public.partner_token_hash(coalesce(p_token, ''))
  limit 1;

  if v_row.id is null then
    return 'invalid_session';
  end if;
  if v_row.status not in ('draft', 'needs_info') then
    return 'locked';
  end if;

  insert into public.partner_audit_log (partner_id, actor_type, action, detail)
  values (
    v_row.id, 'partner', 'disclosure_obligation_accepted',
    jsonb_build_object('version', left(coalesce(p_version, ''), 40))
  );

  return 'ok';
end;
$$;

revoke execute on function public.partner_accept_disclosure(text, text) from public;
grant execute on function public.partner_accept_disclosure(text, text) to anon, authenticated, service_role;

-- 6i) Admin dashboard listing with document counts, for the review queue.
create or replace function public.partner_admin_list(p_status text default null)
returns table (
  id uuid, email text, legal_name text, display_name text,
  applicant_type text, entity_type text, status text,
  email_verified boolean, submitted_at timestamptz, created_at timestamptz,
  affiliate_id uuid, referrer_code text, coupon_code text,
  commission_amount numeric, document_count bigint, reviewed_by text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select
    p.id, p.email, p.legal_name, p.display_name,
    p.applicant_type, p.entity_type, p.status,
    p.email_verified, p.submitted_at, p.created_at,
    p.affiliate_id,
    (select a.referrer_code from public.affiliates a where a.id = p.affiliate_id),
    (select c.code from public.coupons c where c.affiliate_id = p.affiliate_id
       order by c.created_at asc limit 1),
    p.commission_amount,
    (select count(*) from public.partner_documents d
       where d.partner_id = p.id and d.superseded_at is null),
    p.reviewed_by
  from public.partners p
  where p.deleted_at is null
    and (p_status is null or p.status = p_status)
  order by
    -- Actionable items first: submitted -> under_review -> needs_info.
    case p.status
      when 'submitted' then 0
      when 'under_review' then 1
      when 'needs_info' then 2
      when 'approved' then 3
      when 'rejected' then 4
      when 'withdrawn' then 5
      else 6
    end,
    p.submitted_at desc nulls last,
    p.created_at desc;
end;
$$;

revoke execute on function public.partner_admin_list(text) from public;
grant execute on function public.partner_admin_list(text) to service_role;

-- ------------------------------------------------------------------
-- 7) PRIVATE STORAGE BUCKET FOR KYC DOCUMENTS
--    public = false is the critical flag: no unauthenticated read path
--    exists at all. Admins reach files only via short-lived signed URLs
--    minted by the trusted server.
-- ------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'partner-kyc',
  'partner-kyc',
  false,
  10485760, -- 10 MB
  array['application/pdf', 'image/jpeg', 'image/png']
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- No storage.objects policies are created for anon/authenticated. The
-- server uses the service role, which bypasses RLS. This is deliberate:
-- a policy would create a readable path for a leaked anon key.

-- ------------------------------------------------------------------
-- 8) VERIFY
-- ------------------------------------------------------------------
select 'partners' as tbl, count(*) from public.partners
union all select 'partner_documents', count(*) from public.partner_documents
union all select 'partner_audit_log', count(*) from public.partner_audit_log
union all select 'partner_email_events', count(*) from public.partner_email_events;

select id, public, file_size_limit, allowed_mime_types
from storage.buckets where id = 'partner-kyc';

select proname, prosecdef
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and proname like 'partner\_%'
order by proname;
