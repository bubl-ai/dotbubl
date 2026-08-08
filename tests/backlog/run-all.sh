#!/usr/bin/env bash
# Runs every backlog skill smoke test and reports a summary.
# Usage: tests/backlog/run-all.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0
FAIL=0

for t in "$DIR"/test-*.sh; do
  name="$(basename "$t")"
  echo "=== $name ==="
  if OUT=$(bash "$t" 2>&1); then
    echo "$OUT" | tail -1
    PASS=$((PASS + 1))
  else
    echo "$OUT"
    FAIL=$((FAIL + 1))
  fi
  echo
done

echo "----------------------------------------"
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
