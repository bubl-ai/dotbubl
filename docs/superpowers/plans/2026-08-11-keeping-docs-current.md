# keeping-docs-current skill — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `skills/keeping-docs-current/SKILL.md`, a dotbubl skill that checks whether `CLAUDE.md`/`README.md`/referenced docs are stale relative to a given base ref, by dispatching the shared `guideline-check` subagent — with committed tests and the doc updates that follow from adding the repo's second real skill.

**Architecture:** A single skill file, self-contained (no new agent, no new tool, no config). Given a base ref supplied by the caller, its instructions have Claude call `Agent` with `subagent_type: "guideline-check"`, passing a fixed concern template (doc scope, staleness definition, `ReportFindings` field mapping) plus that ref, then relay the subagent's determination back verbatim. Tested the same way `tests/guideline-check/` tests the agent it wraps: real headless `claude -p --plugin-dir` invocations with `--output-format stream-json` against disposable scratch git repos, proving actual subagent dispatch (not just relayed text).

**Tech Stack:** Bash test scripts sourcing the repo's shared `tests/test-helpers.sh`; Claude Code skill frontmatter (YAML) + prose in `skills/keeping-docs-current/SKILL.md`; no other runtime dependencies.

## Global Constraints

- `keeping-docs-current` never auto-detects a base ref — always requires one supplied by the caller (see design spec's "Decisions" section).
- Doc-scope discovery (following what `CLAUDE.md`/`README.md` reference) happens inside the `guideline-check` dispatch, via the subagent's own `Read`/`Grep`/`Glob` — not pre-walked by this skill.
- Findings map onto `ReportFindings` as: `file` = stale doc's path, `summary` = one-line staleness claim, `failure_scenario` = drift description (code vs. doc claim), `category` = `"doc-staleness"`.
- Tests live at `tests/keeping-docs-current/`, mirroring `tests/guideline-check/`'s shape: `test-N-<behavior>.sh` files, `run-all.sh`, `README.md`, sourcing the shared `tests/test-helpers.sh` (never copied per-directory).
- Every test file accumulates failures in a `FAILURES` counter and exits non-zero only at the end, rather than stopping at the first failed assertion.
- Tests must be actually run (not just claimed to pass) before each task's commit, per `CLAUDE.md`'s Testing convention.
- In dispatch prose (the skill's own instructions, test prompts), the subagent is referred to by its bare name, `subagent_type: "guideline-check"` — the plugin prefix is applied automatically at runtime, matching how `agents/guideline-check.md` and `tests/guideline-check/`'s prompts already do it. In test *assertions* checking the resulting JSON stream, use the plugin-qualified `dotbubl:guideline-check` — that's the form Claude Code actually emits in `subagent_type` fields (matching `tests/guideline-check/`'s own assertions).
- Version must be bumped identically in both `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (`plugins[0].version`) — installed copies only notice an update when the version actually changes.
- Every commit message ends with `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`.
- Fix documentation drift in the same commit as the change that causes it — never as a follow-up (`CLAUDE.md`'s "Documentation stays current").

---

### Task 1: `skills/keeping-docs-current/SKILL.md` with tests (TDD)

**Files:**
- Create: `tests/keeping-docs-current/test-1-stale-docs-reported.sh`
- Create: `tests/keeping-docs-current/test-2-current-docs-no-findings.sh`
- Create: `tests/keeping-docs-current/test-3-diffs-against-base-ref.sh`
- Create: `tests/keeping-docs-current/test-4-reference-following.sh`
- Create: `tests/keeping-docs-current/run-all.sh`
- Create: `tests/keeping-docs-current/README.md`
- Create: `skills/keeping-docs-current/SKILL.md`
- Modify: `tests/test-helpers.sh` (add `assert_subagent_empty_findings`)

**Interfaces:**
- Consumes: `tests/test-helpers.sh`'s `new_scratch_repo`, `run_claude_json`, `assert_subagent_dispatched`, `assert_subagent_used_tool`, `assert_contains` (all already defined at repo root — see `tests/test-helpers.sh`). Also consumes the `dotbubl:guideline-check` subagent from #1 (already merged, `agents/guideline-check.md`).
- Produces: `assert_subagent_empty_findings(json_output, subagent_type, test_name)` in `tests/test-helpers.sh`, usable by any future guideline's tests that need to assert a clean "no findings" `ReportFindings` call, not just this one. Also produces the `keeping-docs-current` skill itself, invocable via `Skill(dotbubl:keeping-docs-current)` by any later caller (a human, or eventually `before-pr-checks`, #3, out of scope here) — no other task in this plan calls into it.

- [ ] **Step 1: Write the failing test — stale docs reported**

Create `tests/keeping-docs-current/test-1-stale-docs-reported.sh`:

```bash
#!/usr/bin/env bash
# Verifies: on a branch with an intentionally stale doc reference (README
# points at a doc file that got deleted in a later commit, without the
# reference being updated), keeping-docs-current reports the staleness via
# ReportFindings, naming the actual stale reference.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../test-helpers.sh"

echo "=== Test: keeping-docs-current reports a stale doc reference ==="

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
git commit -q -m "remove setup doc without updating README"

output=$(run_claude_json "Use the keeping-docs-current skill to check whether this repository's documentation is stale, using base ref $BASE_SHA." 120)

FAILURES=0
assert_subagent_dispatched "$output" "dotbubl:guideline-check" "dispatched the guideline-check subagent" || FAILURES=$((FAILURES + 1))
assert_subagent_used_tool "$output" "dotbubl:guideline-check" "ReportFindings" "concluded via ReportFindings" || FAILURES=$((FAILURES + 1))
assert_contains "$output" "setup.md" "names the actual stale reference" || FAILURES=$((FAILURES + 1))

if [[ "$FAILURES" -gt 0 ]]; then
  echo "=== FAILED ($FAILURES) ==="
  exit 1
fi
echo "=== PASS ==="
```

- [ ] **Step 2: Write the failing test — current docs, no findings**

Create `tests/keeping-docs-current/test-2-current-docs-no-findings.sh`:

```bash
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
```

- [ ] **Step 3: Write the failing test — diffs against the given base ref**

Create `tests/keeping-docs-current/test-3-diffs-against-base-ref.sh`:

```bash
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
assert_contains "$output_old" "setup.md" "finds the staleness when the base ref spans it" || FAILURES=$((FAILURES + 1))

output_recent=$(run_claude_json "Use the keeping-docs-current skill to check whether this repository's documentation is stale, using base ref $BASE_RECENT." 120)
assert_subagent_dispatched "$output_recent" "dotbubl:guideline-check" "dispatched for base ref after the staleness-introducing commit" || FAILURES=$((FAILURES + 1))
assert_subagent_empty_findings "$output_recent" "dotbubl:guideline-check" "reports nothing when the diff doesn't span the staleness" || FAILURES=$((FAILURES + 1))

if [[ "$FAILURES" -gt 0 ]]; then
  echo "=== FAILED ($FAILURES) ==="
  exit 1
fi
echo "=== PASS ==="
```

- [ ] **Step 4: Write the failing test — reference-following**

Create `tests/keeping-docs-current/test-4-reference-following.sh`:

```bash
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
```

- [ ] **Step 5: Create the test runner and README**

Create `tests/keeping-docs-current/run-all.sh` (copy of `tests/guideline-check/run-all.sh` with the suite name changed):

```bash
#!/usr/bin/env bash
# Test runner for the keeping-docs-current skill.
# Modeled on obra/superpowers' tests/claude-code/run-skill-tests.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================"
echo " keeping-docs-current skill test suite"
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
# Per-test-file budget. test-3 dispatches the subagent twice in one file,
# so it gets the most headroom of any test here — 240s (tests/guideline-check/'s
# own budget) would be tight for two dispatches, so this suite uses 300s.
TIMEOUT=300

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
            echo "  --timeout SECONDS    Set timeout per test (default: 300)"
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
```

Create `tests/keeping-docs-current/README.md`:

```markdown
# keeping-docs-current skill tests

Automated tests for the `keeping-docs-current` skill, modeled on
`tests/guideline-check/`'s conventions (see `docs/testing.md` at the repo
root for how this fits into the project's overall testing approach).

## Overview

Each test invokes Claude Code in headless mode (`claude -p`) against a
disposable scratch git repo, pointed at this repo's in-progress
`--plugin-dir`, and asks it to use the `keeping-docs-current` skill with a
specific base ref. The skill's own job is to dispatch the `guideline-check`
subagent (see `tests/guideline-check/README.md` for that agent's own
tests) — these tests verify the skill's concern template actually produces
correct doc-staleness analysis, not `guideline-check`'s generic mechanics
again.

## Requirements

- Claude Code CLI installed and in PATH (`claude --version` should work)
- No plugin installation needed — tests point `--plugin-dir` at this repo
  directly

## Running tests

```bash
./run-all.sh                                         # all tests
./run-all.sh --verbose                               # full output, not just pass/fail
./run-all.sh --test test-2-current-docs-no-findings.sh   # one test
./run-all.sh --timeout 360                           # override the per-test timeout
```

Exit code 0 = all passed, non-zero = at least one failed.

## Test structure

### ../test-helpers.sh

Shared across every skill's and agent's tests — see `tests/backlog/README.md`
and `tests/guideline-check/README.md` for the full rundown of what it
provides (`run_claude_json`, `assert_subagent_dispatched`,
`assert_subagent_used_tool`, `assert_subagent_empty_findings`,
`new_scratch_repo`). Sourced here the same way:
`"$SCRIPT_DIR/../test-helpers.sh"`.

### Test files

Each `test-N-<behavior>.sh`:
1. Sources `../test-helpers.sh`
2. Sets up a scratch repo with a base commit (docs consistent with reality)
   and a later commit that changes something without updating the docs
3. Runs `run_claude_json`, telling the model to use the `keeping-docs-current`
   skill with an explicit base ref — `run_claude_json`, not `run_claude`,
   because structured JSON output is needed to prove the subagent was
   actually dispatched
4. Asserts using `assert_subagent_dispatched`, `assert_subagent_used_tool`,
   `assert_subagent_empty_findings`, and `assert_contains` as needed,
   accumulating failures rather than stopping at the first one
5. Exits 0 on success, 1 if any assertion failed

## Current tests

| File | Verifies |
|------|----------|
| `test-1-stale-docs-reported.sh` | A stale doc reference (README pointing at a deleted file) is reported via ReportFindings, naming the actual stale reference |
| `test-2-current-docs-no-findings.sh` | A doc-relevant change accompanied by a correct doc update reports no findings |
| `test-3-diffs-against-base-ref.sh` | The check is scoped to the diff against the supplied base ref, not the repo's overall current state regardless of ref |
| `test-4-reference-following.sh` | Doc scope expands to files CLAUDE.md/README.md reference, not just those two files themselves |

## Adding new tests

Same process as `tests/guideline-check/README.md`'s "Adding new tests" —
create `test-N-<behavior>.sh`, `chmod +x` it, source `../test-helpers.sh`,
use `new_scratch_repo`, use the JSON-based dispatch-proving assertions (not
plain `run_claude` + `assert_contains`), accumulate a `FAILURES` counter.
Picked up automatically by `run-all.sh`'s glob.

## Notes

- Subagent dispatch has more overhead than a plain skill invocation —
  `run_claude_json` calls here pass an explicit 120s timeout, and
  `test-3-diffs-against-base-ref.sh` dispatches twice in one file, so
  `run-all.sh`'s own per-file budget is 300s (vs. `tests/guideline-check/`'s
  240s).
- Deterministic assertions (specific file/path names, empty-findings checks)
  are preferred over asserting on the model's exact wording, same as
  `tests/guideline-check/`.
```

- [ ] **Step 6: Add `assert_subagent_empty_findings` to the shared test helpers**

In `tests/test-helpers.sh`, add this function immediately after `assert_subagent_used_tool`:

```bash
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
```

- [ ] **Step 7: Make the test scripts executable**

```bash
chmod +x tests/keeping-docs-current/test-1-stale-docs-reported.sh
chmod +x tests/keeping-docs-current/test-2-current-docs-no-findings.sh
chmod +x tests/keeping-docs-current/test-3-diffs-against-base-ref.sh
chmod +x tests/keeping-docs-current/test-4-reference-following.sh
chmod +x tests/keeping-docs-current/run-all.sh
```

- [ ] **Step 8: Run the tests and confirm they fail**

Run: `tests/keeping-docs-current/run-all.sh --verbose`
Expected: FAIL on all four tests — `skills/keeping-docs-current/SKILL.md` doesn't exist yet, so there's no such skill for Claude to use; the main model will report it can't find/use that skill (or answer without dispatching `guideline-check` at all), and `assert_subagent_dispatched` will fail.

- [ ] **Step 9: Implement the skill**

Create `skills/keeping-docs-current/SKILL.md`:

```markdown
---
name: keeping-docs-current
description: Use when checking whether CLAUDE.md, README.md, or any docs they reference are stale relative to a branch's diff against a given base ref. Dispatches the shared guideline-check subagent to do the actual analysis and reports what it finds — never edits docs itself. Needs a base ref supplied by the caller; does not auto-detect one.
---

# keeping-docs-current

Checks whether this project's documentation — starting at `CLAUDE.md` and
`README.md`, following whatever they reference — still matches the code,
relative to a base ref you're given. You never read the diff or the docs
yourself and never edit anything: you dispatch the shared `guideline-check`
subagent to do the actual analysis, then relay what it reports.

## What you need before you can run

A base ref to diff against (e.g. `main`, a commit SHA) — supplied by
whoever invoked you, as part of the request (e.g. "check docs against
main"). Never auto-detect one yourself, and never default to something
like `HEAD~1` if none was given — ask for one instead. (Auto-detecting the
base ref is `before-pr-checks`'s job, not this skill's.)

## What you do

1. Use the `Agent` tool with `subagent_type: "guideline-check"`, passing
   this prompt verbatim, with `<BASE_REF>` replaced by the ref you were
   given:

   ```
   Check whether this repository's documentation is stale relative to the
   changes between <BASE_REF> and the current working tree.

   Doc scope: start with CLAUDE.md and README.md. If either references
   other doc files (links, "see X.md" mentions, a docs/ folder), follow
   those references too, using your own Read/Grep/Glob — don't wait to be
   told where they are.

   What counts as stale:
   - A path or file the docs mention that no longer exists
   - A count or list the docs state that no longer matches reality
   - Described behavior that no longer matches what the code does
   - A doc referencing another doc file that's been deleted or moved

   Use Bash to run git diff/git log against <BASE_REF> to see what
   changed, scoped to that diff — don't flag pre-existing staleness the
   diff doesn't touch. If <BASE_REF> is invalid or the diff command
   fails, report that as an error in your final message rather than an
   empty findings list.

   Report via ReportFindings. For each finding:
   - file: the stale doc's path
   - summary: one-line staleness claim
   - failure_scenario: what changed in the code vs. what the doc still
     claims (a drift description, not a crash scenario)
   - category: "doc-staleness"

   If nothing is stale, call ReportFindings with an empty findings list.
   ```

2. Relay the subagent's final-message determination back to whoever
   invoked you, as reported — don't add your own judgment about whether
   the docs are actually stale, and don't edit any files yourself.
```

- [ ] **Step 10: Run the tests and confirm they pass**

Run: `tests/keeping-docs-current/run-all.sh --verbose`
Expected: `STATUS: PASSED`, all four tests `[PASS]`.

- [ ] **Step 11: Commit**

```bash
git add skills/keeping-docs-current/ tests/keeping-docs-current/ tests/test-helpers.sh
git commit -m "Add keeping-docs-current guideline skill

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: Documentation updates and version bump

**Files:**
- Modify: `skills/using-dotbubl/SKILL.md` (Skill Priority section)
- Modify: `README.md` (new subsection + Structure listing)
- Modify: `.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- No change: `CLAUDE.md` (confirmed unaffected — see Step 2)

**Interfaces:**
- Consumes: the existence of `skills/keeping-docs-current/SKILL.md` and `tests/keeping-docs-current/` from Task 1 (referenced by path in the doc updates below; no code dependency).
- Produces: nothing consumed by later tasks — this plan ends here.

- [ ] **Step 1: Update using-dotbubl's Skill Priority section**

In `skills/using-dotbubl/SKILL.md`, replace:

```
## Skill Priority

This toolkit is still small — there are two skills so far: this one
(`using-dotbubl`) and `backlog`. `backlog` is standalone and independently
triggered, with no ordering relationship to this skill or anything else —
nothing to sequence yet. As more dotbubl skills are added, document their
priority order here (e.g. which process skill runs before which
implementation skill).
```

with:

```
## Skill Priority

This toolkit is still small — there are three skills so far: this one
(`using-dotbubl`), `backlog`, and `keeping-docs-current`. All three are
standalone and independently triggered, with no ordering relationship
between them — `keeping-docs-current` needs a base ref supplied by whoever
invokes it (a human today; the `before-pr-checks` orchestrator once it
exists), but that's an input requirement, not a sequencing relationship
with another skill. As more dotbubl skills are added, document their
priority order here (e.g. which process skill runs before which
implementation skill).
```

- [ ] **Step 2: Confirm CLAUDE.md's Repo layout section still matches**

Read `CLAUDE.md`'s "Repo layout" section. It currently describes
`skills/<name>/SKILL.md` generically ("one skill per directory") without
enumerating skills by name — confirm this line is still accurate:

```
skills/<name>/SKILL.md      one skill per directory; using-dotbubl is the meta-skill
                            (see its own "Skill Priority" section when adding another)
```

Since it names no individual skills besides the meta-skill, adding
`keeping-docs-current` requires no edit here. Make no change to this file.

- [ ] **Step 3: Add a keeping-docs-current subsection to README.md**

In `README.md`, `backlog` gets its own subsection under "What you get,"
and the file states "More skills land here over time; each new one gets
the same treatment." Follow that pattern. Replace:

```
Every item requires a title, type (`bug` / `feature` / `enhancement` /
`regression` / `chore` / `docs` / `spike`), priority (`P0`–`P3`),
description, and acceptance criteria — Claude always asks for anything
missing or vague rather than guessing or writing a placeholder.

More skills land here over time; each new one gets the same treatment —
checked automatically, no need to memorize a command.
```

with:

```
Every item requires a title, type (`bug` / `feature` / `enhancement` /
`regression` / `chore` / `docs` / `spike`), priority (`P0`–`P3`),
description, and acceptance criteria — Claude always asks for anything
missing or vague rather than guessing or writing a placeholder.

### `keeping-docs-current` — checks whether your docs still match the code

Given a base ref to diff against, checks whether `CLAUDE.md`, `README.md`,
and anything they reference are stale relative to what changed —
dispatches a read-only analysis and reports findings, it never edits a doc
itself.

```
You:     Check whether the docs are stale against main.
Claude:  README.md still references docs/setup.md, which was removed on
         this branch. No other issues found.
```

Needs a base ref — provide one explicitly (a branch name, `main`, a commit
SHA) when asking; it won't guess one. Usable standalone today; once the
`before-pr-checks` guideline lands, that ref gets supplied automatically as
part of a before-PR check instead.

More skills land here over time; each new one gets the same treatment —
checked automatically, no need to memorize a command.
```

Then, still in `README.md`, update the `skills/` listing under
"Structure." Replace:

```
skills/
  using-dotbubl/     # meta-skill: enforces checking/using skills before acting
  backlog/           # per-project backlog of todos/ideas
```

with:

```
skills/
  using-dotbubl/     # meta-skill: enforces checking/using skills before acting
  backlog/           # per-project backlog of todos/ideas
  keeping-docs-current/  # checks CLAUDE.md/README.md/referenced docs for staleness against a base ref
```

- [ ] **Step 4: Bump the version**

In `.claude-plugin/plugin.json`, change `"version": "0.3.0"` to `"version": "0.4.0"`.

In `.claude-plugin/marketplace.json`, change the nested `"plugins"[0]."version": "0.3.0"` to `"version": "0.4.0"`.

- [ ] **Step 5: Validate**

Run: `claude plugin validate .`
Expected: passes with no structural errors.

- [ ] **Step 6: Commit**

```bash
git add skills/using-dotbubl/SKILL.md README.md .claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "Update docs and bump version for keeping-docs-current skill

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```
