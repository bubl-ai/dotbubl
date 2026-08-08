#!/usr/bin/env bash
# Verifies: explicit-ask creation confirms before writing (turn 1), then
# writes a fully-populated item only after explicit go-ahead (turn 2).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

claude_backlog -p "Log a backlog todo. Title: Add dark mode toggle. Type: feature. Priority: P1. Tags: tui. Description: Users want a dark mode toggle in settings. Acceptance criteria: Toggle persists across sessions."

find backlog -maxdepth 1 -name '*.md' 2>/dev/null | grep -q . \
  && fail "a file was written before explicit go-ahead"

claude_backlog --continue -p "Yes, that's right, add it."

FILE=$(find backlog -maxdepth 1 -name '0001-*.md' | head -n1)
[[ -n "$FILE" ]] || fail "no backlog/0001-*.md file was created after go-ahead"

for pattern in '^id: 1$' '^title: Add dark mode toggle$' '^type: feature$' '^priority: P1$' 'tui'; do
  grep -qE "$pattern" "$FILE" || { cat "$FILE"; fail "missing pattern '$pattern' in $FILE"; }
done
echo "PASS"
