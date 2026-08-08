#!/usr/bin/env bash
# Shared helper functions for every skill's tests under tests/<skill-name>/.
# One shared file, not one per skill — matches obra/superpowers, where every
# skill's tests in tests/claude-code/ source the same test-helpers.sh rather
# than each carrying its own copy. See docs/testing.md for what's kept,
# adapted, or deliberately not copied from theirs.

# Repo root, computed from this file's own location so it works whether
# run from the primary checkout or any worktree — never hardcode a path.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# macOS ships no `timeout` (BSD userland); coreutils via Homebrew provides
# it as `gtimeout`. Fall back to running untimed rather than failing outright.
if command -v timeout &> /dev/null; then
    _TIMEOUT_CMD="timeout"
elif command -v gtimeout &> /dev/null; then
    _TIMEOUT_CMD="gtimeout"
else
    _TIMEOUT_CMD=""
fi

# Run Claude Code against this repo's plugin content and capture output.
# Usage: run_claude "prompt text" [timeout_seconds] [--continue]
#
# Deliberately different from superpowers' version:
# - Always passes --plugin-dir "$REPO_ROOT": we're testing in-progress
#   branch content before it's installed anywhere, not an already-installed
#   plugin. Using an installed copy here would test the wrong thing.
# - Always passes --permission-mode acceptEdits: our tested behaviors write
#   and delete real files. Without this, non-interactive -p writes get
#   silently blocked and the model asks for permission in text instead of
#   actually writing — looks exactly like "the skill didn't trigger" but
#   isn't. Superpowers' sampled tests are mostly read-only comprehension
#   checks ("what does this skill do?"), so they don't need it.
# - Third arg is literally --continue, for a second turn in the same
#   scratch-repo session (our confirm-then-write/delete gates need this).
run_claude() {
    local prompt="$1"
    local timeout_s="${2:-60}"
    local continue_flag="${3:-}"

    local cmd=(claude --plugin-dir "$REPO_ROOT" --permission-mode acceptEdits)
    [[ -n "$continue_flag" ]] && cmd+=("$continue_flag")
    cmd+=(-p "$prompt")

    if [[ -n "$_TIMEOUT_CMD" ]]; then
        "$_TIMEOUT_CMD" "$timeout_s" "${cmd[@]}"
    else
        "${cmd[@]}"
    fi
}

# Check if output contains a pattern (case-insensitive: patterns are prose
# keywords, and models capitalize inconsistently).
# Usage: assert_contains "output" "pattern" "test name"
assert_contains() {
    local output="$1"
    local pattern="$2"
    local test_name="${3:-test}"

    if echo "$output" | grep -qi -- "$pattern"; then
        echo "  [PASS] $test_name"
        return 0
    else
        echo "  [FAIL] $test_name"
        echo "  Expected to find: $pattern"
        echo "  In output:"
        echo "$output" | sed 's/^/    /'
        return 1
    fi
}

# Usage: assert_not_contains "output" "pattern" "test name"
assert_not_contains() {
    local output="$1"
    local pattern="$2"
    local test_name="${3:-test}"

    if echo "$output" | grep -qi -- "$pattern"; then
        echo "  [FAIL] $test_name"
        echo "  Did not expect to find: $pattern"
        echo "  In output:"
        echo "$output" | sed 's/^/    /'
        return 1
    else
        echo "  [PASS] $test_name"
        return 0
    fi
}

# Check that pattern A appears before pattern B in output.
# Usage: assert_order "output" "pattern_a" "pattern_b" "test name"
assert_order() {
    local output="$1"
    local pattern_a="$2"
    local pattern_b="$3"
    local test_name="${4:-test}"

    local line_a line_b
    line_a=$(echo "$output" | grep -ni -- "$pattern_a" | head -1 | cut -d: -f1)
    line_b=$(echo "$output" | grep -ni -- "$pattern_b" | head -1 | cut -d: -f1)

    if [[ -z "$line_a" ]]; then
        echo "  [FAIL] $test_name: pattern A not found: $pattern_a"
        return 1
    fi
    if [[ -z "$line_b" ]]; then
        echo "  [FAIL] $test_name: pattern B not found: $pattern_b"
        return 1
    fi
    if [[ "$line_a" -lt "$line_b" ]]; then
        echo "  [PASS] $test_name (A at line $line_a, B at line $line_b)"
        return 0
    else
        echo "  [FAIL] $test_name"
        echo "  Expected '$pattern_a' before '$pattern_b', found A at $line_a, B at $line_b"
        return 1
    fi
}

# No equivalent in superpowers' helpers — our tested behaviors are file
# creation/deletion, not just conversational replies, so we need file-level
# assertions on top of the output-text ones above.
# Usage: assert_file_exists "path/glob" "test name"
assert_file_exists() {
    local pattern="$1"
    local test_name="${2:-test}"

    if compgen -G "$pattern" > /dev/null; then
        echo "  [PASS] $test_name"
        return 0
    else
        echo "  [FAIL] $test_name"
        echo "  Expected a file matching: $pattern"
        return 1
    fi
}

# Usage: assert_no_file "path/glob" "test name"
assert_no_file() {
    local pattern="$1"
    local test_name="${2:-test}"

    if compgen -G "$pattern" > /dev/null; then
        echo "  [FAIL] $test_name"
        echo "  Expected no file matching: $pattern (found: $(compgen -G "$pattern"))"
        return 1
    else
        echo "  [PASS] $test_name"
        return 0
    fi
}

# Usage: assert_frontmatter "file" "^field: value$" "test name"
assert_frontmatter() {
    local file="$1"
    local pattern="$2"
    local test_name="${3:-test}"

    if grep -qE -- "$pattern" "$file"; then
        echo "  [PASS] $test_name"
        return 0
    else
        echo "  [FAIL] $test_name"
        echo "  Expected pattern in $file: $pattern"
        echo "  File contents:"
        sed 's/^/    /' "$file"
        return 1
    fi
}

# Create a fresh scratch git repo and cd into it. Auto-cleaned on exit —
# unlike superpowers' create_test_project/cleanup_test_project pair (manual
# cleanup, called explicitly), this traps EXIT so a test that fails partway
# through still cleans up. Call once per test file, near the top.
new_scratch_repo() {
    local dir
    dir="$(mktemp -d)"
    # shellcheck disable=SC2064 # intentional early expansion of $dir
    trap "rm -rf '$dir'" EXIT
    cd "$dir"
    git init -q
}

export -f run_claude
export -f assert_contains
export -f assert_not_contains
export -f assert_order
export -f assert_file_exists
export -f assert_no_file
export -f assert_frontmatter
export -f new_scratch_repo
