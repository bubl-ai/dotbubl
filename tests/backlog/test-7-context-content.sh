#!/usr/bin/env bash
# Verifies: a deferred-task item drafted from a real discussion captures that
# discussion's specifics in a dedicated ## Context section - not just a
# restatement of the description - so a fresh session reading the file later
# has the reasoning (what was considered, what was rejected, and why), not
# just the ask.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../test-helpers.sh"

echo "=== Test: Context section captures discussion specifics, not boilerplate ==="

new_scratch_repo
FAILURES=0

turn1_output=$(run_claude "We just spent a while discussing how to store user session tokens. We considered storing them in a local SQLite file, but rejected that because it would require a migration step for every consumer of this library and we want zero setup. We're going with signed in-memory tokens instead. While doing this we noticed the existing RefreshToken class doesn't rotate secrets on logout - worth fixing but out of scope for this PR. Propose deferring it as a follow-up: type bug, priority P1, tag auth. I approve deferring it.")

assert_no_file "backlog/*.md" "no file written before explicit go-ahead" || FAILURES=$((FAILURES + 1))

run_claude "Yes, go ahead and add it." 60 --continue >/dev/null

assert_file_exists "backlog/0001-*.md" "file written after explicit go-ahead" || FAILURES=$((FAILURES + 1))

FILE=$(compgen -G "backlog/0001-*.md" | head -n1 || true)
if [[ -n "$FILE" ]]; then
  FILE_CONTENT=$(cat "$FILE")
  assert_frontmatter "$FILE" '## Context' "has a Context section" || FAILURES=$((FAILURES + 1))
  assert_contains "$FILE_CONTENT" "sqlite" "Context captures the rejected alternative from the discussion, not just the ask" || FAILURES=$((FAILURES + 1))
fi

if [[ "$FAILURES" -gt 0 ]]; then
  echo "=== FAILED ($FAILURES) ==="
  exit 1
fi
echo "=== PASS ==="
