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

Full detail in `docs/testing.md`; the summary that matters day to day:

**Every skill that ships verifiable behavior gets committed, runnable tests
under `tests/<skill-name>/`** — never left as prose-only plan content or
throwaway `/tmp` scripts. `/tmp` files aren't part of the repo, don't
survive a reboot, and can't be re-run by anyone without reverse-engineering
them back out of a plan doc. That already happened once with
`skills/backlog` before being fixed — `tests/backlog/` is the reference
shape for every skill after it:

- `test-helpers.sh` — shared `run_claude`/`assert_*` functions (modeled on
  superpowers' `tests/claude-code/test-helpers.sh`), sourced by every test
  file, never run directly.
- One `test-N-<behavior>.sh` per behavior, independently runnable, each
  accumulating failures across its assertions rather than stopping at the
  first one.
- `run-all.sh` — runs every `test-*.sh` in the directory (excluding the
  helpers file), supports `--verbose` / `--test NAME` / `--timeout`,
  prints a pass/fail summary, exits non-zero on any failure.
- `README.md` — structure, current test list, how to add more.
- Whatever gotchas got learned the hard way (e.g. `--permission-mode
  acceptEdits` for non-interactive writes; macOS having no `timeout`
  binary) get fixed in `test-helpers.sh`/`run-all.sh` directly, not just
  noted — the next skill's tests inherit the fix for free.

**When you add or change a skill's behavior:** update or add the
corresponding test file(s) in the same commit, and actually run
`tests/<skill>/run-all.sh` before committing — don't just claim it passes.

If a plan doc's embedded test scripts (from `writing-plans`/SDD execution)
end up diverging from what's actually committed under `tests/`, the
committed files are the source of truth; treat the plan's copy as a
historical snapshot of intent, not something to keep byte-identical.

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

## Ongoing workflow

1. Edit skills/agents/hooks in this repo.
2. Test locally without touching your real install:
   - `claude --plugin-dir .` — loads the plugin from the local working copy
     for that session only (nothing persisted, no marketplace/install
     involved). If also installed for real, this takes priority for the
     session, so you can compare against the installed version.
   - `/reload-plugins` inside that session after further edits — Claude Code
     doesn't watch the filesystem, so this re-reads skills/agents/hooks/MCP
     configs on demand.
   - `-p "<prompt>"` for a scriptable one-shot smoke test, e.g.:
     `claude --plugin-dir . -p "Run /dotbubl:using-dotbubl and confirm you
     loaded it, nothing else."`
   - `claude plugin validate .` for structural validation (manifest shape,
     paths) without invoking the model.
   - See "Testing convention" above — anything you'd re-run more than once
     belongs in `tests/<skill>/`, not just run ad hoc.
3. Bump `version` in **both** `.claude-plugin/plugin.json` and
   `.claude-plugin/marketplace.json` — installed copies only notice an
   update when the version actually changes.
4. Commit → branch → PR → merge.
5. On each machine with it installed: `/plugin marketplace update dotbubl`,
   then restart/reload.
