#!/usr/bin/env bash
# Verifies: on a branch where a doc-relevant change is accompanied by a
# correct doc update, keeping-docs-current reports no findings.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../test-helpers.sh"

echo "=== Test: keeping-docs-current reports nothing when docs are current ==="

new_scratch_repo
mkdir -p docs
cat > README.md <<'EOF'
# Example

See docs/setup.md for local setup instructions.
EOF
cat > CLAUDE.md <<'EOF'
# CLAUDE.md

See README.md for how this project is set up.
EOF
cat > docs/setup.md <<'EOF'
# Setup

Run ./install.sh to set up your environment.
EOF
git add -A
git commit -q -m "init: docs and setup guide are consistent"
BASE_SHA=$(git rev-parse HEAD)

git rm -q docs/setup.md
cat > README.md <<'EOF'
# Example

Local setup instructions: run ./install.sh to set up your environment.
EOF
git add README.md
git commit -q -m "inline setup instructions, update README accordingly"

output=$(run_claude_json "Use the keeping-docs-current skill to check whether this repository's documentation is stale, using base ref $BASE_SHA." 120)

FAILURES=0
assert_subagent_dispatched "$output" "dotbubl:guideline-check" "dispatched the guideline-check subagent" || FAILURES=$((FAILURES + 1))
assert_subagent_empty_findings "$output" "dotbubl:guideline-check" "reports no findings" || FAILURES=$((FAILURES + 1))

if [[ "$FAILURES" -gt 0 ]]; then
  echo "=== FAILED ($FAILURES) ==="
  exit 1
fi
echo "=== PASS ==="
