# Creates the build junction the APK build needs.
#
# WHY: the repository path contains an ampersand
# ("D:\Soulful Bhakti\Soulful Bhakti Android App & Admin"). cmd.exe treats "&" as
# a command separator, so it cannot cd into that path no matter how the path is
# quoted — `cd /d "... App & Admin"` is split at the "&" and the working
# directory ends up as "...\Soulful Bhakti Android App". Gradle is then invoked
# outside android\ and fails with "Could not find or load main class
# org.gradle.wrapper.GradleWrapperMain".
#
# build-apk.bat therefore builds through this junction, whose path contains
# neither a space nor an ampersand. The script creates the junction itself if it
# is missing, so running this by hand is optional.
#
# Idempotent: safe to run repeatedly.

$ErrorActionPreference = 'Stop'

$junction = 'D:\sb-app'
$target = Join-Path $PSScriptRoot '..'

if (-not (Test-Path (Join-Path $target 'pubspec.yaml'))) {
    throw "The repository root was not found at '$target' (no pubspec.yaml)."
}

if (Test-Path $junction) {
    Write-Host "Removing the existing junction $junction"
    Remove-Item $junction -Force -Recurse
}

New-Item -ItemType Junction -Path $junction -Target $target | Out-Null

if (-not (Test-Path (Join-Path $junction 'pubspec.yaml'))) {
    throw "The junction was created but '$junction\pubspec.yaml' is not readable."
}

Write-Host "Junction ready: $junction -> $target"
