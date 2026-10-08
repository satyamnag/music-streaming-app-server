@echo off
rem Release APK build (dev flavor) with the MSVC (C++) environment for the
rem Rust/Cargokit host scripts.
rem
rem WHY THIS SCRIPT LOOKS LIKE THIS
rem --------------------------------
rem The original version simply ran `flutter build apk` and relied on whatever
rem working directory the caller happened to be in. That cannot work from this
rem repository, because its path contains BOTH spaces and an ampersand:
rem
rem     D:\Soulful Bhakti\Soulful Bhakti Android App & Admin
rem
rem cmd.exe treats "&" as a command separator. So `cd /d "D:\... App & Admin"`
rem is split at the ampersand into the command `cd /d "D:\... App ` followed by
rem a separate command `Admin"`, and the working directory silently ends up as
rem "...\Soulful Bhakti Android App" instead of the repository. Gradle then runs
rem outside android\ and the build dies with:
rem
rem     'Admin\android\' is not recognized as an internal or external command
rem     Error: Could not find or load main class
rem            org.gradle.wrapper.GradleWrapperMain
rem
rem Quoting every path fixes the spaces but NOT the ampersand, because the split
rem happens before quoting is considered. The fix is to never let cmd see the
rem ampersand in a command position: the repository is reached through a
rem junction whose path has neither a space nor an ampersand, created by
rem scripts\setup-build-junction.ps1 (idempotent, safe to re-run).
rem
rem If the junction is missing this script creates it, so a fresh clone works.
setlocal EnableExtensions

set "JUNCTION=D:\sb-app"

rem This script lives in <repo>\scripts\, so the repository root is its parent.
rem `%~dp0` already ends in a backslash, so appending `..` would give
rem "<repo>\scripts\..", which is correct but leaves a literal ".." in the path
rem handed to the junction target. Resolving it with `for %%I` gives a clean
rem absolute path instead.
for %%I in ("%~dp0..") do set "REPO=%%~fI"

if not exist "%REPO%\pubspec.yaml" (
  echo FAILED: no pubspec.yaml at "%REPO%" - is this script inside the repo?
  exit /b 1
)

if not exist "%JUNCTION%\pubspec.yaml" (
  echo Creating the build junction %JUNCTION% ...
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$j='%JUNCTION%'; $t='%REPO%'; if (Test-Path $j) { Remove-Item $j -Force -Recurse }; New-Item -ItemType Junction -Path $j -Target $t | Out-Null" || (
    echo FAILED: could not create the junction %JUNCTION% -^> "%REPO%"
    exit /b 1
  )
)

call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat" -arch=amd64 -host_arch=amd64 >nul
set "PATH=%USERPROFILE%\.cargo\bin;%PATH%"

cd /d %JUNCTION%
if errorlevel 1 (
  echo FAILED: could not cd into %JUNCTION%
  exit /b 1
)

echo Building from %CD%
call "C:\Users\SATYAM NAG\fvm\versions\3.35.2\bin\flutter.bat" build apk --release --flavor dev
exit /b %ERRORLEVEL%
