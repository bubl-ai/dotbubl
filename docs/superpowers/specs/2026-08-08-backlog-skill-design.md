# Backlog skill — design

Date: 2026-08-08
Status: approved, pending implementation plan

## Problem

There's currently no consistent way to capture todos/ideas that come up during
a Claude Code session, or tasks that get identified mid-work but deliberately
deferred to a future PR/MR. They either get lost, or clutter the current
conversation/plan. We want a `dotbubl` skill that gives every project a
lightweight, git-native backlog, and lets you ask Claude what's in it and what
to tackle next.

## Scope

One new skill, `backlog` (final name TBD at implementation — see Open
Questions), shipped from the `dotbubl` plugin, usable in any project once
`dotbubl` is installed. Out of scope for v1: a generated index file, a
`related`/cross-reference field beyond tags, multi-project aggregation.

## Location

Backlog items live in the *consuming project*, not inside `dotbubl` itself:
```
<project-root>/backlog/
```
`<project-root>` is the git top-level of whatever repo you're working in
(`git rev-parse --show-toplevel`), so the skill works correctly regardless of
which subdirectory you invoke it from. Each project's backlog is independent
and commits alongside that project's code.

## Storage format

One markdown file per item, no persisted index:
```
backlog/NNNN-slug.md
```
- `NNNN`: sequential id, zero-padded (`0007`), computed by scanning existing
  `backlog/*.md` filenames for the current max and adding 1.
- `slug`: derived from the title — lowercased, punctuation stripped, spaces
  to hyphens, truncated to ~40 characters.

**No index file.** When asked "what's in the backlog," the skill reads
`backlog/*.md` directly and parses frontmatter live — this is a normal file
operation and doesn't need a pre-built summary. An index was considered
(hand-maintained, or skill-generated) and dropped for v1: it only pays off for
a human skimming the repo without going through Claude, or once the backlog
is large enough that reading every file on every question gets wasteful.
Neither applies yet, and adding one later doesn't require changing the
per-item file format.

**No status field.** Presence of a file in `backlog/` means the item is open.
There is no in-progress/blocked state tracked here. When an item is done, its
file is **deleted entirely** — the project's changelog is the permanent
record of what shipped, so the backlog only ever needs to reflect what's
still open.

## Item schema

YAML frontmatter + markdown body:

```yaml
---
id: 7
title: Add dark mode toggle
type: feature        # bug | feature | enhancement | regression | chore | docs | spike
priority: P1          # P0 | P1 | P2 | P3
tags: [tui, theming]  # free-form, project-specific
depends_on: [3]       # optional, list of ids this item is blocked by
created: 2026-08-08
---

## Description

...

## Acceptance Criteria

- [ ] ...
```

Field notes:
- **`type`** is a fixed, closed vocabulary (`bug`, `feature`, `enhancement`,
  `regression`, `chore`, `docs`, `spike`) — kept small and consistent on
  purpose so it stays meaningful across items and projects.
- **`priority`** is `P0`-`P3` (`P0` = urgent/blocking). Always asked directly
  when an item is created — never silently defaulted, since it's the primary
  thing the backlog gets sorted by.
- **`tags`** is free-form and project-specific (e.g. `tui`, `api`, `auth`).
  It doubles as the mechanism for finding related items: two items sharing a
  tag are related by that fact alone — no separate `related` field needed.
- **`depends_on`** is a list of other items' `id`s that block this one. Only
  set when explicitly stated — never inferred by the skill.
- **`id`** in frontmatter is a plain integer (`7`), not zero-padded — the
  zero-padding (`0007`) is purely a filename convenience for sort order and
  fixed-width readability, not a schema property.

## Triggers

The skill should auto-invoke (via its `description` frontmatter, same
mechanism as any other skill) in two situations:

1. **Explicit ask.** The user says they want to log a new todo/idea. The
   skill gathers title, type, priority, tags, description, and acceptance
   criteria conversationally, then writes the item. Because the user
   initiated it and is present for the conversational gathering, no separate
   confirmation gate is needed before writing.

2. **Deferred task, mid-session.** Claude (or a subagent) identifies
   something during work that could be tackled in a future PR/MR, and the
   user approves deferring it. The skill drafts title/type/priority/tags
   /description/acceptance criteria from the conversation context that
   already exists, then **shows an explicit confirmation** before writing,
   e.g.:
   > Adding to backlog: "Add dark mode toggle" [feature / P2 / tui] — sound right?

   Only writes the file after an explicit yes.

## Querying

"What's in the backlog" / "what should I work on next" reads all
`backlog/*.md`, parses frontmatter, and presents items sorted by `priority`
(`P0` first) with `id` as tiebreaker. Supports filtering by `type` or `tag`
on request (e.g. "show me open bugs," "anything tagged tui").

## Concurrency / id collisions

Because id assignment is "scan max, +1" with no central counter, two branches
minting an item concurrently could pick the same id. This surfaces as a
normal git conflict on two new files with the same name at merge/PR time —
immediately visible, trivially resolved by renumbering one file. Not worth
additional machinery to prevent for v1.

## Open questions for the implementation plan

- Exact skill name and its `description` frontmatter wording (needs to be
  specific enough to trigger reliably on both cases above without
  over-triggering on unrelated "let's fix this later" chatter).
- Whether `backlog/` needs to be created on first use, and where the skill
  documents the `type` vocabulary and schema for the user's reference
  in-repo (likely inside the skill itself, per standard skill authoring).
- Whether this ships as its own skill or two closely related skills (capture
  vs. query) — leaning one skill, deferred to writing-plans.
