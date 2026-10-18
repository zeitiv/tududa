#!/bin/sh
# Print the CHANGELOG.md section for a release tag.
#
# Usage: tool/ci/release_notes.sh <tag> [changelog-file]
#   <tag>   e.g. v1.2.3 (a leading "v" is stripped) or "Unreleased"
#   Matches headings like "## [1.2.3] - 2026-01-31" or "## 1.2.3".
# Exit codes: 0 section printed, 1 usage error / file missing, 3 section missing or empty.
set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: $0 <tag> [changelog-file]" >&2
  exit 1
fi

tag=$1
file=${2:-CHANGELOG.md}
ver=${tag#v}

if [ ! -f "$file" ]; then
  echo "release_notes: $file not found" >&2
  exit 1
fi

notes=$(awk -v ver="$ver" '
  /^## / {
    if (found) exit
    h = $0
    sub(/^## +\[?/, "", h)
    sub(/\].*$/, "", h)
    sub(/ .*$/, "", h)
    if (tolower(h) == tolower(ver)) { found = 1; next }
  }
  found && /^\[[^]]+\]: / { next }   # link reference definitions at the end of the file
  found { print }
' "$file")

# Trim leading and trailing blank lines.
notes=$(printf '%s\n' "$notes" | awk '
  NF { started = 1 }
  started { l[++n] = $0 }
  END { while (n > 0 && l[n] ~ /^[ \t]*$/) n--; for (i = 1; i <= n; i++) print l[i] }
')

if [ -z "$notes" ]; then
  echo "release_notes: no section for $ver in $file" >&2
  exit 3
fi

printf '%s\n' "$notes"
