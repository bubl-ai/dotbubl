#!/usr/bin/env bash
# Verifies: the skill asks for missing required fields (priority,
# description, acceptance criteria) instead of writing an incomplete item.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../test-helpers.sh"

echo "=== Test: asks for missing required fields instead of writing incomplete item ==="

new_scratch_repo
FAILURES=0

run_claude "Log a backlog todo. Title: Improve error messages. Type: enhancement." >/dev/null

assert_no_file "backlog/*.md" "no file written with priority/description/acceptance criteria missing" || FAILURES=$((FAILURES + 1))

if [[ "$FAILURES" -gt 0 ]]; then
  echo "=== FAILED ($FAILURES) ==="
  exit 1
fi
echo "=== PASS ==="
