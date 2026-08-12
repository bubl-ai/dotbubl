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
#   real files. Without this, non-interactive -p writes get silently
#   blocked and the model asks for permission in text instead of actually
#   writing — looks exactly like "the skill didn't trigger" but isn't.
#   Superpowers' sampled tests are mostly read-only comprehension checks
#   ("what does this skill do?"), so they don't need it. Note: completion
#   (deletion) has no dedicated file tool and goes through Bash `rm` —
#   acceptEdits is documented as covering Edit/Write/NotebookEdit
#   specifically, not Bash. Empirically this hasn't caused a problem across
#   every test-4-completion.sh run so far (deletion has always gone
#   through cleanly), but if headless deletion ever starts blocking, this
#   is the first place to look.
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
        # -k: escalate to SIGKILL if still running 10s after the initial
        # signal, so a hung/SIGTERM-ignoring claude process is actually
        # bounded rather than potentially waiting indefinitely.
        "$_TIMEOUT_CMD" -k 10 "$timeout_s" "${cmd[@]}"
    else
        "${cmd[@]}"
    fi
}

# Run Claude Code with structured (stream-json) output, for tests that need
# to verify actual tool/subagent dispatch rather than just relayed text —
# plain run_claude only captures the final assistant message, which can't
# prove a specific subagent type was actually invoked (the model could
# answer directly instead of dispatching it, and the final text would look
# identical either way).
# Usage: run_claude_json "prompt" [timeout_seconds]
# Outputs the raw stream-json lines (one JSON object per line).
run_claude_json() {
    local prompt="$1"
    local timeout_s="${2:-60}"

    local cmd=(claude --plugin-dir "$REPO_ROOT" --permission-mode acceptEdits --output-format stream-json --verbose)
    cmd+=(-p "$prompt")

    if [[ -n "$_TIMEOUT_CMD" ]]; then
        "$_TIMEOUT_CMD" -k 10 "$timeout_s" "${cmd[@]}" 2>&1
    else
        "${cmd[@]}" 2>&1
    fi
}

# Check that a subagent of the given type was actually dispatched via the
# Agent tool, by looking for its subagent_type on a stream-json event —
# not just present in relayed conversational text (which is easy to satisfy
# without actually dispatching anything).
# Usage: assert_subagent_dispatched "json_output" "dotbubl:guideline-check" "test name"
assert_subagent_dispatched() {
    local json_output="$1"
    local subagent_type="$2"
    local test_name="${3:-test}"

    if echo "$json_output" | grep -q "\"subagent_type\":\"$subagent_type\""; then
        echo "  [PASS] $test_name"
        return 0
    else
        echo "  [FAIL] $test_name"
        echo "  Expected a dispatched subagent_type: $subagent_type"
        return 1
    fi
}

# Check that a subagent of the given type called the named tool
# (e.g. ReportFindings) by examining the actual tool-use event in the assistant
# message, not a progress-event summary which may not fire. Checks for
# "name":"$tool_name" on lines mentioning the subagent_type, filtering to
# subagent_type first then checking for the tool name within that subset —
# order-independent, since JSON key order isn't guaranteed stable.
# Usage: assert_subagent_used_tool "json_output" "dotbubl:guideline-check" "ReportFindings" "test name"
assert_subagent_used_tool() {
    local json_output="$1"
    local subagent_type="$2"
    local tool_name="$3"
    local test_name="${4:-test}"

    if echo "$json_output" | grep "\"subagent_type\":\"$subagent_type\"" | grep -q "\"name\":\"$tool_name\""; then
        echo "  [PASS] $test_name"
        return 0
    else
        echo "  [FAIL] $test_name"
        echo "  Expected subagent_type $subagent_type to have used tool: $tool_name"
        return 1
    fi
}

# Check that a subagent of the given type called ReportFindings with an
# empty findings array — for "already correct, nothing to report" test
# cases. Scopes to the ReportFindings tool-use event for that subagent_type
# first (same pattern as assert_subagent_used_tool), then checks its input
# carries an empty findings array. Tolerant of optional whitespace after
# the colon since JSON serializers aren't guaranteed to omit it.
# Usage: assert_subagent_empty_findings "json_output" "dotbubl:guideline-check" "test name"
assert_subagent_empty_findings() {
    local json_output="$1"
    local subagent_type="$2"
    local test_name="${3:-test}"

    local scoped
    scoped=$(echo "$json_output" | grep "\"subagent_type\":\"$subagent_type\"" | grep "\"name\":\"ReportFindings\"")

    if [[ -z "$scoped" ]]; then
        echo "  [FAIL] $test_name"
        echo "  Expected subagent_type $subagent_type to have called ReportFindings"
        return 1
    fi

    if echo "$scoped" | grep -qE '"findings":[[:space:]]*\[\]'; then
        echo "  [PASS] $test_name"
        return 0
    else
        echo "  [FAIL] $test_name"
        echo "  Expected ReportFindings called with an empty findings array"
        return 1
    fi
}

# Check that a subagent of the given type called ReportFindings with a
# non-empty findings array whose content matches the given pattern —
# proves the *finding itself* (not just surrounding conversation text)
# names what's expected, since plain output-text grepping can pass
# vacuously (the pattern may appear in the subagent's own git diff/Read
# output regardless of what it concluded).
# Usage: assert_subagent_finding_mentions "json_output" "dotbubl:guideline-check" "setup.md" "test name"
assert_subagent_finding_mentions() {
    local json_output="$1"
    local subagent_type="$2"
    local pattern="$3"
    local test_name="${4:-test}"

    local scoped
    scoped=$(echo "$json_output" | grep "\"subagent_type\":\"$subagent_type\"" | grep "\"name\":\"ReportFindings\"")

    if [[ -z "$scoped" ]]; then
        echo "  [FAIL] $test_name"
        echo "  Expected subagent_type $subagent_type to have called ReportFindings"
        return 1
    fi

    if echo "$scoped" | grep -qi -- "$pattern"; then
        echo "  [PASS] $test_name"
        return 0
    else
        echo "  [FAIL] $test_name"
        echo "  Expected the ReportFindings call itself to mention: $pattern"
        return 1
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

# Check that pattern A appears before pattern B in output — by line number,
# falling back to in-line character position when both land on the same
# line (a model isn't guaranteed to one-item-per-line just because asked
# to), rather than reporting a false FAIL for a same-line case where A
# still textually precedes B.
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
    elif [[ "$line_a" -eq "$line_b" ]]; then
        # Same line: compare literal substring position instead of failing
        # outright. index() is a plain substring search (not regex) — fine
        # here since assert_order is always called with literal text, not
        # patterns relying on regex metacharacters.
        local line_text pos_a pos_b
        line_text=$(echo "$output" | sed -n "${line_a}p")
        pos_a=$(awk -v s="$line_text" -v p="$pattern_a" 'BEGIN{print index(tolower(s), tolower(p))}')
        pos_b=$(awk -v s="$line_text" -v p="$pattern_b" 'BEGIN{print index(tolower(s), tolower(p))}')
        if [[ "$pos_a" -gt 0 && "$pos_b" -gt 0 && "$pos_a" -lt "$pos_b" ]]; then
            echo "  [PASS] $test_name (both on line $line_a, A before B)"
            return 0
        else
            echo "  [FAIL] $test_name: both on line $line_a but A not before B"
            echo "  Line: $line_text"
            return 1
        fi
    else
        echo "  [FAIL] $test_name"
        echo "  Expected '$pattern_a' before '$pattern_b', found A at line $line_a, B at line $line_b"
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
export -f run_claude_json
export -f assert_contains
export -f assert_not_contains
export -f assert_order
export -f assert_file_exists
export -f assert_no_file
export -f assert_frontmatter
export -f assert_subagent_dispatched
export -f assert_subagent_used_tool
export -f assert_subagent_empty_findings
export -f assert_subagent_finding_mentions
export -f new_scratch_repo
