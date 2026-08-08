---
name: backlog
description: Use when the user wants to log a new todo/idea, when a task identified during work is deferred to a future PR/MR and the user approves, when asked what's in the backlog or what to work on next, or when a backlog item is done and should be removed. Manages a per-project backlog/ folder of markdown items with type, priority, and tags.
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
  only**. Compute the next id as the max of (a) every `NNNN` currently
  present in `backlog/*.md`, and (b) every `NNNN` that ever existed there,
  by running `git log --diff-filter=D --name-only -- backlog/` and
  extracting ids from the deleted filenames — then add 1. Always check
  (b), not just when the directory happens to look sparse: a backlog
  completed in id order (e.g. 4-7 done and deleted, leaving 1-3) looks
  perfectly dense with no visible gap, and would otherwise silently
  reassign a previously-used id. If the directory is empty, doesn't exist
  yet, and `git log` shows no prior deletions, the next id is `1`.
- Ids are **never reused** — a stale `depends_on` reference or changelog
  mention of a number must keep pointing at the same item it always did.
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

`title`, `type`, `priority`, `description`, and `acceptance criteria` are
all **required** — never write an item missing any of these, and never
fill one with a generic placeholder just to move forward. If one can't be
gathered or drafted from context, ask for it before writing. `tags` and
`depends_on` are optional.

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
directly, never default), `tags`, description, acceptance criteria. Title,
type, priority, description, and acceptance criteria are required — keep
asking until each is actually provided; don't move on with any of them
missing or generic.

Once everything required is gathered, show a confirmation line and wait for
an explicit yes before writing:

> Add to backlog: "<title>" [<type> / <priority> / <tags>] — with
> description and N acceptance criteria. Sound right?

Do not write the file until the user responds affirmatively to that
specific confirmation. Once confirmed, compute the next id and slug per
"Item files" above, write `backlog/NNNN-slug.md` with the frontmatter +
body shape shown above, then confirm what was added (id, title, path).

## Creating an item — deferred task identified mid-session

When Claude (or a subagent) identifies, during work, something that could be
tackled in a future PR/MR, and the user approves deferring it: draft title,
`type`, `priority`, `tags`, description, and acceptance criteria from the
conversation context that already exists. Title, type, priority,
description, and acceptance criteria are required — if the context doesn't
give enough to draft a real one (not a placeholder), ask before showing the
confirmation line. If `priority` is not clear from that context, ask
directly before proceeding — never default it. Then show a confirmation
line and wait for an explicit yes before doing anything else:

> Adding to backlog: "<title>" [<type> / <priority> / <tags>] — with
> description and N acceptance criteria. Sound right?

Do not write the file until the user responds affirmatively to that specific
confirmation. Once confirmed, write it using the same id/slug/frontmatter
mechanics and post-write confirmation as the explicit-ask path above.

## Completing an item

When the user indicates a backlog item is done (e.g. "mark #3 done", "that
backlog item is finished", "the fix shipped"): find `backlog/NNNN-*.md` for
that id. If no id is given, or the phrase could match more than one item,
list the candidate item(s) — id and title — and have the user confirm or
pick which one before proceeding. Then show a confirmation line and wait for
an explicit yes:

> Remove backlog item #<id> "<title>"?

Do not delete the file until the user responds affirmatively to that
specific confirmation. It's assumed the work is shipped/recorded elsewhere
(e.g. the changelog) — there is no status field and no archive: a completed
item's only record after this point is the project's changelog/commit
history, not the backlog.
