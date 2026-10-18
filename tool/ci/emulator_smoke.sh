#!/bin/sh
# Runs inside android-emulator-runner (emulator already booted).
# Usage: tool/ci/emulator_smoke.sh <debug-apk>
# Also runs integration_test/widget_bridge_test.dart and :app:connectedDebugAndroidTest.
set -u

PKG=com.tududi.tududi
apk=${1:?apk path required}
summary=${GITHUB_STEP_SUMMARY:-/dev/null}
fail=0

adb install -r -t "$apk" || { echo "::error::adb install failed"; exit 1; }
adb logcat -c

out=$(adb shell am start -W -n "$PKG/.MainActivity" | tr -d '\r')
echo "$out"
printf '%s\n' "$out" | grep -q '^Status: ok' || { echo "::error::am start did not report Status: ok"; fail=1; }
total=$(printf '%s\n' "$out" | sed -n 's/^TotalTime: *//p' | head -n1)
{
  echo "### Emulator smoke test"
  echo ""
  echo "- Cold start TotalTime: ${total:-unknown} ms"
} >> "$summary"

sleep 10
pid=$(adb shell pidof "$PKG" | tr -d '\r')
if [ -z "$pid" ]; then
  echo "::error::$PKG is not running 10 s after start"
  fail=1
else
  echo "app pid after 10 s: $pid"
  echo "- Process alive after 10 s: yes (pid $pid)" >> "$summary"
fi

adb logcat -d -v threadtime > logcat.txt
if grep -A4 'FATAL EXCEPTION' logcat.txt | grep -q "Process: $PKG"; then
  echo "::error::FATAL EXCEPTION for $PKG in logcat"
  grep -A12 'FATAL EXCEPTION' logcat.txt | head -n 40
  echo "- FATAL EXCEPTION: yes" >> "$summary"
  fail=1
else
  echo "- FATAL EXCEPTION: none" >> "$summary"
fi

echo "--- appwidget (informational) ---"
adb shell dumpsys appwidget | grep -i "$PKG" || echo "no appwidget entries for $PKG (none placed on the home screen)"

flutter test integration_test/widget_bridge_test.dart || fail=1

(cd android && ./gradlew :app:connectedDebugAndroidTest) || fail=1

exit "$fail"
