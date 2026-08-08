#!/usr/bin/env bash
# Verifies: completing an item requires explicit confirmation before the
# file is deleted (deletion is permanent, no archive/status field).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

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

claude_backlog -p "Backlog item 1 is done, the fix shipped."

[[ -f backlog/0001-fix-flaky-login-test.md ]] \
  || fail "file was deleted before explicit go-ahead"

claude_backlog --continue -p "Yes, remove it."

[[ ! -f backlog/0001-fix-flaky-login-test.md ]] \
  || fail "file still exists after explicit go-ahead"
echo "PASS"
