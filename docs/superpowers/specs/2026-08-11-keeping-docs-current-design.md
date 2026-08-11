# keeping-docs-current guideline skill — design

Date: 2026-08-11
Status: proposed
Backlog: #2 (`backlog/0002-keeping-docs-current-guideline-skill.md`)

## Problem

`dotbubl` wants a "before-PR checks" feature whose first concrete guideline
is documentation staleness: does a branch's diff leave `CLAUDE.md`,
`README.md`, or anything they reference describing behavior that no longer
matches the code? The shared `guideline-check` subagent (#1, merged in
PR #8) provides the read-only analysis primitive every guideline reuses, but
it's generic — it has no built-in notion of what "documentation staleness"
means or where to look. This spec covers the skill that supplies that:
`keeping-docs-current`.

## Scope

One new file, `skills/keeping-docs-current/SKILL.md`, plus its tests
(`tests/keeping-docs-current/`) and the doc updates that follow from adding
a second dotbubl skill (`using-dotbubl`'s Skill Priority section). Out of
scope: the `before-pr-checks` orchestrator and its dispatch list (#3),
base-ref auto-detection (explicitly #3's job, not this skill's — see
Decisions below), and the code-review/changelog guidelines (#4, #5).

## Decisions

Three questions were resolved during brainstorming, each worth recording
because the obvious-looking alternative was considered and rejected:

**Base ref comes from the caller; this skill never auto-detects one.**
#3's own backlog item already commits to owning base-ref auto-detection
(`origin/HEAD` or the current branch's upstream) exactly once, so every
dispatched guideline gets it the same way. If `keeping-docs-current`
duplicated that detection, every future guideline (#5's changelog check,
and whatever comes after) would need to reimplement it too, and #3 would
either have to override a self-detected ref (dead code) or trust two
independent computations to agree forever. The cost today — invoking this
skill standalone means naming a ref explicitly rather than it being
inferred — is temporary and disappears once #3 exists to supply it.

**Doc-scope discovery happens inside the `guideline-check` dispatch, not
before it.** The skill hands `guideline-check` a starting point
(`CLAUDE.md`, `README.md`) and instructions to follow references itself,
using its own `Read`/`Grep`/`Glob` — one dispatch does discovery, diffing,
and the staleness judgment together. The alternative (this skill pre-walks
references and hands `guideline-check` a finished file list) would
duplicate that walk in two places and adds a parent-context Read/Grep step
that the subagent model already exists to absorb.

**This skill is self-contained, not a special-cased fragment for #3 to
inline.** `keeping-docs-current` is a normal, standalone `SKILL.md`,
runnable on its own today. When #3 is built, its dispatch-list entry for
this guideline invokes it the same way #4's entry invokes `/code-review` —
"an existing skill" is already a first-class dispatch mechanism in #3's own
design, so #2 doesn't need to expose a separately packaged prompt fragment
in anticipation of a consumer that isn't built yet.

**Mechanics note (not a decision, a clarification):** a skill is not an
independent actor. `Skill(keeping-docs-current)` loads this file's
instructions into whichever context invoked it — a person's session today,
or #3's own context later — and that context is the one that then calls
`Agent` with `subagent_type: "dotbubl:guideline-check"`. "The skill
dispatches the agent" and "before-pr-checks invokes the agent using the
skill as its prompt" describe the same mechanism from two vantage points.

## Design

### Skill definition

`skills/keeping-docs-current/SKILL.md`, structurally identical in shape to
`skills/backlog/SKILL.md` (frontmatter + prose instructions, no code). Its
instructions tell whichever context loads it to:

1. Take the base ref supplied in the invocation (e.g. "check docs against
   `main`") — no fallback, no auto-detection.
2. Call `Agent` with `subagent_type: "dotbubl:guideline-check"`, passing a
   prompt built from the fixed concern template below plus that base ref.
3. Relay `guideline-check`'s final-message determination back to whoever
   invoked the skill, unmodified — this skill does no independent judgment
   of its own.

### Concern template (the dispatch prompt's content)

Drawn directly from language already in this repo's `CLAUDE.md`
("Documentation stays current" section) rather than invented fresh:

- **Doc scope:** start at `CLAUDE.md` and `README.md`; follow whatever they
  reference (links, "see X.md" mentions, a `docs/` folder) using judgment,
  not a config file of tracked docs.
- **What counts as stale:** paths/files mentioned that no longer exist,
  counts or lists that no longer match reality, described behavior that no
  longer matches what the code does.
- **Base ref:** whatever this dispatch was given.

### Findings mapping onto `ReportFindings`

`guideline-check`'s tool allow-list is fixed to `ReportFindings` (#1), whose
fields are shaped for code-review findings — not something this skill can
change. The concern template tells the subagent how to map doc-staleness
findings onto those fields explicitly, rather than leaving it to guess:

| `ReportFindings` field | Doc-staleness meaning |
|---|---|
| `file` | the stale doc's path (e.g. `README.md`) |
| `summary` | one-line staleness claim (e.g. "README still documents the removed `--legacy` flag") |
| `failure_scenario` | repurposed: what changed in code vs. what the doc still claims — a drift description, not a crash scenario |
| `category` | `"doc-staleness"` |

On a clean branch, `guideline-check` calls `ReportFindings` with an empty
list — same "no findings" contract as any other use of the agent.

### Error handling

- **Invalid/nonexistent base ref:** the subagent's `git diff`/`git log`
  fails; the concern template requires that failure be surfaced as an error
  in the final message, never silently reported as "no findings."
- **No `CLAUDE.md`/`README.md` in the target repo:** not an error —
  legitimately nothing to check, so `ReportFindings` returns empty.
- **A referenced doc file is missing** (e.g. `CLAUDE.md` links to a
  deleted `docs/` file): this is itself a staleness finding — a doc
  referencing a doc that no longer exists — reported, not skipped.

## Testing

`tests/keeping-docs-current/`, mirroring `tests/guideline-check/`'s shape
(shared `tests/test-helpers.sh`, `run-all.sh`, `README.md`), using
`run_claude_json` + `assert_subagent_dispatched`/`assert_subagent_used_tool`
to prove real dispatch rather than relayed text:

- **`test-1-stale-docs-reported.sh`** — scratch repo: a base commit with
  `CLAUDE.md`/`README.md` describing some behavior, a second commit that
  changes that behavior without touching the docs. Invoke the skill with
  the base commit as ref; assert `dotbubl:guideline-check` was dispatched,
  `ReportFindings` was called, and the reported content names the actual
  stale claim.
- **`test-2-current-docs-no-findings.sh`** — same setup, but the second
  commit updates the docs correctly alongside the behavior change; assert
  an empty findings result.
- **`test-3-diffs-against-base-ref.sh`** — mirrors #1's test of the same
  name: confirms the supplied ref is actually used (a case that's stale
  relative to `HEAD~2` but would look clean against `HEAD~1`).
- **`test-4-reference-following.sh`** — `CLAUDE.md` points to a `docs/x.md`
  that goes stale (not `README.md` itself); confirms scope actually expands
  past the two starting files rather than stopping at them.

## Documentation updates (same PR)

- **`skills/using-dotbubl/SKILL.md`'s "Skill Priority" section** — currently
  documents two skills (`using-dotbubl`, `backlog`) with "nothing to
  sequence yet." Update to reflect a third, and note its relationship (or
  lack of one) to the existing two — `keeping-docs-current` is independently
  triggered by a human/orchestrator supplying a base ref, not sequenced
  relative to `backlog`.
- **CLAUDE.md Repo layout** — confirm the `skills/<name>/` line still
  matches now that a second, non-meta skill exists alongside
  `using-dotbubl`.
- **README.md** — confirm its skills listing/description still matches,
  per CLAUDE.md's "Documentation stays current" rule.

## Out of scope / deferred to later specs

- `before-pr-checks` (#3): the dispatch list, base-ref auto-detection, and
  findings-merge/apply logic all live there — this skill only needs to be
  correctly invocable by it later, not to anticipate its shape.
- The changelog guideline (#5): a separate skill following the same
  "propose, don't write" pattern against `guideline-check`, once its own
  turn comes.
- Code-review reuse (#4): doesn't touch this skill at all — invokes
  `/code-review` directly as a separate dispatch-list entry in #3.
