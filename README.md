# dotbubl

Claude Code toolkit — skills, agents, hooks and conventions,
versioned in git and installed as a plugin so they're available in every project
on every machine, without living inside any single repo's `.claude/` folder.

Structured the way [obra/superpowers](https://github.com/obra/superpowers) does it:
a self-hosted plugin + marketplace in one repo, plus a `using-dotbubl` meta-skill
injected at session start so skills get checked and used, not just left on disk.

## Install

```
/plugin marketplace add bubl-ai/dotbubl
/plugin install dotbubl@dotbubl
```

Skills, agents, and commands from this toolkit are namespaced, e.g. `/dotbubl:some-skill`.

## Update

After pushing changes to this repo:

```
/plugin marketplace update dotbubl
```

(or reinstall / restart Claude Code, depending on version)

## Developing locally

Test changes before pushing, without reinstalling:

```
claude --plugin-dir ./dotbubl
```

Then `/reload-plugins` after each edit to pick up changes.

## Structure

```
.claude-plugin/
  plugin.json       # plugin manifest
  marketplace.json  # self-hosted marketplace (this repo installs itself)
skills/
  using-dotbubl/     # meta-skill: enforces checking/using skills before acting
  backlog/           # per-project backlog of todos/ideas
hooks/
  hooks.json         # registers the SessionStart hook
  session-start      # injects using-dotbubl as always-on context
```

Add new skills under `skills/<skill-name>/SKILL.md`, agents under `agents/`,
more hooks in `hooks/hooks.json`, MCP servers in `.mcp.json` — all at the repo
root (never inside `.claude-plugin/`, which holds only the two manifests).

Bump `version` in both `plugin.json` and `marketplace.json` when you want
installed copies to actually pick up an update.

## Note on scope

Bare Claude Code settings (`permissions`, `env`, `model`, etc.) are **not**
portable via plugins — only `agent` and `subagentStatusLine` keys are read from
a plugin's `settings.json`. Keep machine-specific settings in each machine's
own `~/.claude/settings.json`.
