#!/usr/bin/env bash
# Verifies: explicit-ask creation confirms before writing (turn 1), then
# writes a fully-populated item only after explicit go-ahead (turn 2).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../test-helpers.sh"

echo "=== Test: explicit-ask creation gates on confirmation ==="

new_scratch_repo
FAILURES=0

run_claude "Log a backlog todo. Title: Add dark mode toggle. Type: feature. Priority: P1. Tags: tui. Description: Users want a dark mode toggle in settings. Acceptance criteria: Toggle persists across sessions." >/dev/null

assert_no_file "backlog/*.md" "no file written before explicit go-ahead" || FAILURES=$((FAILURES + 1))

run_claude "Yes, that's right, add it." 60 --continue >/dev/null

assert_file_exists "backlog/0001-*.md" "file written after explicit go-ahead" || FAILURES=$((FAILURES + 1))

FILE=$(compgen -G "backlog/0001-*.md" | head -n1 || true)
if [[ -n "$FILE" ]]; then
  assert_frontmatter "$FILE" '^id: 1$' "id is 1" || FAILURES=$((FAILURES + 1))
  assert_frontmatter "$FILE" '^title: Add dark mode toggle$' "title correct" || FAILURES=$((FAILURES + 1))
  assert_frontmatter "$FILE" '^type: feature$' "type correct" || FAILURES=$((FAILURES + 1))
  assert_frontmatter "$FILE" '^priority: P1$' "priority correct" || FAILURES=$((FAILURES + 1))
  assert_frontmatter "$FILE" 'tui' "tags correct" || FAILURES=$((FAILURES + 1))
  assert_frontmatter "$FILE" '## Description' "has Description section" || FAILURES=$((FAILURES + 1))
  assert_frontmatter "$FILE" '## Acceptance Criteria' "has Acceptance Criteria section" || FAILURES=$((FAILURES + 1))
fi

if [[ "$FAILURES" -gt 0 ]]; then
  echo "=== FAILED ($FAILURES) ==="
  exit 1
fi
echo "=== PASS ==="
