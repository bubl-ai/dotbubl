#!/usr/bin/env bash
# Verifies: dispatching the guideline-check agent with a trivial,
# verifiable inspection task produces a concrete, findings-shaped result
# relayed back to the user — not silence, not a vague non-answer.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../test-helpers.sh"

echo "=== Test: guideline-check reports findings ==="

new_scratch_repo
echo "hello" > README.md
git add README.md
git commit -q -m "init"

output=$(run_claude_json "Use the Agent tool with subagent_type \"guideline-check\" to check whether this repository's root directory contains a file named LICENSE, and report what it finds." 120)

FAILURES=0
assert_subagent_dispatched "$output" "dotbubl:guideline-check" "dispatched the guideline-check subagent" || FAILURES=$((FAILURES + 1))
assert_subagent_used_tool "$output" "dotbubl:guideline-check" "ReportFindings" "concluded via ReportFindings" || FAILURES=$((FAILURES + 1))
assert_no_file "LICENSE" "did not create the file it was only asked to check for" || FAILURES=$((FAILURES + 1))

if [[ "$FAILURES" -gt 0 ]]; then
  echo "=== FAILED ($FAILURES) ==="
  exit 1
fi
echo "=== PASS ==="
