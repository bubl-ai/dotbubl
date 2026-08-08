# backlog skill tests

Automated tests for the `backlog` skill, modeled on
[obra/superpowers](https://github.com/obra/superpowers)'
`tests/claude-code/` conventions. See `docs/testing.md` at the repo root
for how this fits into the project's overall testing approach.

## Overview

Each test invokes Claude Code in headless mode (`claude -p`) against a
disposable scratch git repo, pointed at this repo's in-progress
`--plugin-dir` (not an installed copy — see `test-helpers.sh` for why that
matters here), and verifies the skill's actual behavior: files written or
not written, with the right content, in the right order.

## Requirements

- Claude Code CLI installed and in PATH (`claude --version` should work)
- No plugin installation needed — tests point `--plugin-dir` at this repo
  directly

## Running tests

```bash
./run-all.sh                          # all tests
./run-all.sh --verbose                # full output, not just pass/fail
./run-all.sh --test test-2-explicit-ask.sh   # one test
./run-all.sh --timeout 180            # override the per-test timeout
```

Exit code 0 = all passed, non-zero = at least one failed.

## Test structure

### ../test-helpers.sh

**Lives one level up, at `tests/test-helpers.sh`** — shared across every
skill's tests, not copied per skill (matches superpowers: all of
`tests/claude-code/*.sh` source one `test-helpers.sh`, not one each).
Sourced (not run) by every test file here:
- `run_claude "prompt" [timeout_seconds] [--continue]` — invoke Claude
  against this repo's plugin content
- `assert_contains` / `assert_not_contains` / `assert_order` — check
  conversational output
- `assert_file_exists` / `assert_no_file` / `assert_frontmatter` — check
  the actual files the skill wrote or didn't write
- `new_scratch_repo` — fresh `git init`'d temp dir, auto-cleaned on exit

If you're adding a test for a *different* skill, source this same file
(`"$SCRIPT_DIR/../test-helpers.sh"` from `tests/<that-skill>/`) rather than
copying it — extend it there if you need a new generic assertion.

### Test files

Each `test-N-<behavior>.sh`:
1. Sources `../test-helpers.sh`
2. Sets up a scratch repo (and fixture files, if the scenario needs
   existing backlog items)
3. Runs one or two `run_claude` turns
4. Asserts on output and/or files, accumulating failures rather than
   stopping at the first one
5. Exits 0 on success, 1 if any assertion failed

## Current tests

| File | Verifies |
|------|----------|
| `test-1-query.sh` | Querying sorts items by priority (P0 first) |
| `test-2-explicit-ask.sh` | Explicit-ask creation confirms before writing, writes a complete item |
| `test-3-deferred-task.sh` | Deferred-task creation confirms before writing, writes a complete item |
| `test-4-completion.sh` | Completion confirms before deleting |
| `test-5-required-fields.sh` | Missing required fields (priority/description/acceptance criteria) block the write, prompting instead |

## Adding new tests

1. Create `test-N-<behavior>.sh`, `chmod +x` it
2. Source `../test-helpers.sh`, use `new_scratch_repo` for setup
3. Use the `assert_*` helpers; accumulate a `FAILURES` counter rather than
   exiting on the first failed assertion (see any existing test for the
   pattern)
4. It's picked up automatically by `run-all.sh`'s glob — no registration
   step needed (unlike superpowers' explicit test array, since we don't yet
   have a fast/slow split worth maintaining separately)

## Notes

- Tests verify the skill's *behavior*, not its literal wording — assertions
  check for files and key facts (id, type, priority, tags), not exact
  phrasing, since the model's exact prose varies between runs.
- Keep tests deterministic where the behavior is deterministic (file
  presence/absence, frontmatter values) and avoid asserting on wording that
  could reasonably vary.
- `run_claude` needs `--permission-mode acceptEdits` under the hood for any
  scenario that writes or deletes a file — see the comment in
  `test-helpers.sh` for why, if you're extending it.
