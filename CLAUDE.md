# CLAUDE.md

Guidance for working *in this repo*. Not shipped to anyone who installs the
plugin elsewhere — plugins have no CLAUDE.md-equivalent component, which is
why `hooks/session-start` exists to inject always-on context instead.

## Reference

[obra/superpowers](https://github.com/obra/superpowers) is our reference for
best practices on structuring and writing this plugin — plugin/marketplace
layout, the `using-<name>` meta-skill + `SessionStart` hook pattern, skill
writing conventions, the "Skill Priority" ordering rule, etc. When in doubt
about how to structure or word something here, check how superpowers does it
first, then adapt (not copy wholesale — e.g. we don't carry over its
multi-platform or PR-contribution-guideline content, since those don't apply
to this repo).

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

**Every skill that ships verifiable behavior gets committed, runnable tests
under `tests/<skill-name>/` — never left as prose-only plan content or
throwaway `/tmp` scripts.** `/tmp` files aren't part of the repo, don't
survive a reboot, and can't be re-run by anyone (or anything, e.g. future
CI) without first reverse-engineering them back out of a plan doc. That
already happened once with `skills/backlog` — see `tests/backlog/` for the
result and its shape:

- One script per behavior (`test-N-<behavior>.sh`), each independently
  runnable: `bash tests/<skill>/test-N-*.sh`.
- A shared `common.sh` for setup that's actually shared (scratch git repo,
  `--plugin-dir` resolved from the script's own location — **never a
  hardcoded absolute path**, since the same script must work from the
  primary checkout or any worktree) — DRY without inventing a framework.
- A `run-all.sh` that runs every `test-*.sh` in the directory and prints a
  pass/fail summary.
- Bake in whatever gotchas were learned the hard way (e.g.
  `--permission-mode acceptEdits` for non-interactive writes) so the next
  person — or the next skill — doesn't have to rediscover them.

**When you add or change a skill's behavior:** update or add the
corresponding test file(s) in the same commit, and actually run
`tests/<skill>/run-all.sh` before committing — don't just claim it passes.
If a plan doc's embedded test scripts (from `writing-plans`/SDD execution)
end up diverging from what's actually committed under `tests/`, the
committed files are the source of truth; treat the plan's copy as a
historical snapshot of intent, not something to keep byte-identical.

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
