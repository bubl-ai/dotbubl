#!/usr/bin/env bash
# Verifies: a task identified and deferred mid-session is NOT written until
# a separate, explicit confirmation — the two-gate design's core property.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Concrete detail matters here: the skill correctly refuses to fabricate
# specifics for code that doesn't exist in an empty scratch repo, so a vague
# "this could be split out" prompt won't produce a draft to confirm at all.
claude_backlog -p "While reviewing this code you noticed the create_user function doesn't validate the email field format or check for empty password values before hashing. That's worth fixing but out of scope for this PR — propose deferring it as a follow-up: type chore, priority P2, tag validation. I approve deferring it."

find backlog -maxdepth 1 -name '*.md' 2>/dev/null | grep -q . \
  && fail "a file was written before explicit go-ahead"

claude_backlog --continue -p "Yes, go ahead and add it."

FILE=$(find backlog -maxdepth 1 -name '0001-*.md' 2>/dev/null | head -n1)
[[ -n "$FILE" ]] || fail "no file was written after explicit go-ahead"

for pattern in '^type: chore$' '^priority: P2$' 'validation'; do
  grep -qE "$pattern" "$FILE" || { cat "$FILE"; fail "missing pattern '$pattern' in $FILE"; }
done
echo "PASS"
