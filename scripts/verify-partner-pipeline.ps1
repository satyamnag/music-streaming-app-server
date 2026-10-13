# ============================================================================
# FULL PIPELINE VERIFICATION (PowerShell)
# ============================================================================
# Brings up a throwaway PostgreSQL instance, applies the real migrations, and
# runs every test layer against it:
#
#   1. migration chain applies cleanly and is idempotent
#   2. database behaviour tests (real SQL functions, constraints, grants)
#   3. crypto + file-validation unit tests
#   4. HTML structural verification
#   5. HTTP integration against the STUB (fast, isolates route logic)
#   6. HTTP end-to-end against REAL PostgreSQL (the strongest layer)
#
# Usage:  pwsh -File scripts/verify-partner-pipeline.ps1
#
# The instance is disposable: it lives under _pgtest/ locally and is never
# used by production. Requires PostgreSQL binaries (found automatically).
# ============================================================================

$ErrorActionPreference = 'Stop'

# Native tools write progress and warnings to stderr (initdb warns about local
# "trust" auth, psql notices are informational). With ErrorActionPreference set
# to Stop, PowerShell 5.1 promotes those to terminating errors. Redirect them
# instead of letting them abort the run.
$PSNativeCommandUseErrorActionPreference = $false

# --- locate PostgreSQL ------------------------------------------------------
function Find-PgBin {
  $candidates = @()
  $scoopRoot = Join-Path $env:USERPROFILE 'scoop\apps\postgresql'
  if (Test-Path $scoopRoot) {
    Get-ChildItem $scoopRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
      $candidates += (Join-Path $_.FullName 'bin')
    }
  }
  $candidates += (Get-ChildItem 'C:\Program Files\PostgreSQL' -Directory -ErrorAction SilentlyContinue |
    ForEach-Object { Join-Path $_.FullName 'bin' })
  foreach ($c in $candidates) {
    if (Test-Path (Join-Path $c 'initdb.exe')) { return $c }
  }
  return $null
}

$PG_BIN = Find-PgBin
if (-not $PG_BIN) {
  Write-Host 'PostgreSQL binaries not found. Install PostgreSQL, or set PG_BIN.' -ForegroundColor Red
  exit 1
}
Write-Host "PostgreSQL binaries: $PG_BIN" -ForegroundColor Cyan

$PORT     = 55432
$DBNAME   = 'sb_partner_verify'
$PGDATA   = Join-Path $PSScriptRoot '..\_pgtest\data'
$PGLOG    = Join-Path $PSScriptRoot '..\_pgtest\log\verify.log'
$SERVER   = Join-Path $PSScriptRoot '..\server'
$MIG      = Join-Path $SERVER 'migrations'
$PSQL     = Join-Path $PG_BIN 'psql.exe'
$INITDB   = Join-Path $PG_BIN 'initdb.exe'
$PGCTL    = Join-Path $PG_BIN 'pg_ctl.exe'
$PGREADY  = Join-Path $PG_BIN 'pg_isready.exe'
$env:PGPASSWORD = 'testpw'

$results = @()

function Step($name, $block, $expectMarker) {
  Write-Host ''
  Write-Host "=== $name ===" -ForegroundColor Yellow
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    # Native tools write to stderr routinely (psql NOTICE, node warnings), so
    # failure is decided by the EXIT CODE plus, optionally, the presence of an
    # explicit success marker. Inferring failure from loose text matching is
    # unreliable — "PASS re-submitting is not an error" and "FAIL 0" are both
    # legitimate output.
    $out = @(& $block 2>&1)
    $code = $LASTEXITCODE

    if ($expectMarker) {
      if (-not ($out | Select-String -SimpleMatch $expectMarker)) {
        throw "expected marker not found: '$expectMarker'"
      }
    }
    if ($null -ne $code -and $code -ne 0) { throw "exit code $code" }

    $script:results += [pscustomobject]@{ Step = $name; Result = 'PASS' }
    Write-Host "  -> PASS" -ForegroundColor Green
  } catch {
    $script:results += [pscustomobject]@{ Step = $name; Result = "FAIL: $_" }
    Write-Host "  -> FAIL: $_" -ForegroundColor Red
  } finally {
    $ErrorActionPreference = $prev
  }
}

# --- 1. bring up a disposable cluster ---------------------------------------
if (-not (Test-Path (Join-Path $PGDATA 'PG_VERSION'))) {
  New-Item -ItemType Directory -Force -Path $PGDATA, (Split-Path $PGLOG) | Out-Null
  $pwfile = Join-Path $env:TEMP 'pgpw_verify.txt'
  Set-Content -Path $pwfile -Value 'testpw' -NoNewline
  # initdb writes an informational warning to stderr; capture it rather than
  # letting it surface as a PowerShell error record.
  $initOut = & $INITDB -D $PGDATA -U postgres --pwfile=$pwfile -E UTF8 --locale=C 2>&1
  $initCode = $LASTEXITCODE
  Remove-Item $pwfile -Force -ErrorAction SilentlyContinue
  if ($initCode -ne 0) {
    Write-Host ($initOut | Out-String) -ForegroundColor Red
    throw "initdb failed with exit code $initCode"
  }
  Write-Host 'Initialized a disposable PostgreSQL cluster.' -ForegroundColor Cyan
}

# Start the server detached so it survives this script.
$running = $false
try {
  $ready = & $PGREADY -h 127.0.0.1 -p $PORT 2>&1
  $running = $LASTEXITCODE -eq 0
} catch { $running = $false }

if (-not $running) {
  Write-Host 'Starting PostgreSQL...' -ForegroundColor Cyan
  # Start-Process keeps the server independent of this shell.
  Start-Process -FilePath (Join-Path $PG_BIN 'postgres.exe') `
    -ArgumentList @('-D', $PGDATA, '-p', $PORT) `
    -RedirectStandardOutput $PGLOG -RedirectStandardError "$PGLOG.err" `
    -WindowStyle Hidden
  for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Milliseconds 750
    & $PGREADY -h 127.0.0.1 -p $PORT *> $null
    if ($LASTEXITCODE -eq 0) { $running = $true; break }
  }
}
if (-not $running) { Write-Host 'PostgreSQL failed to start. See ' $PGLOG -ForegroundColor Red; exit 1 }
Write-Host 'PostgreSQL is accepting connections.' -ForegroundColor Green

# --- 2. build the database ---------------------------------------------------
Step 'Build database from migrations (fresh)' {
  & $PSQL -h 127.0.0.1 -p $PORT -U postgres -q -c "DROP DATABASE IF EXISTS $DBNAME;" *> $null
  & $PSQL -h 127.0.0.1 -p $PORT -U postgres -q -c "CREATE DATABASE $DBNAME;" *> $null

  # DELIBERATELY DO NOT pre-install pgcrypto.
  #
  # An earlier version of this script ran `CREATE EXTENSION pgcrypto` before
  # applying the migrations, which HID a real deployment bug: migration 033
  # used pgcrypto's `digest()` while assuming migration 003 had installed the
  # extension. On the real Supabase project, 003 evidently had not — so the
  # migration failed with "function digest(text, unknown) does not exist".
  #
  # Leaving the database bare makes this step prove that the migration chain
  # installs its own dependency, rather than relying on a hand-prepared fixture.

  $files = @(
    'test\supabase-shim.sql',
    'migrations\003_referrals.sql', 'migrations\004_coupons.sql',
    'migrations\005_vault.sql',
    'migrations\007_affiliate_yearly_flat100.sql',
    'migrations\008_affiliate_configurable_amount.sql',
    'migrations\009_affiliate_referrer_qr.sql',
    'migrations\033_partner_program.sql'
  )
  foreach ($f in $files) {
    $out = & $PSQL -h 127.0.0.1 -p $PORT -U postgres -d $DBNAME -q -v ON_ERROR_STOP=1 -f (Join-Path $SERVER $f) 2>&1
    if ($out | Select-String 'ERROR') { throw "$f failed: $($out | Select-String 'ERROR' | Select-Object -First 1)" }
  }

  # Assert the exact thing that broke in production is now working.
  $probe = & $PSQL -h 127.0.0.1 -p $PORT -U postgres -d $DBNAME -t -A -c `
    "select public.partner_token_hash('probe') = encode(digest('probe','sha256'),'hex');" 2>&1
  if (($probe | Out-String).Trim() -ne 't') { throw "pgcrypto/digest unusable after migrations: $probe" }

  # Storage emulation + vault seed (test fixtures only).
  $seed = @"
create table if not exists public.test_only_storage_objects (
  id uuid primary key default gen_random_uuid(), bucket_id text not null, name text not null,
  data bytea not null, content_type text, created_at timestamptz not null default now(),
  unique (bucket_id, name));
truncate table vault.secrets;
insert into vault.secrets (name, secret) values ('admin_token','real-db-admin-token');
"@
  $seed | & $PSQL -h 127.0.0.1 -p $PORT -U postgres -d $DBNAME -q 2>&1 | Out-Null
}

Step 'Migration installs its own extension on a BARE database' {
  # Regression guard for the production failure. This database has NOTHING
  # pre-installed: no pgcrypto, no extensions at all. Only the migration
  # chain may bring it up.
  $bare = "${DBNAME}_bare"
  & $PSQL -h 127.0.0.1 -p $PORT -U postgres -q -c "DROP DATABASE IF EXISTS $bare;" *> $null
  & $PSQL -h 127.0.0.1 -p $PORT -U postgres -q -c "CREATE DATABASE $bare;" *> $null

  foreach ($f in @('test\supabase-shim.sql', 'migrations\004_coupons.sql', 'migrations\033_partner_program.sql')) {
    $out = & $PSQL -h 127.0.0.1 -p $PORT -U postgres -d $bare -q -v ON_ERROR_STOP=1 -f (Join-Path $SERVER $f) 2>&1
    if ($out | Select-String 'ERROR') { throw "$f failed on a bare database: $($out | Select-String 'ERROR' | Select-Object -First 1)" }
  }
  $probe = & $PSQL -h 127.0.0.1 -p $PORT -U postgres -d $bare -t -A -c `
    "select public.partner_token_hash('probe') = encode(digest('probe','sha256'),'hex');" 2>&1
  if (($probe | Out-String).Trim() -ne 't') { throw "digest unavailable on the bare database: $probe" }
  & $PSQL -h 127.0.0.1 -p $PORT -U postgres -q -c "DROP DATABASE IF EXISTS $bare;" *> $null
}

Step 'Works when pgcrypto lives in a NON-public schema (production layout)' {
  # This is the exact production failure. Supabase commonly installs
  # extensions into an `extensions` schema. The partner functions pin
  # `set search_path = public`, so an unqualified digest() call fails with
  # "function digest(text, text) does not exist" even though pgcrypto is
  # installed and working.
  $ext = "${DBNAME}_ext"
  & $PSQL -h 127.0.0.1 -p $PORT -U postgres -q -c "DROP DATABASE IF EXISTS $ext;" *> $null
  & $PSQL -h 127.0.0.1 -p $PORT -U postgres -q -c "CREATE DATABASE $ext;" *> $null
  & $PSQL -h 127.0.0.1 -p $PORT -U postgres -d $ext -q -c 'create schema extensions; create extension pgcrypto with schema extensions;' *> $null

  foreach ($f in @('test\supabase-shim.sql', 'migrations\004_coupons.sql', 'migrations\033_partner_program.sql')) {
    $out = & $PSQL -h 127.0.0.1 -p $PORT -U postgres -d $ext -q -v ON_ERROR_STOP=1 -f (Join-Path $SERVER $f) 2>&1
    if ($out | Select-String 'ERROR') { throw "$f failed with pgcrypto in 'extensions': $($out | Select-String 'ERROR' | Select-Object -First 1)" }
  }
  $probe = & $PSQL -h 127.0.0.1 -p $PORT -U postgres -d $ext -t -A -c `
    "select public.partner_token_hash('probe') = encode(extensions.digest('probe','sha256'),'hex');" 2>&1
  if (($probe | Out-String).Trim() -ne 't') { throw "sb_digest wrong with pgcrypto in 'extensions': $probe" }
  & $PSQL -h 127.0.0.1 -p $PORT -U postgres -q -c "DROP DATABASE IF EXISTS $ext;" *> $null
}

Step 'Repairs missing earlier migrations and runs the full lifecycle' {
  # Simulates a project where 003/008/009 never ran: pgcrypto sits in
  # `extensions`, and `affiliates` lacks referrer_code and commission_amount.
  # Migration 033 must repair those prerequisites itself, then drive a
  # complete partner lifecycle including the SHIPPED app's RPCs.
  $fix = "${DBNAME}_repair"
  & $PSQL -h 127.0.0.1 -p $PORT -U postgres -q -c "DROP DATABASE IF EXISTS $fix;" *> $null
  & $PSQL -h 127.0.0.1 -p $PORT -U postgres -q -c "CREATE DATABASE $fix;" *> $null
  & $PSQL -h 127.0.0.1 -p $PORT -U postgres -d $fix -q -c 'create schema extensions; create extension pgcrypto with schema extensions;' *> $null

  foreach ($f in @('test\supabase-shim.sql', 'migrations\004_coupons.sql', 'migrations\033_partner_program.sql')) {
    $out = & $PSQL -h 127.0.0.1 -p $PORT -U postgres -d $fix -q -v ON_ERROR_STOP=1 -f (Join-Path $SERVER $f) 2>&1
    if ($out | Select-String 'ERROR') { throw "$f failed during repair: $($out | Select-String 'ERROR' | Select-Object -First 1)" }
  }

  # Assert the repairs actually happened.
  foreach ($col in @('referrer_code', 'commission_amount')) {
    $present = & $PSQL -h 127.0.0.1 -p $PORT -U postgres -d $fix -t -A -c `
      "select count(*) from information_schema.columns where table_name='affiliates' and column_name='$col';" 2>&1
    if (($present | Out-String).Trim() -ne '1') { throw "repair failed: affiliates.$col still missing" }
  }

  # Full lifecycle, including bind_affiliate_referral / validate_coupon /
  # redeem_coupon — the RPCs the shipped Android app calls.
  $out = & $PSQL -h 127.0.0.1 -p $PORT -U postgres -d $fix -q -v ON_ERROR_STOP=1 `
    -f (Join-Path $SERVER 'test\partner_lifecycle_on_repaired_db.sql') 2>&1
  if ($out | Select-String 'ERROR') { throw "lifecycle failed: $($out | Select-String 'ERROR' | Select-Object -First 1)" }
  if (-not ($out | Select-String 'LIFECYCLE COMPLETE AND CORRECT')) { throw 'lifecycle did not report success' }
  & $PSQL -h 127.0.0.1 -p $PORT -U postgres -q -c "DROP DATABASE IF EXISTS $fix;" *> $null
}

Step 'Migration 033 is idempotent (re-run)' {
  $out = & $PSQL -h 127.0.0.1 -p $PORT -U postgres -d $DBNAME -q -v ON_ERROR_STOP=1 `
    -f (Join-Path $MIG '033_partner_program.sql') 2>&1
  if ($out | Select-String 'ERROR') { throw ($out | Select-String 'ERROR' | Select-Object -First 1) }
}

# --- 3. test layers ----------------------------------------------------------
# Each step asserts an explicit SUCCESS MARKER in its output in addition to a
# zero exit code, so a suite that silently does nothing cannot pass.

Step 'Database behaviour tests (real SQL)' {
  $out = & $PSQL -h 127.0.0.1 -p $PORT -U postgres -d $DBNAME -q -v ON_ERROR_STOP=1 `
    -f (Join-Path $SERVER 'test\partner_db.test.sql') 2>&1
  Write-Host "    $(($out | Select-String 'PASS ').Count) assertions passed"
  $out | Select-String 'ALL DATABASE TESTS PASSED'
} 'ALL DATABASE TESTS PASSED'

Step 'Crypto + file-validation unit tests' {
  & node (Join-Path $SERVER 'test\partner_crypto.test.mjs') 2>&1
} '0 failed'

Step 'HTML structural verification' {
  & node (Join-Path $SERVER 'test\partner-verify.cjs') 2>&1 | Select-String 'ALL CHECKS PASSED|CHECK\(S\)'
} 'ALL CHECKS PASSED'

Step 'HTTP integration against the stub' {
  & node (Join-Path $SERVER 'test\partner-stub-register.mjs') (Join-Path $SERVER 'test\partner-flow.test.mjs') 2>&1
} '0 failed'

Step 'HTTP end-to-end against REAL PostgreSQL' {
  $env:PARTNER_TEST_DB_URL = "postgres://postgres:testpw@127.0.0.1:$PORT/$DBNAME"
  & node (Join-Path $SERVER 'test\real-db-register.mjs') (Join-Path $SERVER 'test\partner-real-db.test.mjs') 2>&1
} '0 failed'

Step 'Pre-existing admin tests (no regression)' {
  & node (Join-Path $SERVER 'test\admin-filters.test.cjs') 2>&1
} 'FAIL 0'

# --- summary -----------------------------------------------------------------
Write-Host ''
Write-Host '================ SUMMARY ================' -ForegroundColor Cyan
$results | ForEach-Object {
  $color = if ($_.Result -eq 'PASS') { 'Green' } else { 'Red' }
  Write-Host ("  {0,-52} {1}" -f $_.Step, $_.Result) -ForegroundColor $color
}
$failed = ($results | Where-Object { $_.Result -ne 'PASS' }).Count
Write-Host ''
if ($failed -eq 0) {
  Write-Host 'ALL PIPELINE STEPS PASSED' -ForegroundColor Green
  exit 0
} else {
  Write-Host "$failed STEP(S) FAILED" -ForegroundColor Red
  exit 1
}
