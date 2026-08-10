#!/usr/bin/env bash
# Test runner for the guideline-check agent.
# Modeled on obra/superpowers' tests/claude-code/run-skill-tests.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================"
echo " guideline-check agent test suite"
echo "========================================"
echo ""
echo "Repository: $(cd ../.. && pwd)"
echo "Test time: $(date)"
echo "Claude version: $(claude --version 2>/dev/null || echo 'not found')"
echo ""

if ! command -v claude &> /dev/null; then
    echo "ERROR: Claude Code CLI not found"
    exit 1
fi

# macOS ships no `timeout` (BSD userland); `coreutils` via Homebrew provides
# it as `gtimeout`. Fall back to running untimed rather than failing outright.
if command -v timeout &> /dev/null; then
    TIMEOUT_CMD="timeout"
elif command -v gtimeout &> /dev/null; then
    TIMEOUT_CMD="gtimeout"
else
    echo "WARNING: no 'timeout' or 'gtimeout' on PATH — running without a timeout wrapper."
    echo "         Install coreutils (e.g. 'brew install coreutils') to enable it."
    TIMEOUT_CMD=""
fi

run_with_timeout() {
    local seconds="$1"
    shift
    if [[ -n "$TIMEOUT_CMD" ]]; then
        # -k: if the process ignores SIGTERM and is still running 10s later,
        # send SIGKILL. Without this, a hung claude CLI can wait indefinitely
        # instead of actually being bounded by $TIMEOUT.
        "$TIMEOUT_CMD" -k 10 "$seconds" "$@"
    else
        "$@"
    fi
}

VERBOSE=false
SPECIFIC_TEST=""
# Per-test-file budget. Tests dispatch a subagent (more overhead than a
# plain skill invocation) via run_claude at up to 120s each — 180s would
# leave little slack for git init / process-startup overhead, so give it
# more room than tests/backlog/run-all.sh does.
TIMEOUT=240

while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --test|-t)
            SPECIFIC_TEST="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --verbose, -v        Show verbose output"
            echo "  --test, -t NAME      Run only the specified test file"
            echo "  --timeout SECONDS    Set timeout per test (default: 240)"
            echo "  --help, -h           Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

tests=()
for f in "$SCRIPT_DIR"/test-*.sh; do
    [[ "$(basename "$f")" == *-helpers.sh ]] && continue
    tests+=("$f")
done
if [[ -n "$SPECIFIC_TEST" ]]; then
    tests=("$SCRIPT_DIR/$SPECIFIC_TEST")
fi

if [[ "${#tests[@]}" -eq 0 ]]; then
    echo "ERROR: no test files matched — nothing to run."
    exit 1
fi

passed=0
failed=0

for test_path in "${tests[@]}"; do
    test_name="$(basename "$test_path")"
    echo "----------------------------------------"
    echo "Running: $test_name"
    echo "----------------------------------------"

    if [[ ! -f "$test_path" ]]; then
        echo "  [FAIL] Test file not found: $test_name"
        failed=$((failed + 1))
        echo ""
        continue
    fi
    [[ -x "$test_path" ]] || chmod +x "$test_path"

    start_time=$(date +%s)

    if [[ "$VERBOSE" == true ]]; then
        if run_with_timeout "$TIMEOUT" bash "$test_path"; then
            echo "  [PASS] $test_name ($(( $(date +%s) - start_time ))s)"
            passed=$((passed + 1))
        else
            exit_code=$?
            [[ "$exit_code" -eq 124 ]] && echo "  [FAIL] $test_name (timeout after ${TIMEOUT}s)" \
                || echo "  [FAIL] $test_name ($(( $(date +%s) - start_time ))s)"
            failed=$((failed + 1))
        fi
    else
        if output=$(run_with_timeout "$TIMEOUT" bash "$test_path" 2>&1); then
            echo "  [PASS] ($(( $(date +%s) - start_time ))s)"
            passed=$((passed + 1))
        else
            exit_code=$?
            [[ "$exit_code" -eq 124 ]] && echo "  [FAIL] (timeout after ${TIMEOUT}s)" \
                || echo "  [FAIL] ($(( $(date +%s) - start_time ))s)"
            echo ""
            echo "  Output:"
            echo "$output" | sed 's/^/    /'
            failed=$((failed + 1))
        fi
    fi
    echo ""
done

echo "========================================"
echo " Test Results Summary"
echo "========================================"
echo ""
echo "  Passed: $passed"
echo "  Failed: $failed"
echo ""

if [[ "$failed" -gt 0 ]]; then
    echo "STATUS: FAILED"
    exit 1
else
    echo "STATUS: PASSED"
    exit 0
fi
