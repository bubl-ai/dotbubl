#!/usr/bin/env bash
# Verifies: doc scope actually expands past CLAUDE.md/README.md to files
# they reference. CLAUDE.md points at docs/architecture.md, which goes
# stale (README.md itself stays untouched and accurate throughout).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../test-helpers.sh"

echo "=== Test: keeping-docs-current follows CLAUDE.md's references ==="

new_scratch_repo
mkdir -p docs core cli
cat > CLAUDE.md <<'EOF'
# CLAUDE.md

See docs/architecture.md for how the modules are organized.
EOF
cat > README.md <<'EOF'
# Example project
EOF
cat > docs/architecture.md <<'EOF'
# Architecture

This project has two modules: `core/` and `cli/`.
EOF
touch core/.gitkeep cli/.gitkeep
git add -A
git commit -q -m "init: two modules, documented in docs/architecture.md"
BASE_SHA=$(git rev-parse HEAD)

git rm -rq cli
git commit -q -m "remove cli module without updating docs/architecture.md"

output=$(run_claude_json "Use the keeping-docs-current skill to check whether this repository's documentation is stale, using base ref $BASE_SHA." 120)

FAILURES=0
assert_subagent_dispatched "$output" "dotbubl:guideline-check" "dispatched the guideline-check subagent" || FAILURES=$((FAILURES + 1))
assert_subagent_used_tool "$output" "dotbubl:guideline-check" "ReportFindings" "concluded via ReportFindings" || FAILURES=$((FAILURES + 1))
assert_contains "$output" "architecture.md" "found the staleness in the referenced doc, not just CLAUDE.md/README.md" || FAILURES=$((FAILURES + 1))

if [[ "$FAILURES" -gt 0 ]]; then
  echo "=== FAILED ($FAILURES) ==="
  exit 1
fi
echo "=== PASS ==="
