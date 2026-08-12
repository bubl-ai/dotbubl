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
