#!/usr/bin/env bash
# Verifies: a task identified and deferred mid-session is NOT written until
# a separate, explicit confirmation — the two-gate design's core property.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../test-helpers.sh"

echo "=== Test: deferred-task creation gates on confirmation ==="

new_scratch_repo
FAILURES=0

# Concrete detail matters here: the skill correctly refuses to fabricate
# specifics for code that doesn't exist in an empty scratch repo, so a vague
# "this could be split out" prompt won't produce a draft to confirm at all.
turn1_output=$(run_claude "While reviewing this code you noticed the create_user function doesn't validate the email field format or check for empty password values before hashing. That's worth fixing but out of scope for this PR — propose deferring it as a follow-up: type chore, priority P2, tag validation. I approve deferring it.")

assert_no_file "backlog/*.md" "no file written before explicit go-ahead" || FAILURES=$((FAILURES + 1))
# "No file written" alone doesn't prove the confirmation gate actually ran —
# a confused/silent turn 1 would pass that check too. Confirm the required
# confirmation line was actually shown. (Title is model-drafted here, unlike
# test-2, so assert on the stable fields instead of exact title text.)
assert_contains "$turn1_output" "chore" "turn 1 confirmation shows type" || FAILURES=$((FAILURES + 1))
assert_contains "$turn1_output" "P2" "turn 1 confirmation shows priority" || FAILURES=$((FAILURES + 1))
assert_contains "$turn1_output" "sound right" "turn 1 shows the confirmation question" || FAILURES=$((FAILURES + 1))

run_claude "Yes, go ahead and add it." 60 --continue >/dev/null

assert_file_exists "backlog/0001-*.md" "file written after explicit go-ahead" || FAILURES=$((FAILURES + 1))

FILE=$(compgen -G "backlog/0001-*.md" | head -n1 || true)
if [[ -n "$FILE" ]]; then
  assert_frontmatter "$FILE" '^type: chore$' "type correct" || FAILURES=$((FAILURES + 1))
  assert_frontmatter "$FILE" '^priority: P2$' "priority correct" || FAILURES=$((FAILURES + 1))
  assert_frontmatter "$FILE" '^tags:.*\bvalidation\b' "tags correct" || FAILURES=$((FAILURES + 1))
  assert_frontmatter "$FILE" '## Context' "has Context section" || FAILURES=$((FAILURES + 1))
fi

if [[ "$FAILURES" -gt 0 ]]; then
  echo "=== FAILED ($FAILURES) ==="
  exit 1
fi
echo "=== PASS ==="
