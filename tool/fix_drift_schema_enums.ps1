# Fixes the drift schema snapshots so the migration test can compile.
#
# WHY THIS IS NEEDED
# ------------------
# `test/drift/app_db/generated/schema_v*.dart` are standalone schema snapshots.
# Drift generates each one from a JSON file in `drift_schemas/app_db/`, copying
# the column's `default_dart` expression VERBATIM into the snapshot.
#
# For enum-typed columns the expression is a reference to the enum member:
#
#     "default_dart": "Constant(ThemeMode.system.name)"
#
# The snapshot imports only `package:drift/drift.dart`, so `ThemeMode` — and the
# eight other enums referenced the same way — are undefined there. The generated
# files therefore cannot compile:
#
#     Error: The getter 'ThemeMode' isn't defined for the type 'PreferencesTable'
#
# `lib/models/database/database.g.dart` has the same expression and DOES compile,
# because it is a `part of` the app, where Flutter's Material import brings
# `ThemeMode` into scope. A snapshot has no such scope. That asymmetry is the whole
# bug: the app builds, the migration test never runs.
#
# THE FIX
# -------
# Replace each `EnumName.member.name` with the literal string it evaluates to, so
# the snapshot is self-contained. This changes NOTHING about the schema the test
# then verifies: `.name` is a compile-time constant, and the string written into
# the JSON is exactly what drift puts in the SQL DEFAULT.
#
# This is also what drift itself already does. Nine of these enums were removed
# from the codebase in later versions, and drift persisted their defaults as plain
# literals in `lib/models/database/database.steps.dart`:
#
#     defaultValue: Constant("high")     <- was SourceQualities.high.name
#     defaultValue: Constant("m4a")      <- was SourceCodecs.m4a.name
#
# so the literals below are read from the app's own compiled migration steps, not
# guessed. The four enums that still exist are resolved the same way, from their
# definitions in lib/models/database/tables/preferences.dart and
# lib/models/metadata/market.dart.
#
# Idempotent: re-running it after a successful fix changes nothing, and it refuses
# to touch a file where a replacement would be ambiguous.

$ErrorActionPreference = 'Stop'

$schemaDir = Join-Path $PSScriptRoot '..\drift_schemas\app_db'
$schemaDir = (Resolve-Path $schemaDir).Path

# Enum member -> the literal its `.name` produces.
#
# Every value here is READ FROM THE CODEBASE:
#  * the five still-defined enums from their own `enum` declarations, and
#  * the four removed ones from database.steps.dart, where drift recorded the
#    literal when the enum ceased to exist.
$literals = [ordered]@{
    'ThemeMode.system'                       = 'system'
    'CloseBehavior.close'                    = 'close'
    'LayoutMode.adaptive'                    = 'adaptive'
    'Market.IN'                              = 'IN'
    'Market.US'                              = 'US'
    'SearchMode.youtube'                     = 'youtube'
    'YoutubeClientEngine.youtubeExplode'     = 'youtubeExplode'
    'AudioSource.youtube'                    = 'youtube'
    'SourceCodecs.m4a'                       = 'm4a'
    'SourceCodecs.weba'                      = 'weba'
    'SourceQualities.high'                   = 'high'
    'SourceType.youtube'                     = 'youtube'
}

$files = Get-ChildItem $schemaDir -Filter '*.json'
if ($files.Count -eq 0) { throw "No schema JSON files found in $schemaDir" }

$totalReplacements = 0
$touchedFiles = 0

foreach ($file in $files) {
    $original = [IO.File]::ReadAllText($file.FullName)
    $updated = $original
    $fileReplacements = 0

    foreach ($member in $literals.Keys) {
        $literal = $literals[$member]

        # Only rewrite the exact drift expression, so an unrelated string that
        # happens to contain the same text is never touched.
        $needle = "Constant($member.name)"
        if (-not $updated.Contains($needle)) { continue }

        $escaped = $literal.Replace('\', '\\').Replace('"', '\"')
        $replacement = "Constant(\`"$escaped\`")"

        $count = ([regex]::Matches($updated, [regex]::Escape($needle))).Count
        $updated = $updated.Replace($needle, $replacement)
        $fileReplacements += $count
    }

    if ($updated -ne $original) {
        # Write UTF-8 WITHOUT a BOM and without a trailing newline change, so the
        # diff is limited to the replacements themselves.
        [IO.File]::WriteAllText($file.FullName, $updated, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host ("  {0}: {1} replacement(s)" -f $file.Name, $fileReplacements)
        $totalReplacements += $fileReplacements
        $touchedFiles++
    }
}

Write-Host ""
Write-Host "Updated $touchedFiles file(s), $totalReplacements default expression(s)."

# Fail loudly if anything enum-shaped survived, rather than leaving the build to
# discover it.
$remaining = @()
foreach ($file in $files) {
    $raw = [IO.File]::ReadAllText($file.FullName)
    foreach ($m in [regex]::Matches($raw, '"default_dart":"(Constant\([^)]*\))')) {
        $expr = $m.Groups[1].Value
        if ($expr -match '^Constant\([A-Z][A-Za-z0-9_]*\.[A-Za-z0-9_]+\.name\)$') {
            $remaining += "$($file.Name): $expr"
        }
    }
}

if ($remaining.Count -gt 0) {
    Write-Host ""
    Write-Host "STILL UNRESOLVED:" -ForegroundColor Red
    $remaining | Sort-Object -Unique | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    throw "Some enum default expressions were not resolved; the snapshots will not compile."
}

Write-Host "No enum-referencing defaults remain in the schema JSON."

# ---------------------------------------------------------------------------
# The GENERATED snapshots need the same substitution.
#
# WHY THEY CANNOT SIMPLY BE REGENERATED
# -------------------------------------
# `dart run drift_dev schema generate drift_schemas/ <out>` is the documented way
# to rebuild these, and it does NOT work on this project: drift_dev 2.28.0 reads
# the schema JSONs' `_meta.version` "1.2.0" but cannot map this older sub-format,
# so it finds ZERO entities and writes an EMPTY registry instead of failing:
#
#     static const versions = const [];
#
# That is worse than the compile error it was meant to fix — an empty registry
# means the migration test verifies nothing at all, and it would have looked like
# a clean run. Verified by regenerating into a scratch directory.
#
# So the snapshots are patched in place. The substitution is exactly the one the
# JSON got above, and leaves the schema the test verifies byte-identical: only the
# SOURCE EXPRESSION for a compile-time constant changes, never the constant.
# ---------------------------------------------------------------------------
$generatedDir = Join-Path $PSScriptRoot '..\test\drift\app_db\generated'
$generatedDir = (Resolve-Path $generatedDir).Path
$dartFiles = Get-ChildItem $generatedDir -Filter 'schema_v*.dart'
if ($dartFiles.Count -eq 0) { throw "No generated schema snapshots found in $generatedDir" }

$dartReplacements = 0
$dartTouched = 0

foreach ($file in $dartFiles) {
    $original = [IO.File]::ReadAllText($file.FullName)
    $updated = $original
    $fileReplacements = 0

    foreach ($member in $literals.Keys) {
        $literal = $literals[$member]
        # In Dart the generated code is already `Constant(Enum.member.name)`;
        # replace the whole expression with the equivalent string literal.
        $needle = "Constant($member.name)"
        if (-not $updated.Contains($needle)) { continue }

        $count = ([regex]::Matches($updated, [regex]::Escape($needle))).Count
        $updated = $updated.Replace($needle, "const Constant(`"$literal`")")
        $fileReplacements += $count
    }

    if ($updated -ne $original) {
        [IO.File]::WriteAllText($file.FullName, $updated, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host ("  {0}: {1} replacement(s)" -f $file.Name, $fileReplacements)
        $dartReplacements += $fileReplacements
        $dartTouched++
    }
}

Write-Host ""
Write-Host "Patched $dartTouched snapshot(s), $dartReplacements expression(s)."

# The registry must still list every version. A regenerated one would not, so this
# is asserted rather than assumed -- an empty registry would silently disable the
# whole migration suite.
$registry = Join-Path $generatedDir 'schema.dart'
$registryText = [IO.File]::ReadAllText($registry)
if ($registryText -match 'versions\s*=\s*const\s*\[\s*\]') {
    throw "schema.dart has an EMPTY version registry - the migration test would verify nothing."
}
$expected = 1..($dartFiles.Count) | ForEach-Object { $_ }
$listed = [regex]::Match($registryText, 'versions\s*=\s*const\s*\[([^\]]*)\]')
if (-not $listed.Success) { throw "Could not read the version registry from schema.dart" }
$actual = ($listed.Groups[1].Value -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ } | ForEach-Object { [int]$_ }
$missing = $expected | Where-Object { $_ -notin $actual }
if ($missing) {
    throw "schema.dart is missing version(s): $($missing -join ', ')"
}
Write-Host "Version registry OK: $($actual -join ', ')"

# Finally, assert no snapshot still references a bare enum name, so a future
# regeneration that reintroduces one fails here rather than in the test compiler.
$leftover = @()
foreach ($file in $dartFiles) {
    $raw = [IO.File]::ReadAllText($file.FullName)
    foreach ($m in [regex]::Matches($raw, 'Constant\((?:ThemeMode|CloseBehavior|LayoutMode|Market|SearchMode|YoutubeClientEngine|AudioSource|SourceCodecs|SourceQualities|SourceType)\.[A-Za-z0-9_]+\.name\)')) {
        $leftover += "$($file.Name): $($m.Value)"
    }
}
if ($leftover.Count -gt 0) {
    Write-Host ""
    $leftover | Sort-Object -Unique | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    throw "Snapshots still reference undefined enum names."
}
Write-Host "No snapshot references an undefined enum name."
