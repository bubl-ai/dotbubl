#!/usr/bin/env bash
# Verifies: keeping-docs-current actually scopes its check to the diff
# against the supplied base ref, rather than judging the repo's overall
# current state regardless of which ref it's told to use. Same staleness
# scenario as test-1, dispatched twice with two different base refs: one
# that spans the staleness-introducing commit (expect a finding) and one
# that doesn't (expect none).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../test-helpers.sh"

echo "=== Test: keeping-docs-current diffs against the supplied base ref ==="

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
BASE_OLD=$(git rev-parse HEAD)

git rm -q docs/setup.md
git commit -q -m "remove setup doc without updating README"
BASE_RECENT=$(git rev-parse HEAD)

echo "unrelated change" > unrelated.txt
git add unrelated.txt
git commit -q -m "unrelated change, nothing doc-relevant"

FAILURES=0

output_old=$(run_claude_json "Use the keeping-docs-current skill to check whether this repository's documentation is stale, using base ref $BASE_OLD." 120)
assert_subagent_dispatched "$output_old" "dotbubl:guideline-check" "dispatched for base ref spanning the staleness-introducing commit" || FAILURES=$((FAILURES + 1))
assert_subagent_finding_mentions "$output_old" "dotbubl:guideline-check" "setup.md" "finds the staleness when the base ref spans it" || FAILURES=$((FAILURES + 1))

output_recent=$(run_claude_json "Use the keeping-docs-current skill to check whether this repository's documentation is stale, using base ref $BASE_RECENT." 120)
assert_subagent_dispatched "$output_recent" "dotbubl:guideline-check" "dispatched for base ref after the staleness-introducing commit" || FAILURES=$((FAILURES + 1))
assert_subagent_empty_findings "$output_recent" "dotbubl:guideline-check" "reports nothing when the diff doesn't span the staleness" || FAILURES=$((FAILURES + 1))

if [[ "$FAILURES" -gt 0 ]]; then
  echo "=== FAILED ($FAILURES) ==="
  exit 1
fi
echo "=== PASS ==="
