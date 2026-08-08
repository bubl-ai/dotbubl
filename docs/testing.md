# Testing dotbubl

Modeled on [obra/superpowers](https://github.com/obra/superpowers)'
`docs/testing.md`, adapted to this repo's actual scale (one maintainer, a
handful of skills so far). Re-check their current version before making
structural changes here — this file should stay a deliberate adaptation,
not drift into a stale copy.

## What superpowers does, and what we do

Superpowers has two tiers:

- **`tests/`** — bash/node/python tests of the plugin's non-LLM code
  (manifest wiring, hook output shape, sync scripts), run directly, no API
  cost.
- **`evals/`** — a *separate companion repo* (`superpowers-evals`), a
  Python harness ("Drill") driving real tmux sessions of Claude Code /
  Codex / Gemini CLI against YAML scenarios, with an LLM verifier judging
  skill compliance. Slow (3-30+ minutes per scenario), real API spend,
  explicitly not part of CI even for them today.

We have one tier: **`tests/<skill-name>/`** — see `tests/backlog/README.md`
for the concrete structure. It plays the role of superpowers' `tests/`, but
because our skills are pure prose/instructions (no non-LLM code to test
separately), our tests *are* real Claude Code invocations against
`--plugin-dir`, checking actual behavior (files written, confirmations
shown, gates honored) — closer in spirit to what superpowers' `evals/`
tier checks, just without the YAML-scenario format, the separate harness
repo, or the tmux-session machinery.

**We do not have an `evals/` tier**, and don't plan to build one yet. That
infrastructure exists to support many contributors and many skills under
adversarial pressure-testing at scale; building it now, for one person and
a handful of skills, would be pure overhead. Revisit if this repo grows
enough contributors or skills that ad hoc `tests/<skill>/` scripts stop
being enough — the signal to watch for is tests taking real effort to keep
in sync with skill changes, not a fixed skill count.

## No CI

Superpowers itself has no `.github/workflows/` — not even for its fast
`tests/` tier. Rigor there comes from documented convention (`CLAUDE.md`'s
Testing convention, in our case) plus running tests before committing, not
automated gating. We match that deliberately, not by oversight: adding CI
here would need an `ANTHROPIC_API_KEY` repo secret and spends real API
tokens on every push, for a solo repo where "did I run the tests" is
already enforced by nobody but the person committing. Revisit if that
changes (more contributors, or tests routinely skipped before commit).

## Running tests

Per-skill, from the repo root:

```bash
tests/backlog/run-all.sh
```

Each skill's test directory has its own `README.md` with specifics.

## Writing tests for a new skill

1. Create `tests/<skill-name>/` with `test-N-*.sh` per behavior,
   `run-all.sh`, `README.md` — copy the shape of `tests/backlog/`.
2. **Source the shared `tests/test-helpers.sh`** (`"$SCRIPT_DIR/../test-helpers.sh"`
   from inside `tests/<skill-name>/`) — don't copy it per skill. This
   matches superpowers: every skill's tests in `tests/claude-code/` source
   the same `test-helpers.sh`, not a per-skill copy. Extend the shared file
   when a new assertion is generically useful (the way `assert_frontmatter`
   was added for YAML-frontmatter items — useful to any future skill with
   frontmatter, not backlog-specific despite being added for it); keep
   something truly skill-specific local to that skill's own test directory
   instead.
3. See `CLAUDE.md`'s Testing convention for the commit discipline
   (tests land in the same commit as the behavior they cover, and get
   actually run — not just claimed — before committing).
