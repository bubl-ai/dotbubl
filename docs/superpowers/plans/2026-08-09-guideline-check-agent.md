# Guideline-check shared subagent — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `agents/guideline-check.md`, a reusable read-only subagent for dotbubl's before-PR guideline checks, with committed tests and the doc updates that follow from adding the repo's first `agents/` entry.

**Architecture:** A single custom Claude Code subagent definition (`agents/guideline-check.md`) restricted to an explicit tool allow-list (no write tools at all), invocable via the `Agent` tool with `subagent_type: "guideline-check"`. It always concludes by calling `ReportFindings`. Tested the same way `tests/backlog/` tests the backlog skill: real headless `claude -p --plugin-dir` invocations against disposable scratch git repos, asserting on actual output/files rather than internal logic (there is no internal logic to unit-test — the "code" is the prose instructions in the agent file).

**Tech Stack:** Bash test scripts sourcing the repo's shared `tests/test-helpers.sh`; Claude Code custom subagent frontmatter (YAML) in `agents/guideline-check.md`; no other runtime dependencies.

## Global Constraints

- `agents/guideline-check.md`'s `tools` field must be exactly the allow-list `Read, Grep, Glob, Bash, ReportFindings` — never `Edit`, `Write`, or `NotebookEdit`, and never a `disallowedTools` exclusion list instead.
- `model: inherit` in the frontmatter — no other default model, no cost/model policy baked into this file.
- Tests live at `tests/guideline-check/`, mirroring `tests/backlog/`'s shape exactly: `test-N-<behavior>.sh` files, `run-all.sh`, `README.md`, sourcing the shared `tests/test-helpers.sh` (never copied per-directory).
- Every test file accumulates failures in a `FAILURES` counter and exits non-zero only at the end, rather than stopping at the first failed assertion (existing repo convention — see any `tests/backlog/test-*.sh`).
- Tests must be actually run (not just claimed to pass) before the task's commit, per `CLAUDE.md`'s Testing convention.
- Version must be bumped identically in both `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (`plugins[0].version`) — installed copies only notice an update when the version actually changes.
- Every commit message ends with `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`.
- Fix documentation drift in the same commit as the change that causes it — never as a follow-up (`CLAUDE.md`'s "Documentation stays current").

---

### Task 1: `agents/guideline-check.md` with tests (TDD)

**Files:**
- Create: `tests/guideline-check/test-1-reports-findings-shape.sh`
- Create: `tests/guideline-check/test-2-no-filesystem-writes.sh`
- Create: `tests/guideline-check/run-all.sh`
- Create: `tests/guideline-check/README.md`
- Create: `agents/guideline-check.md`

**Interfaces:**
- Consumes: `tests/test-helpers.sh`'s `run_claude`, `assert_contains`, `assert_no_file`, `new_scratch_repo` (all already defined and exported at repo root — see `tests/test-helpers.sh`).
- Produces: a custom subagent with frontmatter `name: guideline-check`, `tools: Read, Grep, Glob, Bash, ReportFindings`, `model: inherit`, invocable by any later skill or test via the `Agent` tool as `subagent_type: "guideline-check"`. No other task in this plan calls into it programmatically, but backlog items #2/#5 (out of scope here) will dispatch it the same way these tests do.

- [ ] **Step 1: Write the failing test — reports findings**

Create `tests/guideline-check/test-1-reports-findings-shape.sh`:

```bash
#!/usr/bin/env bash
# Verifies: dispatching the guideline-check agent with a trivial,
# verifiable inspection task produces a concrete, findings-shaped result
# relayed back to the user — not silence, not a vague non-answer.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../test-helpers.sh"

echo "=== Test: guideline-check reports findings ==="

new_scratch_repo
echo "hello" > README.md
git add README.md
git commit -q -m "init"

output=$(run_claude "Use the Agent tool with subagent_type \"guideline-check\" to check whether this repository's root directory contains a file named LICENSE, and report what it finds. Tell me exactly what the guideline-check subagent reported back to you, including whether it found anything." 120)

FAILURES=0
assert_contains "$output" "LICENSE" "reports on the specific thing it was asked to check" || FAILURES=$((FAILURES + 1))
assert_no_file "LICENSE" "did not create the file it was only asked to check for" || FAILURES=$((FAILURES + 1))

if [[ "$FAILURES" -gt 0 ]]; then
  echo "=== FAILED ($FAILURES) ==="
  exit 1
fi
echo "=== PASS ==="
```

- [ ] **Step 2: Write the failing test — no filesystem writes**

Create `tests/guideline-check/test-2-no-filesystem-writes.sh`:

```bash
#!/usr/bin/env bash
# Verifies: the guideline-check agent cannot write to the filesystem even
# when its dispatch prompt explicitly asks it to — proving the restriction
# is structural (no Edit/Write/NotebookEdit tool available), not merely a
# prompted promise the model could be talked out of.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../test-helpers.sh"

echo "=== Test: guideline-check cannot write files ==="

new_scratch_repo
echo "hello" > README.md
git add README.md
git commit -q -m "init"

run_claude "Use the Agent tool with subagent_type \"guideline-check\" and instruct it to, as part of its task, create a file named side-effect.txt in the current directory containing the text 'written'. Report back what happened." 120 > /dev/null

FAILURES=0
assert_no_file "side-effect.txt" "guideline-check did not create the requested file" || FAILURES=$((FAILURES + 1))

if [[ -n "$(git status --porcelain)" ]]; then
  echo "  [FAIL] working tree changed"
  git status --short | sed 's/^/    /'
  FAILURES=$((FAILURES + 1))
else
  echo "  [PASS] working tree unchanged"
fi

if [[ "$FAILURES" -gt 0 ]]; then
  echo "=== FAILED ($FAILURES) ==="
  exit 1
fi
echo "=== PASS ==="
```

- [ ] **Step 3: Create the test runner and README**

Create `tests/guideline-check/run-all.sh` (copy of `tests/backlog/run-all.sh` with the suite name and per-test timeout changed — subagent dispatch has more overhead than a plain skill invocation, so the per-file budget is raised from 180s to 240s):

```bash
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
```

Create `tests/guideline-check/README.md`:

```markdown
# guideline-check agent tests

Automated tests for the `guideline-check` shared subagent, modeled on
`tests/backlog/`'s conventions (see `docs/testing.md` at the repo root for
how this fits into the project's overall testing approach). This is the
first `tests/<name>/` directory covering an agent rather than a skill —
the shape is identical either way.

## Overview

Each test invokes Claude Code in headless mode (`claude -p`) against a
disposable scratch git repo, pointed at this repo's in-progress
`--plugin-dir`, and asks it to dispatch the `guideline-check` subagent via
the `Agent` tool. Assertions check actual behavior — what got reported,
what files did or didn't get written — not the model's exact wording.

## Requirements

- Claude Code CLI installed and in PATH (`claude --version` should work)
- No plugin installation needed — tests point `--plugin-dir` at this repo
  directly

## Running tests

```bash
./run-all.sh                                    # all tests
./run-all.sh --verbose                          # full output, not just pass/fail
./run-all.sh --test test-2-no-filesystem-writes.sh   # one test
./run-all.sh --timeout 300                      # override the per-test timeout
```

Exit code 0 = all passed, non-zero = at least one failed.

## Test structure

### ../test-helpers.sh

Shared across every skill's and agent's tests — see `tests/backlog/README.md`
for the full rundown of what it provides (`run_claude`, `assert_*`,
`new_scratch_repo`). Sourced here the same way: `"$SCRIPT_DIR/../test-helpers.sh"`.

### Test files

Each `test-N-<behavior>.sh`:
1. Sources `../test-helpers.sh`
2. Sets up a scratch repo
3. Runs one `run_claude` turn that asks the main model to dispatch
   `subagent_type: "guideline-check"` for a specific, verifiable task
4. Asserts on output and/or files, accumulating failures rather than
   stopping at the first one
5. Exits 0 on success, 1 if any assertion failed

## Current tests

| File | Verifies |
|------|----------|
| `test-1-reports-findings-shape.sh` | A trivial inspection task produces a concrete, findings-shaped result, with no incidental file writes |
| `test-2-no-filesystem-writes.sh` | The agent cannot write a file even when its dispatch prompt explicitly asks it to — the restriction is structural, not prompted |

## Adding new tests

Same process as `tests/backlog/README.md`'s "Adding new tests" section —
create `test-N-<behavior>.sh`, `chmod +x` it, source `../test-helpers.sh`,
use `new_scratch_repo`, accumulate a `FAILURES` counter. Picked up
automatically by `run-all.sh`'s glob.

## Notes

- Subagent dispatch has more overhead than a plain skill invocation —
  `run_claude` calls here pass an explicit 120s timeout (vs. the 60s
  default) and `run-all.sh`'s own per-file budget is 240s (vs.
  `tests/backlog/`'s 180s).
- Deterministic assertions (file presence/absence, `git status`) are
  preferred over asserting on the model's exact wording, same as
  `tests/backlog/`.
```

- [ ] **Step 4: Make the test scripts executable**

```bash
chmod +x tests/guideline-check/test-1-reports-findings-shape.sh
chmod +x tests/guideline-check/test-2-no-filesystem-writes.sh
chmod +x tests/guideline-check/run-all.sh
```

- [ ] **Step 5: Run the tests and confirm they fail**

Run: `tests/guideline-check/run-all.sh --verbose`
Expected: FAIL on both tests — `agents/guideline-check.md` doesn't exist yet, so there is no `guideline-check` subagent type for the `Agent` tool to dispatch; the main model will report it can't find/use that subagent type, `assert_contains "$output" "LICENSE"` and/or the file assertions will fail.

- [ ] **Step 6: Implement the agent**

Create `agents/guideline-check.md`:

```markdown
---
name: guideline-check
description: Use when a dotbubl guideline skill (before-PR checks) needs read-only analysis of the working tree or a branch diff, reporting results via ReportFindings. Shared by every guideline skill — structurally cannot edit files, so parallel guideline runs never conflict.
tools: Read, Grep, Glob, Bash, ReportFindings
model: inherit
---

# guideline-check

You are a read-only analysis agent shared by every dotbubl "before-PR
checks" guideline (documentation staleness, code review, changelog, and
whatever's added later). You have no `Edit`, `Write`, or `NotebookEdit`
tool — that isn't a suggestion, it's the actual mechanism that keeps
parallel guideline runs from ever conflicting: nothing you do can race
another instance of this same agent running alongside you, because
neither of you can write.

## What you receive

Whoever dispatches you supplies, in your task prompt:
- The specific guideline's concern — what to look for and why.
- A base ref to diff against (e.g. `main`) — not a precomputed diff. Use
  `Bash` to run your own `git diff`/`git log` against it, scoped to what
  your guideline actually needs.
- Any guideline-specific pointers you can't discover yourself (e.g. where
  a relevant file lives, or a format convention to check against).

## What you do

1. Inspect using `Read`, `Grep`, `Glob`, and `Bash` only.
2. Decide what, if anything, is wrong.
3. Call `ReportFindings` exactly once to conclude — an empty findings list
   if everything checks out, a populated and severity-ranked list
   otherwise.

## What you never do

Never attempt to fix, edit, or write anything yourself, even if your
dispatch prompt explicitly asks you to. You have no tool that could do
this regardless — if asked, report that the requested change is out of
scope for a read-only check rather than attempting a workaround. Applying
approved fixes is the dispatching orchestrator's job, done centrally and
sequentially after every guideline has reported back.
```

- [ ] **Step 7: Run the tests and confirm they pass**

Run: `tests/guideline-check/run-all.sh --verbose`
Expected: `STATUS: PASSED`, both tests `[PASS]`.

- [ ] **Step 8: Commit**

```bash
git add agents/guideline-check.md tests/guideline-check/
git commit -m "Add guideline-check shared read-only subagent

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: Documentation updates and version bump

**Files:**
- Modify: `CLAUDE.md` (Repo layout section, Testing convention section)
- Modify: `docs/testing.md`
- Modify: `README.md` (Structure section)
- Modify: `.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

**Interfaces:**
- Consumes: the existence of `agents/guideline-check.md` and `tests/guideline-check/` from Task 1 (referenced by path in the doc updates below; no code dependency).
- Produces: nothing consumed by later tasks — this plan ends here.

- [ ] **Step 1: Update CLAUDE.md's Repo layout section**

In `CLAUDE.md`, replace:

```
## Repo layout

```
.claude-plugin/             plugin.json + marketplace.json — only files that belong here
skills/<name>/SKILL.md      one skill per directory; using-dotbubl is the meta-skill
                            (see its own "Skill Priority" section when adding another)
hooks/                      hooks.json + hook scripts (session-start injects using-dotbubl
                            as always-on context — plugins have no CLAUDE.md equivalent)
tests/<skill-name>/         committed, runnable tests per skill — see "Testing convention"
docs/testing.md             testing convention in full
docs/superpowers/plans/     committed plan/spec docs from the writing-plans / brainstorming
docs/superpowers/specs/     skills, one per feature, named YYYY-MM-DD-<slug>.md
backlog/                    this repo's own personal backlog — gitignored (see
                            skills/backlog/SKILL.md's note on why: the plugin ships the
                            whole repo root, and backlog items aren't meant to be published)
```

`agents/` (custom subagent definitions) and `.mcp.json` (MCP servers) don't
exist yet but follow the same pattern when added — repo root, never inside
`.claude-plugin/`. `README.md` covers the user-facing shape of this same
layout; keep both in sync when the structure changes, but don't just
duplicate one into the other — README explains what installers get, this
section explains where a contributor edits it.
```

with:

```
## Repo layout

```
.claude-plugin/             plugin.json + marketplace.json — only files that belong here
agents/<name>.md            custom subagent definitions, one file per agent; guideline-check
                            is the first — a shared read-only subagent for before-PR checks
skills/<name>/SKILL.md      one skill per directory; using-dotbubl is the meta-skill
                            (see its own "Skill Priority" section when adding another)
hooks/                      hooks.json + hook scripts (session-start injects using-dotbubl
                            as always-on context — plugins have no CLAUDE.md equivalent)
tests/<skill-or-agent-name>/ committed, runnable tests per skill or agent — see "Testing convention"
docs/testing.md             testing convention in full
docs/superpowers/plans/     committed plan/spec docs from the writing-plans / brainstorming
docs/superpowers/specs/     skills, one per feature, named YYYY-MM-DD-<slug>.md
backlog/                    this repo's own personal backlog — gitignored (see
                            skills/backlog/SKILL.md's note on why: the plugin ships the
                            whole repo root, and backlog items aren't meant to be published)
```

`agents/` now holds custom subagent definitions (`guideline-check` is the
first); `.mcp.json` (MCP servers) doesn't exist yet but follows the same
pattern when added — repo root, never inside `.claude-plugin/`. `README.md`
covers the user-facing shape of this same layout; keep both in sync when
the structure changes, but don't just duplicate one into the other —
README explains what installers get, this section explains where a
contributor edits it.
```

- [ ] **Step 2: Update CLAUDE.md's Testing convention section**

In `CLAUDE.md`, replace:

```
**Every skill that ships verifiable behavior gets committed, runnable tests
under `tests/<skill-name>/`** — never left as prose-only plan content or
throwaway `/tmp` scripts. `/tmp` files aren't part of the repo, don't
survive a reboot, and can't be re-run by anyone without reverse-engineering
them back out of a plan doc. That already happened once with
`skills/backlog` before being fixed — `tests/backlog/` is the reference
shape for every skill after it:
```

with:

```
**Every skill or agent that ships verifiable behavior gets committed,
runnable tests under `tests/<skill-or-agent-name>/`** — never left as
prose-only plan content or throwaway `/tmp` scripts. `/tmp` files aren't
part of the repo, don't survive a reboot, and can't be re-run by anyone
without reverse-engineering them back out of a plan doc. That already
happened once with `skills/backlog` before being fixed — `tests/backlog/`
is the reference shape for every skill after it, and `tests/guideline-check/`
is the same shape applied to an agent instead of a skill:
```

- [ ] **Step 3: Update docs/testing.md**

In `docs/testing.md`, replace:

```
We have one tier: **`tests/<skill-name>/`** — see `tests/backlog/README.md`
for the concrete structure. It plays the role of superpowers' `tests/`, but
```

with:

```
We have one tier: **`tests/<skill-or-agent-name>/`** — see
`tests/backlog/README.md` (skill) or `tests/guideline-check/README.md`
(agent) for the concrete structure. It plays the role of superpowers'
`tests/`, but
```

And replace:

```
## Writing tests for a new skill

1. Create `tests/<skill-name>/` with `test-N-*.sh` per behavior,
   `run-all.sh`, `README.md` — copy the shape of `tests/backlog/`.
```

with:

```
## Writing tests for a new skill or agent

1. Create `tests/<skill-or-agent-name>/` with `test-N-*.sh` per behavior,
   `run-all.sh`, `README.md` — copy the shape of `tests/backlog/` (skill)
   or `tests/guideline-check/` (agent). The shape is identical either way.
```

- [ ] **Step 4: Update README.md's Structure section**

In `README.md`, replace:

```
## Structure

```
.claude-plugin/
  plugin.json       # plugin manifest
  marketplace.json  # self-hosted marketplace (this repo installs itself)
skills/
  using-dotbubl/     # meta-skill: enforces checking/using skills before acting
  backlog/           # per-project backlog of todos/ideas
hooks/
  hooks.json         # registers the SessionStart hook
  session-start      # injects using-dotbubl as always-on context
tests/               # committed, runnable tests per skill
docs/                # testing convention + design plans/specs
```
```

with:

```
## Structure

```
.claude-plugin/
  plugin.json       # plugin manifest
  marketplace.json  # self-hosted marketplace (this repo installs itself)
agents/
  guideline-check.md  # shared read-only subagent for before-PR guideline checks
skills/
  using-dotbubl/     # meta-skill: enforces checking/using skills before acting
  backlog/           # per-project backlog of todos/ideas
hooks/
  hooks.json         # registers the SessionStart hook
  session-start      # injects using-dotbubl as always-on context
tests/               # committed, runnable tests per skill or agent
docs/                # testing convention + design plans/specs
```
```

- [ ] **Step 5: Bump the version**

In `.claude-plugin/plugin.json`, change `"version": "0.2.2"` to `"version": "0.3.0"`.

In `.claude-plugin/marketplace.json`, change the nested `"plugins"[0]."version": "0.2.2"` to `"version": "0.3.0"`.

- [ ] **Step 6: Validate**

Run: `claude plugin validate .`
Expected: passes with no structural errors (confirms `agents/guideline-check.md`'s frontmatter and the version bump didn't break plugin manifest validity).

- [ ] **Step 7: Commit**

```bash
git add CLAUDE.md docs/testing.md README.md .claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "Update docs and bump version for guideline-check agent

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```
