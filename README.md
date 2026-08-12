# dotbubl

Personal Claude Code toolkit — skills, hooks, and conventions, versioned in
git and installed as a plugin so they're available in every project on every
machine, without living inside any single repo's `.claude/` folder.

Structured the way [obra/superpowers](https://github.com/obra/superpowers)
does it: a self-hosted plugin + marketplace in one repo, plus a
`using-dotbubl` meta-skill injected at session start so skills get checked
and used automatically, not just left on disk waiting to be remembered.

## Install

```
/plugin marketplace add bubl-ai/dotbubl
/plugin install dotbubl@dotbubl
```

Run inside an interactive Claude Code session (`/plugin` is a slash command,
not a shell command). This is per-machine and one-time — from then on it's
loaded in every session on that machine, regardless of working directory.

## What you get

Once installed, dotbubl is active from the first message of every session —
there's nothing to turn on. A `SessionStart` hook injects the
`using-dotbubl` meta-skill as always-on context, which tells Claude to check
for a matching dotbubl skill before acting, and use it if one applies.

### `backlog` — a per-project todo list, in plain markdown

Track ideas and tasks for whatever project you're in as one markdown file
per item under that project's own `backlog/` folder — no server, no app,
just files you can read, grep, and commit like anything else in the repo.

```
You:     We should add dark mode eventually, but not now — log it.
Claude:  Add to backlog: "Add dark mode support" [feature / P2] — with
         description and 2 acceptance criteria. Sound right?
You:     yes
Claude:  Added #4 "Add dark mode support" to backlog/0004-add-dark-mode-support.md
```

Other things you can say:

- **"What's in the backlog?"** / **"What should I work on next?"** — lists
  every item, sorted by priority (P0 first).
- **"Any P0 bugs in there?"** — filter by type or tag.
- **"Mark #3 done"** — deletes the item once you confirm (the work itself is
  assumed to be recorded elsewhere, e.g. your changelog or commit history).
- Notice something worth deferring mid-task ("let's fix that in a follow-up
  PR") — Claude will offer to log it instead of losing track of it.

Every item requires a title, type (`bug` / `feature` / `enhancement` /
`regression` / `chore` / `docs` / `spike`), priority (`P0`–`P3`),
description, and acceptance criteria — Claude always asks for anything
missing or vague rather than guessing or writing a placeholder.

### `keeping-docs-current` — checks whether your docs still match the code

Given a base ref to diff against, checks whether `CLAUDE.md`, `README.md`,
and anything they reference are stale relative to what changed —
dispatches a read-only analysis and reports findings, it never edits a doc
itself.

```
You:     Check whether the docs are stale against main.
Claude:  README.md still references docs/setup.md, which was removed on
         this branch. No other issues found.
```

Needs a base ref — provide one explicitly (a branch name, `main`, a commit
SHA) when asking; it won't guess one. Usable standalone today; once the
`before-pr-checks` guideline lands, that ref gets supplied automatically as
part of a before-PR check instead.

More skills land here over time; each new one gets the same treatment —
checked automatically, no need to memorize a command.

## Update

After pushing changes to this repo:

```
/plugin marketplace update dotbubl
```

(or reinstall / restart Claude Code, depending on version)

## Developing locally

Test changes before pushing, without touching your real install:

```
claude --plugin-dir ./dotbubl
```

Then `/reload-plugins` after each edit to pick up changes. See `CLAUDE.md`
for the full contributor workflow (testing, versioning, etc.).

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
  keeping-docs-current/  # checks CLAUDE.md/README.md/referenced docs for staleness against a base ref
hooks/
  hooks.json         # registers the SessionStart hook
  session-start      # injects using-dotbubl as always-on context
tests/               # committed, runnable tests per skill or agent
docs/                # testing convention + design plans/specs
```

Add new skills under `skills/<skill-name>/SKILL.md`, agents under `agents/`,
more hooks in `hooks/hooks.json`, MCP servers in `.mcp.json` — all at the
repo root (never inside `.claude-plugin/`, which holds only the two
manifests).

## Note on scope

Bare Claude Code settings (`permissions`, `env`, `model`, etc.) are **not**
portable via plugins — only `agent` and `subagentStatusLine` keys are read from
a plugin's `settings.json`. Keep machine-specific settings in each machine's
own `~/.claude/settings.json`.

## License

MIT — see [LICENSE](LICENSE).
