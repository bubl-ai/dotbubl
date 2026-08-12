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

For subagent testing specifically, this file also provides:
- `run_claude_json`: Runs Claude with `--output-format stream-json --verbose` to 
  capture structured events, including tool and subagent dispatch signals
- `assert_subagent_dispatched`: Verifies that the Agent tool actually dispatched 
  the subagent (by inspecting for `subagent_type` in the JSON stream), not just 
  that the model mentioned it in text
- `assert_subagent_used_tool`: Verifies that the subagent concluded by calling a 
  specific tool (e.g., `ReportFindings`)
- `assert_subagent_empty_findings`: Verifies a subagent called ReportFindings with
  an empty findings array (the "nothing wrong" case)
- `assert_subagent_finding_mentions`: Verifies a subagent's ReportFindings call
  included a finding whose content matches a given pattern, not just that the
  surrounding output text does

Plain `run_claude` output alone can't prove a subagent was actually dispatched — 
the model could answer the question directly without dispatching anything, and 
the relayed text would look identical either way. Structured JSON output is 
required to detect the real tool/subagent dispatch events.

### Test files

Each `test-N-<behavior>.sh`:
1. Sources `../test-helpers.sh`
2. Sets up a scratch repo
3. Runs one `run_claude_json` turn that asks the main model to dispatch
   `subagent_type: "guideline-check"` for a specific, verifiable task —
   note `run_claude_json`, not `run_claude`, because we need structured
   JSON output to prove the subagent was actually dispatched, not just that
   the model answered the question
4. Asserts using:
   - `assert_subagent_dispatched` to verify the Agent tool actually dispatched
     the subagent (checking for `subagent_type` in the JSON stream)
   - `assert_subagent_used_tool` to verify the subagent concluded via its
     expected final tool (e.g., `ReportFindings`)
   - Other file/state assertions like `assert_no_file` as needed
   - Accumulates failures rather than stopping at the first one
5. Exits 0 on success, 1 if any assertion failed

## Current tests

| File | Verifies |
|------|----------|
| `test-1-reports-findings-shape.sh` | A trivial inspection task produces a concrete, findings-shaped result via ReportFindings |
| `test-2-no-filesystem-writes.sh` | The agent does not write when explicitly instructed to via Bash (behavioral restriction, since Edit/Write/NotebookEdit are structurally unavailable) |
| `test-3-diffs-against-base-ref.sh` | The agent's core capability: running `git diff` via Bash to inspect real repository changes, not hallucinated content |

## Adding new tests

Create `test-N-<behavior>.sh`, `chmod +x` it, source `../test-helpers.sh`,
use `new_scratch_repo`, and accumulate a `FAILURES` counter. Picked up
automatically by `run-all.sh`'s glob.

**Important:** This directory tests subagent dispatch, not just skill invocation.
Follow the JSON-based pattern in existing tests — use `run_claude_json` to
capture structured events, then verify dispatch with `assert_subagent_dispatched`
and tool conclusion with `assert_subagent_used_tool`. Plain `run_claude` +
`assert_contains` (as in `tests/backlog/`) will appear to pass without proving
the subagent was actually dispatched, so do not replicate that pattern here.

## Notes

- Subagent dispatch has more overhead than a plain skill invocation —
  `run_claude` calls here pass an explicit 120s timeout (vs. the 60s
  default) and `run-all.sh`'s own per-file budget is 240s (vs.
  `tests/backlog/`'s 180s).
- Deterministic assertions (file presence/absence, `git status`) are
  preferred over asserting on the model's exact wording, same as
  `tests/backlog/`.
