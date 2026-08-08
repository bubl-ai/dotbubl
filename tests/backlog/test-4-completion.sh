#!/usr/bin/env bash
# Verifies: completing an item requires explicit confirmation before the
# file is deleted (deletion is permanent, no archive/status field).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../test-helpers.sh"

echo "=== Test: completion gates on confirmation before deleting ==="

new_scratch_repo
FAILURES=0

mkdir -p backlog
cat > backlog/0001-fix-flaky-login-test.md <<'EOF'
---
id: 1
title: Fix flaky login test
type: bug
priority: P2
tags: [ci]
created: 2026-08-01
---

## Description
The login test intermittently times out in CI.

## Acceptance Criteria
- [ ] Test passes 20/20 consecutive CI runs
EOF

run_claude "Backlog item 1 is done, the fix shipped." >/dev/null

assert_file_exists "backlog/0001-fix-flaky-login-test.md" "file still exists before explicit go-ahead" || FAILURES=$((FAILURES + 1))

run_claude "Yes, remove it." 60 --continue >/dev/null

assert_no_file "backlog/0001-fix-flaky-login-test.md" "file deleted after explicit go-ahead" || FAILURES=$((FAILURES + 1))

if [[ "$FAILURES" -gt 0 ]]; then
  echo "=== FAILED ($FAILURES) ==="
  exit 1
fi
echo "=== PASS ==="
