---
name: dev-loop
description: Use when testing or iterating on dotbubl's skills, agents, or hooks locally, or when preparing to commit/release a change to this plugin — the edit/test/commit loop for this repo.
---

# dev-loop

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
   - See `docs/testing.md` — anything you'd re-run more than once belongs
     in `tests/<skill>/`, not just run ad hoc.
3. Bump `version` in **both** `.claude-plugin/plugin.json` and
   `.claude-plugin/marketplace.json` — installed copies only notice an
   update when the version actually changes.
4. Check documentation before committing — see CLAUDE.md's "Documentation
   stays current".
5. Commit → branch → PR → merge.
6. On each machine with it installed: `/plugin marketplace update dotbubl`,
   then restart/reload.
