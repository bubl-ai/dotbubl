#!/usr/bin/env bash
# Shared setup for skills/backlog smoke tests. Source this, don't run it.
set -euo pipefail

# Repo root, computed from this file's own location so it works whether
# run from the primary checkout or any worktree — never hardcode a path.
DOTBUBL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Fresh, disposable git repo per test — the skill never touches dotbubl's
# own backlog/ (there isn't one), only the invoking project's.
SCRATCH="$(mktemp -d)"
cd "$SCRATCH"
git init -q

claude_backlog() {
  # --permission-mode acceptEdits: non-interactive -p writes otherwise get
  # silently blocked and the model asks for permission in text instead of
  # actually writing — looks exactly like "the skill didn't trigger" but isn't.
  claude --plugin-dir "$DOTBUBL_DIR" --permission-mode acceptEdits "$@"
}

fail() {
  echo "FAIL: $1"
  exit 1
}
