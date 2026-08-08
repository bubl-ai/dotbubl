#!/usr/bin/env bash
# Verifies: querying the backlog reports items sorted by priority (P0 first).
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

cat > backlog/0002-add-dark-mode.md <<'EOF'
---
id: 2
title: Add dark mode toggle
type: feature
priority: P0
tags: [tui, theming]
created: 2026-08-02
---

## Description
Users want a dark mode toggle in settings.

## Acceptance Criteria
- [ ] Toggle persists across sessions
EOF

OUT="$(claude_backlog -p "List everything in the backlog, sorted by priority. Format each line EXACTLY as: <priority> #<id> <title>")"
echo "$OUT"

LINE_P0=$(grep -n "P0 #2 Add dark mode toggle" <<<"$OUT" | cut -d: -f1 || true)
LINE_P2=$(grep -n "P2 #1 Fix flaky login test" <<<"$OUT" | cut -d: -f1 || true)

[[ -n "$LINE_P0" && -n "$LINE_P2" && "$LINE_P0" -lt "$LINE_P2" ]] \
  || fail "expected P0 item before P2 item"
echo "PASS"
