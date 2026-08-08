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
run_claude "While reviewing this code you noticed the create_user function doesn't validate the email field format or check for empty password values before hashing. That's worth fixing but out of scope for this PR — propose deferring it as a follow-up: type chore, priority P2, tag validation. I approve deferring it." >/dev/null

assert_no_file "backlog/*.md" "no file written before explicit go-ahead" || FAILURES=$((FAILURES + 1))

run_claude "Yes, go ahead and add it." 60 --continue >/dev/null

assert_file_exists "backlog/0001-*.md" "file written after explicit go-ahead" || FAILURES=$((FAILURES + 1))

FILE=$(compgen -G "backlog/0001-*.md" | head -n1 || true)
if [[ -n "$FILE" ]]; then
  assert_frontmatter "$FILE" '^type: chore$' "type correct" || FAILURES=$((FAILURES + 1))
  assert_frontmatter "$FILE" '^priority: P2$' "priority correct" || FAILURES=$((FAILURES + 1))
  assert_frontmatter "$FILE" 'validation' "tags correct" || FAILURES=$((FAILURES + 1))
fi

if [[ "$FAILURES" -gt 0 ]]; then
  echo "=== FAILED ($FAILURES) ==="
  exit 1
fi
echo "=== PASS ==="
