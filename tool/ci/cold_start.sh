#!/bin/sh
# Cold start time reporter for CI (emulator/device already booted, app installed).
# Usage: tool/ci/cold_start.sh [runs]   (default 5)
# Force-stops the app before every run, starts MainActivity with `am start -W`
# and prints each TotalTime plus the median (ms), also appended to
# $GITHUB_STEP_SUMMARY when set. Exit 1 when no run reported a time.
set -u

PKG=com.tududi.tududi
runs=${1:-5}
summary=${GITHUB_STEP_SUMMARY:-/dev/null}
times=""

i=1
while [ "$i" -le "$runs" ]; do
  adb shell am force-stop "$PKG"
  sleep 2
  out=$(adb shell am start -W -n "$PKG/.MainActivity" | tr -d '\r')
  t=$(printf '%s\n' "$out" | sed -n 's/^TotalTime: *//p' | head -n1)
  if printf '%s\n' "$out" | grep -q '^Status: ok' && [ -n "$t" ]; then
    echo "run $i: TotalTime ${t} ms"
    times="$times $t"
  else
    echo "::warning::run $i did not report a TotalTime"
    printf '%s\n' "$out"
  fi
  i=$((i + 1))
done
adb shell am force-stop "$PKG"

[ -n "$times" ] || { echo "::error::no cold start measured"; exit 1; }

sorted=$(printf '%s\n' $times | sort -n)
count=$(printf '%s\n' $sorted | wc -l | tr -d ' ')
median=$(printf '%s\n' $sorted | sed -n "$(( (count + 1) / 2 ))p")
min=$(printf '%s\n' $sorted | head -n1)
max=$(printf '%s\n' $sorted | tail -n1)

echo "Cold start TotalTime: median ${median} ms (min ${min}, max ${max}, ${count} runs)"
{
  echo "### Cold start"
  echo "- TotalTime median: **${median} ms** (min ${min}, max ${max}, ${count} runs)"
} >>"$summary"
