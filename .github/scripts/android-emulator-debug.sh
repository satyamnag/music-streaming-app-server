#!/usr/bin/env bash
# Runs the Soulful Bhakti debug session on the CI Android emulator and
# captures the complete logcat debugging surface (see the workflow that calls
# this file). Runs with bash so multi-line logic and env vars behave.
#
# argv[1]: exercise_ui   "true" to drive a short swipe/tap pass through the app
# argv[2]: log_filter    verbose|debug|info|warning|error|assert
set -euo pipefail

APK=build/app/outputs/flutter-apk/app-stable-debug.apk
PKG=com.soulfulbhakti.app
ACT=com.sangeet.app/.MainActivity
EXERCISE="${1:-true}"
LVL="${2:-warning}"

adb wait-for-device
# google_apis image: root lets us read /data/anr (best-effort).
adb root || true
adb wait-for-device
adb shell input keyevent 82 || true # dismiss keyguard

echo "::group::Install and launch"
adb install -t -r "$APK"
adb logcat -c
adb shell am start -W -n "$ACT" || true
APP_PID=""
for i in $(seq 1 45); do
  APP_PID=$(adb shell pidof "$PKG" 2>/dev/null | tr -d '\r' || true)
  [ -n "$APP_PID" ] && break
  sleep 2
done
echo "APP_PID=${APP_PID:-NOT RUNNING}"
# Let the splash gate + first data load settle.
sleep 10
echo "::endgroup::"

if [ "$EXERCISE" = "true" ]; then
  echo "::group::UI exercise (swipe + navigation, all best-effort)"
  adb shell input swipe 540 1600 540 600 400 || true
  sleep 2
  adb shell input tap 945 2280 || true # bottom-nav "Stats" tile
  sleep 3
  adb shell input tap 1000 180 || true # top-right avatar -> profile popup
  sleep 3
  adb shell input keyevent 4 || true # back
  sleep 2
  adb shell input keyevent 4 || true # back again
  sleep 2
  echo "::endgroup::"
fi

echo "::group::Capture debugging logs"
adb logcat -d -v threadtime > full_logcat.txt || true
adb logcat -d -v threadtime --pid="${APP_PID}" > app_logcat.txt 2>/dev/null || true
adb logcat -d -b crash -v threadtime > crash_logcat.txt || true
adb logcat -d -b events -v threadtime > events_logcat.txt || true
case "$LVL" in
  verbose) LP=V ;;
  debug) LP=D ;;
  info) LP=I ;;
  warning) LP=W ;;
  error) LP=E ;;
  assert) LP=A ;;
  *) LP=W ;;
esac
adb logcat -d -v threadtime "*:$LP" > filtered_logcat.txt || true
adb shell dumpsys activity processes > dumpsys_processes.txt || true
adb shell dumpsys meminfo "$PKG" > meminfo.txt || true
adb shell dumpsys package "$PKG" > package_info.txt || true
adb shell "cat /data/anr/traces.txt 2>/dev/null" > anr_traces.txt || true
echo "::endgroup::"

echo "::group::Debug summary"
echo "full log lines : $(wc -l < full_logcat.txt 2>/dev/null || echo 0)"
echo "app log lines  : $(wc -l < app_logcat.txt 2>/dev/null || echo 0)"
echo "crash log lines: $(wc -l < crash_logcat.txt 2>/dev/null || echo 0)"
grep -E "FATAL EXCEPTION|AndroidRuntime|ANR in |am_crash|am_anr|am_kill|Process: com\.soulfulbhakti|E flutter" \
  full_logcat.txt crash_logcat.txt events_logcat.txt 2>/dev/null \
  | head -200 > findings.txt || true
echo "--- top findings ---"
head -60 findings.txt 2>/dev/null || true
echo "--- app-pid log (tail) ---"
tail -40 app_logcat.txt 2>/dev/null || true
echo "::endgroup::"