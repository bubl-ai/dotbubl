#!/usr/bin/env bash
# Verifies: the guideline-check agent can run git diff via Bash to inspect
# changes, which is its core designed capability. The agent receives a base
# ref (not a precomputed diff) and uses Bash to run its own git diff/git log.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../test-helpers.sh"

echo "=== Test: guideline-check diffs against base ref ==="

new_scratch_repo
echo "line one" > README.md
git add README.md
git commit -q -m "initial commit"

echo "line two" >> README.md
git add README.md
git commit -q -m "second commit"

output=$(run_claude_json "Use the Agent tool with subagent_type \"guideline-check\" and tell it: run 'git diff HEAD~1' via Bash to see what changed in the most recent commit, then report what you find via ReportFindings." 120)

FAILURES=0
assert_subagent_dispatched "$output" "dotbubl:guideline-check" "dispatched the guideline-check subagent" || FAILURES=$((FAILURES + 1))
assert_subagent_used_tool "$output" "dotbubl:guideline-check" "ReportFindings" "concluded via ReportFindings" || FAILURES=$((FAILURES + 1))
assert_contains "$output" "line two" "found the actual diff content (line two added)" || FAILURES=$((FAILURES + 1))

if [[ "$FAILURES" -gt 0 ]]; then
  echo "=== FAILED ($FAILURES) ==="
  exit 1
fi
echo "=== PASS ==="
