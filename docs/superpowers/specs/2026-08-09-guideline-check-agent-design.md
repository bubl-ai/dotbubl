# Shared read-only guideline-check subagent — design

Date: 2026-08-09
Status: proposed
Backlog: #1 (`backlog/0001-shared-read-only-guideline-check.md`)

## Problem

`dotbubl` wants a "before-PR checks" feature: a set of independent guideline
checks (starting with documentation staleness, then code-review reuse and a
changelog check) that fan out in parallel just before a PR ships. Parallel
subagents that can write are unsafe — two subagents editing the same file
around the same time can silently clobber each other, and concurrent
`git add`/`git commit` calls can race into a bad commit. Nothing else in that
feature (the `keeping-docs-current` guideline, #2; the `before-pr-checks`
orchestrator, #3) can be built until there's a subagent type that makes
concurrent writes structurally impossible rather than just prompted against.
This spec covers only that piece.

## Scope

One new file, `agents/guideline-check.md` — a custom Claude Code subagent
definition, invocable via the `Agent` tool with `subagent_type:
"guideline-check"`. Plus its tests (`tests/guideline-check/`) and the
repo-doc updates needed to reflect a first `agents/` entry existing. Out of
scope: the `keeping-docs-current` guideline itself (#2), the
`before-pr-checks` orchestrator and its dispatch list (#3), and the
code-review/changelog guidelines (#4, #5) — each gets its own spec when its
turn comes, building against the interface fixed here.

## Design

### Agent definition

```yaml
---
name: guideline-check
description: Use when a dotbubl guideline skill (before-PR checks) needs
  read-only analysis of the working tree or a branch diff, reporting
  results via ReportFindings. Shared by every guideline skill —
  structurally cannot edit files, so parallel guideline runs never
  conflict.
tools: Read, Grep, Glob, Bash, ReportFindings
model: inherit
---
```

- **`tools` is an explicit allow-list**, not a `disallowedTools` exclusion —
  safer than trying to enumerate everything to exclude, and self-documenting
  about exactly what this agent can touch. No `Edit`/`Write`/`NotebookEdit`,
  ever, regardless of what a dispatch prompt asks for.
- **`model: inherit`** is the file's only default, and carries no cost/speed
  policy. Which model an actual dispatch uses is decided by the caller: for
  guidelines run through `before-pr-checks` (#3), that's a `model` value on
  that guideline's row in the orchestrator's dispatch list; a caller that
  doesn't specify one gets `inherit`. This file never needs to change to
  adjust that.
- **Body/instructions** frame the agent generically — a reusable analysis
  agent for dotbubl guideline checks, not tied to documentation specifically
  (`keeping-docs-current` is only its first consumer). It:
  1. Performs whatever read-only inspection its dispatch prompt describes,
     using `Read`/`Grep`/`Glob`/`Bash`.
  2. Always concludes by calling `ReportFindings` — an empty list if nothing
     is wrong, a severity-ranked list of findings otherwise.
  3. Never attempts to fix, edit, or write anything itself, even if a
     dispatch prompt asks it to — that's the orchestrator's job (#3), after
     collecting every guideline's findings and getting user approval.

### Context contract (what every dispatcher must supply)

A dispatch prompt to this agent is expected to contain, and only needs to
contain:
1. **The guideline's own narrow task description** — what to look for and
   why (e.g. "check CLAUDE.md/README.md and anything they reference for
   staleness against this diff").
2. **A base ref to diff against** (e.g. `main`) — not a precomputed diff.
   The agent has `Bash`, so it runs its own `git diff`/`git log` against
   that ref, scoped to what its guideline actually cares about, rather than
   every dispatch parsing one shared, undifferentiated blob.
3. **Guideline-specific pointers it can't discover on its own**, where they
   exist (e.g. `keeping-docs-current` already knows to start at
   CLAUDE.md/README.md; a future changelog guideline would need to be told
   where `CHANGELOG.md` lives and its entry format).

It explicitly does **not** receive: other guidelines' findings (each
instance runs independently; merging happens only after all report back),
the main conversation's history (subagents spawn cold regardless), or a
precomputed intent/changeset summary (considered and dropped — each
guideline's own diff scoping is enough; a shared pre-analysis step added
complexity with no concrete consumer).

## Testing

`tests/guideline-check/`, mirroring `tests/backlog/`'s established shape
(shared `tests/test-helpers.sh`, `run-all.sh`, `README.md`):

- **`test-1-reports-findings-shape.sh`** — dispatch the agent with a
  trivial, verifiable inspection prompt; assert the run produces a
  `ReportFindings`-shaped result.
- **`test-2-no-filesystem-writes.sh`** — dispatch it with a prompt that
  *tries* to get it to write or edit something; assert the test workspace's
  `git status` is unchanged afterward. This is the test that actually
  proves the restriction is structural (no tool available) rather than
  merely a prompted promise the model could be talked out of.

This is the first agent added to the repo, so it's also the first time
`tests/<name>/` covers something other than a skill — see Documentation
updates below.

## Documentation updates (same PR)

- **CLAUDE.md Repo layout** — `agents/` currently reads "don't exist yet";
  update once this file lands.
- **CLAUDE.md Testing convention** — broaden "every skill that ships
  verifiable behavior gets committed, runnable tests under
  `tests/<skill-name>/`" to cover agents too (`tests/<skill-or-agent-name>/`).
- **`docs/testing.md`** — same generalization wherever it currently says
  "skill" specifically for the directory convention.
- **README.md** — confirm its existing `agents under agents/` mention still
  matches now that the directory is real, per CLAUDE.md's "Documentation
  stays current" rule.

## Out of scope / deferred to later specs

- `keeping-docs-current` (#2): the first real consumer, and the first
  concrete exercise of the context contract above.
- `before-pr-checks` (#3): the dispatch list, base-ref auto-detection, and
  findings-merge/apply logic all live there, not here.
- The changelog guideline (#5): dispatches onto this same agent, once #3
  exists to invoke it.
- Code-review reuse (#4): doesn't dispatch onto this agent at all — it
  invokes the existing `/code-review` skill directly as a separate
  dispatch-list entry in #3, included here only because #3's design
  documents both mechanisms merging findings uniformly.
