---
name: backlog
description: Use when the user wants to log a new todo/idea, when a task identified during work is deferred to a future PR/MR and the user approves, or when asked what's in the backlog or what to work on next. Manages a per-project backlog/ folder of markdown items with type, priority, and tags.
---

# Backlog

Manages a lightweight, git-native backlog for the *current project* — never
for the `dotbubl` plugin itself.

## Where the backlog lives

Run `git rev-parse --show-toplevel` to find the current project's root.
The backlog is `<that path>/backlog/`. Create the directory if it doesn't
exist yet (first use in a project).

## Item files

One file per item: `backlog/NNNN-slug.md`.

- `NNNN`: sequential integer id, zero-padded to 4 digits in the **filename
  only**. Compute the next id by listing `backlog/*.md`, extracting the
  leading `NNNN` from each filename, taking the max, and adding 1. If the
  directory is empty or doesn't exist yet, the next id is `1`.
- `slug`: the title, lowercased, punctuation stripped, spaces replaced with
  hyphens, truncated to ~40 characters.

Frontmatter:

```yaml
---
id: 7                 # plain integer, NOT zero-padded (padding is filename-only)
title: Add dark mode toggle
type: feature          # one of: bug | feature | enhancement | regression | chore | docs | spike
priority: P1            # one of: P0 | P1 | P2 | P3
tags: [tui, theming]    # free-form, project-specific; also how related items are found
depends_on: [3]         # optional — list of ids this item is blocked by. Only set when explicitly stated, never inferred.
created: 2026-08-08
---

## Description

...

## Acceptance Criteria

- [ ] ...
```

`priority` must always be asked directly if not already stated — never
silently defaulted.

## Querying the backlog

When asked what's in the backlog, what to work on next, or for a filtered
view (by `type` or `tag`): read every `backlog/*.md` file, parse its
frontmatter, and present the items sorted by `priority` (`P0` first, `P3`
last) with `id` as the tiebreaker for items sharing a priority.

## Creating an item — explicit ask

When the user says they want to log a new todo/idea: gather, conversationally,
whatever of these isn't already given — title, `type`, `priority` (ask
directly, never default), `tags`, description, acceptance criteria. Compute
the next id and slug per "Item files" above, write
`backlog/NNNN-slug.md` with the frontmatter + body shape shown above, then
confirm what was added (id, title, path).

No separate confirmation gate is needed here — the user initiated this
directly and was present for the conversational gathering.

## Creating an item — deferred task identified mid-session

When Claude (or a subagent) identifies, during work, something that could be
tackled in a future PR/MR, and the user approves deferring it: draft title,
`type`, `priority`, `tags`, description, and acceptance criteria from the
conversation context that already exists. If `priority` is not clear from that
context, ask directly before proceeding — never default it. Then show a
confirmation line and wait for an explicit yes before doing anything else:

> Adding to backlog: "<title>" [<type> / <priority> / <tags>] — sound right?

Do not write the file until the user responds affirmatively to that specific
confirmation. Once confirmed, write it using the same id/slug/frontmatter
mechanics and post-write confirmation as the explicit-ask path above.
