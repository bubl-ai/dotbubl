#!/usr/bin/env bash
# Verifies: querying the backlog reports items sorted by priority (P0 first).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Test: query sorts by priority ==="

new_scratch_repo
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

output=$(run_claude "List everything in the backlog, sorted by priority. Format each line EXACTLY as: <priority> #<id> <title>")

FAILURES=0
assert_order "$output" "P0 #2 Add dark mode toggle" "P2 #1 Fix flaky login test" "P0 item listed before P2 item" || FAILURES=$((FAILURES + 1))

if [[ "$FAILURES" -gt 0 ]]; then
  echo "=== FAILED ($FAILURES) ==="
  exit 1
fi
echo "=== PASS ==="
