#!/usr/bin/env bash
# Verifies: the skill rejects generic placeholder content for required
# fields, not just fields that are fully absent (test-5 covers absent;
# this covers "technically provided but not real").
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../test-helpers.sh"

echo "=== Test: rejects generic placeholder content for required fields ==="

new_scratch_repo
FAILURES=0

run_claude "Log a backlog todo. Title: Improve error messages. Type: enhancement. Priority: P2. Description: N/A. Acceptance criteria: N/A." >/dev/null

assert_no_file "backlog/*.md" "no file written with N/A placeholder description/acceptance criteria" || FAILURES=$((FAILURES + 1))

if [[ "$FAILURES" -gt 0 ]]; then
  echo "=== FAILED ($FAILURES) ==="
  exit 1
fi
echo "=== PASS ==="
