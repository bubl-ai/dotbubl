# CLAUDE.md

Guidance for working *in this repo*. Not shipped to anyone who installs the
plugin elsewhere — plugins have no CLAUDE.md-equivalent component, which is
why `hooks/session-start` exists to inject always-on context instead.

## Reference

[obra/superpowers](https://github.com/obra/superpowers) is our reference for
best practices on structuring and writing this plugin — plugin/marketplace
layout, the `using-<name>` meta-skill + `SessionStart` hook pattern, skill
writing conventions, the "Skill Priority" ordering rule, testing structure,
etc. When in doubt about how to structure or word something here, check how
superpowers does it *now* (re-fetch, don't rely on memory of an old
checkout) first, then adapt — not copy wholesale. See "What we deliberately
don't adopt" below for the parts that don't fit this repo's scale.

## Repo layout

```
.claude-plugin/             plugin.json + marketplace.json — only files that belong here
agents/<name>.md            custom subagent definitions, one file per agent; guideline-check
                            is the first — a shared read-only subagent for before-PR checks
skills/<name>/SKILL.md      one skill per directory; using-dotbubl is the meta-skill
                            (see its own "Skill Priority" section when adding another)
hooks/                      hooks.json + hook scripts (session-start injects using-dotbubl
                            as always-on context — plugins have no CLAUDE.md equivalent)
tests/<skill-or-agent-name>/ committed, runnable tests per skill or agent — see "Testing convention"
docs/testing.md             testing convention in full
docs/superpowers/plans/     committed plan/spec docs from the writing-plans / brainstorming
docs/superpowers/specs/     skills, one per feature, named YYYY-MM-DD-<slug>.md
backlog/                    this repo's own personal backlog — gitignored (see
                            skills/backlog/SKILL.md's note on why: the plugin ships the
                            whole repo root, and backlog items aren't meant to be published)
```

`agents/` now holds custom subagent definitions (`guideline-check` is the
first); `.mcp.json` (MCP servers) doesn't exist yet but follows the same
pattern when added — repo root, never inside `.claude-plugin/`. `README.md`
covers the user-facing shape of this same layout; keep both in sync when
the structure changes, but don't just duplicate one into the other —
README explains what installers get, this section explains where a
contributor edits it.

## Installing

```
/plugin marketplace add bubl-ai/dotbubl
/plugin install dotbubl@dotbubl
```

Run inside an interactive Claude Code session (`/plugin` is a slash command,
not a shell command). This is per-machine and one-time: it registers this
repo as a marketplace and installs the `dotbubl` plugin from it, persisted in
`~/.claude.json`. From then on it's loaded in every session on that machine,
regardless of working directory — not just when you happen to be inside this
repo or pass `--plugin-dir`.

To update an existing install after new commits land on `main`:
```
/plugin marketplace update dotbubl
```
then restart or reload so the new version takes effect.

## Testing convention

**Every skill or agent that ships verifiable behavior gets committed,
runnable tests under `tests/<skill-or-agent-name>/`, added in the same
commit as the behavior change, and actually run — not just claimed —
before committing.** Full structure and detail: `docs/testing.md`.

## What we deliberately don't adopt from superpowers

Checked against their current repo, not guessed:

- **An `evals/` tier.** They run a separate companion repo
  (`superpowers-evals`) with a Python harness (Drill) driving real tmux
  sessions and an LLM verifier, for adversarial pressure-testing skill
  wording at scale. That infrastructure earns its cost with many
  contributors and many skills; for one person and a handful of skills it
  would be pure overhead. `tests/<skill>/` already does real
  `--plugin-dir` behavioral checks, which covers our actual need.
- **CI.** They have none either, even for their fast `tests/` tier — so
  this isn't a gap relative to them, it's matching them. Adding one here
  would need an `ANTHROPIC_API_KEY` secret and real spend per push, for a
  repo where "run the tests first" is already just personal discipline.
- **`.github/PULL_REQUEST_TEMPLATE.md`'s content.** Theirs exists to
  defend a public repo against low-quality external AI-submitted PRs
  (multi-harness disclosure, "who reviewed this diff," duplicate-PR
  checks). This repo has one contributor — none of that applies.
- **Multi-harness support** (Codex/Cursor/Kimi/Pi/Antigravity/OpenCode
  plugin variants). `dotbubl` targets Claude Code only.

## Documentation stays current

**After every change, check documentation — don't defer it.** The two main
docs are `README.md` and `CLAUDE.md`, plus anything they refer to (e.g.
`docs/testing.md`, `skills/*/SKILL.md`). Re-read the sections a change
touches and confirm they're still valid: paths that still exist, counts and
lists that still match, described behavior that still matches what the code
actually does. Docs that quietly drift from the repo are worse than no docs
— they actively mislead the next reader (human or agent). Fix drift in the
same commit as the change that caused it, not as a follow-up.

## Ongoing workflow

See the `dev-loop` skill (`.claude/skills/dev-loop/SKILL.md`) for the
local edit/test/commit loop — load it when iterating on this plugin.
