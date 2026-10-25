#!/usr/bin/env bash
# Proves the artwork cache survives an app restart, on a real Android runtime.
#
# WHY IT LOOKS LIKE THIS
# ----------------------
# The cache lives in the app's private cache directory, which is unreadable
# without root or a debuggable build, and Android's own gauges are unusable for
# this question: `dumpsys diskstats`' per-package cache figure is stale (measured
# on a device - it did not move after `pm trim-caches`), `cmd storagestats` does
# not exist on Android 11, and `du` on /data/data/<pkg> is denied to the shell
# user. So the app reports its own numbers, and this script compares two
# launches of the same screen:
#
#   cold  - a fresh install, nothing on disk: every artwork file is a download;
#   warm  - the same screen again, after force-stopping the process, so only the
#           DISK cache can serve it (an in-memory image cache cannot survive).
#
# `written_since_launch` is the number that matters: files whose mtime is newer
# than the process start are files that launch downloaded. A warm launch that
# still writes most of what the cold launch wrote is the reported defect - the
# artwork reloads on every launch - and this script fails the run for it.
#
# WHY IT POLLS INSTEAD OF SLEEPING
# --------------------------------
# The first version slept 45 s and then read logcat, which measured nothing: on an
# emulator this debug build needs ~60 s to get through startup (Dart VM, the local
# playback server, the plugin scripts) before the home screen fetches anything, so
# no cold report had been written yet and the cache looked empty. The app now
# reports at 30 s and at 90 s, and this waits for the LATER line, up to 200 s.

set -uo pipefail

APK="build/app/outputs/flutter-apk/app-stable-debug.apk"
PKG=com.soulfulbhakti.app
SETTLED_LABEL='after-home-load-90s'
MAX_WAIT_SECONDS=200

if [ ! -f "$APK" ]; then
  echo "::error::$APK not found - the debug build step did not produce it."
  exit 1
fi

adb wait-for-device
adb install -r "$APK"

# Waits for the settled diagnostic line. Returns 1 if it never appears, so the
# caller can still capture whatever the app managed to log.
wait_for_settled_diagnostic() {
  local waited=0
  while [ "$waited" -lt "$MAX_WAIT_SECONDS" ]; do
    adb logcat -d 2>/dev/null | grep -F "$SETTLED_LABEL" | tail -n 1 > imgdiag-settled.tmp
    if [ -s imgdiag-settled.tmp ]; then
      return 0
    fi
    sleep 10
    waited=$(( waited + 10 ))
  done
  return 1
}

launch_and_measure() {
  local label="$1"
  adb shell am force-stop "$PKG"
  sleep 2
  adb logcat -c
  adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1

  if wait_for_settled_diagnostic; then
    mv imgdiag-settled.tmp "imgdiag-$label.txt"
  else
    echo "::warning::The settled diagnostic ($SETTLED_LABEL) did not appear within ${MAX_WAIT_SECONDS}s on the $label launch."
    adb logcat -d 2>/dev/null | grep -F '[IMGDIAG]' | tail -n 1 > "imgdiag-$label.txt" || true
  fi

  adb logcat -d > "logcat-$label.txt" 2>&1
  adb shell am force-stop "$PKG"
  echo "--- $label ---"
  cat "imgdiag-$label.txt" 2>/dev/null || true
}

launch_and_measure cold
launch_and_measure warm

read_number() {
  sed -n "s/.*$2=\\([0-9]*\\).*/\\1/p" "$1" 2>/dev/null | head -n 1
}

cold_written=$(read_number imgdiag-cold.txt written_since_launch)
warm_written=$(read_number imgdiag-warm.txt written_since_launch)
cache_files=$(read_number imgdiag-warm.txt files)
cache_bytes=$(read_number imgdiag-warm.txt bytes)

echo
echo "cold launch wrote : ${cold_written:-?} cache files"
echo "warm launch wrote : ${warm_written:-?} cache files"
echo "cache now holds   : ${cache_files:-?} files / ${cache_bytes:-?} bytes"

if [ -z "${cold_written:-}" ] || [ -z "${warm_written:-}" ]; then
  echo "::error::The app reported no cache diagnostic. Either the build was not compiled with --dart-define=IMAGE_CACHE_DIAGNOSTICS=true, or startup never got far enough within ${MAX_WAIT_SECONDS}s."
  exit 1
fi

if [ "${cache_files:-0}" -lt 1 ]; then
  echo "::error::A full launch left nothing in the artwork cache: images are not being cached at all (check that the build has real backend credentials, so the home screen actually has artwork to fetch)."
  exit 1
fi

# The cold launch must have actually filled something, otherwise there is
# nothing to reuse and the comparison below would pass vacuously.
if [ "$cold_written" -lt 3 ]; then
  echo "::error::The cold launch only wrote $cold_written cache files, which is too few to prove reuse. The home screen artwork was probably empty - check the build's backend credentials."
  exit 1
fi

if [ "$warm_written" -ge $(( cold_written * 6 / 10 )) ]; then
  echo "::error::The second launch re-downloaded $warm_written of the $cold_written artwork files the first launch fetched. The disk cache is not surviving a restart."
  exit 1
fi

echo
echo "OK: the warm launch reused the disk cache ($warm_written new files against $cold_written on the cold launch, $cache_files files held in total)."
