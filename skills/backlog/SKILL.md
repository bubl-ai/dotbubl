---
name: backlog
description: Use when the user wants to log a new todo/idea, when a task identified during work is deferred to a future PR/MR and the user approves, when asked what's in the backlog or what to work on next, or when a backlog item is done and should be removed. Manages a per-project backlog/ folder of markdown items with type, priority, and tags.
---

# Backlog

Manages a lightweight, git-native backlog for the *current project* —
including the `dotbubl` repo itself when that's the current project.

`dotbubl`'s own `backlog/` is git-ignored (see `.gitignore`): the plugin
manifest ships the whole repo root to every installer
(`"source": "./"` in `.claude-plugin/marketplace.json`) and the repo is
public, so anything committed here is what everyone downloads and can
browse on GitHub. Backlog items are personal planning notes, not something
to publish — the skill still creates and manages them normally, they just
never get committed, and won't sync to the maintainer's other machines the
way the rest of the repo does.

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

## Context

...

## Acceptance Criteria

- [ ] ...
```

`title`, `type`, `priority`, `description`, `context`, and `acceptance
criteria` are all **required** — never write an item missing any of these,
and never fill one with a generic placeholder just to move forward. If one
can't be gathered or drafted from context, ask for it before writing.
`tags` and `depends_on` are optional.

`priority` must always be asked directly if not already stated — never
silently defaulted.

**`context` makes the item stand alone.** A future session picking this
item up may have none of the current conversation available, so it needs
*why*, not just *what*. Capture the reasoning that actually led here: what
was discussed, what alternatives were considered and rejected (and why),
and any constraints that shaped the scope or priority. Draw this from the
real conversation — never invent specifics that weren't actually discussed.

If the item comes from a direct, one-line ask with no real prior
discussion, a brief, honest statement of that fact (e.g. "Requested
directly; no prior discussion to capture.") satisfies the requirement —
that's real information, not a placeholder. What's *not* acceptable, no
matter how much discussion actually happened: generic non-answers like
"N/A", "see above", or "see description" that dodge the requirement rather
than truthfully filling it.

## Querying the backlog

When asked what's in the backlog, what to work on next, or for a filtered
view (by `type` or `tag`): read every `backlog/*.md` file, parse its
frontmatter, and present the items sorted by `priority` (`P0` first, `P3`
last) with `id` as the tiebreaker for items sharing a priority.

## Creating an item — explicit ask

When the user says they want to log a new todo/idea: gather, conversationally,
whatever of these isn't already given — title, `type`, `priority` (ask
directly, never default), `tags`, description, context, acceptance
criteria. Title, type, priority, description, context, and acceptance
criteria are required — keep asking until each is actually provided; don't
move on with any of them missing or generic. See "Item files" above for
what belongs in `context` and when a brief "no prior discussion" note is
enough.

Once everything required is gathered, show a confirmation line and wait for
an explicit yes before writing:

> Add to backlog: "<title>" [<type> / <priority> / <tags>] — with
> description, context, and N acceptance criteria. Sound right?

Do not write the file until the user responds affirmatively to that
specific confirmation. Once confirmed, compute the next id and slug per
"Item files" above, write `backlog/NNNN-slug.md` with the frontmatter +
body shape shown above, then confirm what was added (id, title, path).

## Creating an item — deferred task identified mid-session

When Claude (or a subagent) identifies, during work, something that could be
tackled in a future PR/MR, and the user approves deferring it: draft title,
`type`, `priority`, `tags`, description, context, and acceptance criteria
from the conversation context that already exists. Title, type, priority,
description, context, and acceptance criteria are required — if the
context doesn't give enough to draft a real one (not a placeholder), ask
before showing the confirmation line. This is usually the richest path for
`context`: mid-session deferrals almost always follow real discussion
(design decisions, rejected approaches, why something's out of scope) —
capture that, not just a restatement of the description. If `priority` is
not clear from that context, ask directly before proceeding — never
default it. Then show a confirmation line and wait for an explicit yes
before doing anything else:

> Adding to backlog: "<title>" [<type> / <priority> / <tags>] — with
> description, context, and N acceptance criteria. Sound right?

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
