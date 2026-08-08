# Backlog Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a `backlog` skill from the `dotbubl` plugin that lets any project have a lightweight, git-native backlog of todos/ideas, capturable two ways (explicit ask, or a deferred-task-approved-mid-session), and queryable ("what's in the backlog / what should I tackle next").

**Architecture:** A single skill file (`skills/backlog/SKILL.md`) containing all behavior as instructions Claude follows — no separate scripts or code, consistent with how `using-dotbubl` and superpowers' own skills are built. The skill operates on `<git-toplevel-of-cwd>/backlog/*.md` in whatever project it's invoked from (never inside `dotbubl` itself). Because behavior lives in prose rather than a programming language, "tests" here are functional smoke tests: invoke `claude --plugin-dir` against a disposable scratch git repo and assert on the resulting files on disk (deterministic) and, where only conversational output can be checked, on a requested fixed output format (as deterministic as prompting allows — flag this limitation, don't pretend otherwise).

**Tech Stack:** Claude Code plugin skill (Markdown + YAML frontmatter). Bash for test scripts. `git` for repo-root detection.

**Testing gotcha (discovered during Task 2, applies to every test script that writes or deletes a file):** non-interactive `-p` invocations need `--permission-mode acceptEdits` or the model silently can't write/delete and asks for permission in its text reply instead — this looks exactly like "the skill isn't triggering" but isn't. Also: `--plugin-dir` must point at *this plan's worktree* (wherever it is checked out), never the main checkout, until this branch is merged — the main checkout won't have this branch's `skills/backlog/` content.

**Testing gotcha #2 (discovered during Task 3, applies to the two-turn confirmation-gate test):** don't layer a redundant user-authored "don't do X until I separately say go ahead" instruction on top of the skill's own confirmation gate in the turn-1 prompt — the model reasonably treats that as a second, distinct gate on top of the "sound right?" confirmation, turning a 2-turn test into a 3-turn interaction and making turn 2 look like a failure to write when it's actually just answering the wrong question. State only what the design actually specifies (identification + approval to defer) in turn 1, and let the skill's own single confirmation line be the one thing turn 2's "yes" responds to.

**Testing gotcha #3 (discovered during Task 3, applies to any scratch-repo test involving "context that already exists"):** the skill correctly refuses to fabricate title/description/acceptance-criteria specifics when the scratch repo has no actual code for a "while reviewing this code..." prompt to refer to — this is good behavior, not a bug, but it means test prompts describing a code-review scenario need enough concrete, specific detail (a real-sounding function/field name, a real-sounding gap) for the model to draft from, not a vague one-liner. Verified working end-to-end with a concrete prompt naming a specific function and specific missing validations.

## Global Constraints

(Copied from `docs/superpowers/specs/2026-08-08-backlog-skill-design.md` — every task's work implicitly includes these.)

- Backlog lives at `<project-root>/backlog/` where `<project-root>` is `git rev-parse --show-toplevel` of the invoking project — never inside `dotbubl`.
- One file per item: `backlog/NNNN-slug.md`, id zero-padded to 4 digits in the filename only.
- No persisted index file. No status field. Completed items are **deleted**, not archived.
- Frontmatter fields: `id` (plain integer), `title`, `type` (closed enum: `bug`, `feature`, `enhancement`, `regression`, `chore`, `docs`, `spike`), `priority` (`P0`-`P3`), `tags` (free-form list), `depends_on` (optional list of ids), `created` (`YYYY-MM-DD`). Body: `## Description`, `## Acceptance Criteria`.
- `priority` is always asked directly, never defaulted. `depends_on` is only set when explicitly stated, never inferred.
- Two triggers: (1) explicit ask → gather details conversationally, write directly, no extra confirmation gate. (2) task identified and deferred mid-session, user approves → draft from context, **show a confirmation line, wait for explicit yes**, only then write.
- Skill name: `backlog` (namespaced as `/dotbubl:backlog` once installed).

---

## File Structure

- **Create `skills/backlog/SKILL.md`** — the entire skill: frontmatter (name + trigger description) and all behavior (repo-root/id/slug mechanics, querying, both creation triggers). Kept as one file: this is v1 scope, one clear responsibility ("manage this project's backlog"), and doesn't yet need the reference-sub-file pattern larger superpowers skills use.
- **Modify `.claude-plugin/plugin.json`** — bump `version` `0.1.0` → `0.2.0`.
- **Modify `.claude-plugin/marketplace.json`** — bump the matching `version` field, same reason.
- **No change to `skills/using-dotbubl/SKILL.md`.** Its "Skill Priority" section only needs entries for skills that must sequence *before* others (like superpowers' `brainstorming`). `backlog` is a standalone, independently-triggered skill with no ordering relationship to `using-dotbubl` — nothing to add there.
- **No change to `README.md` / `CLAUDE.md`.** Both already describe "add skills under `skills/<name>/SKILL.md`" generically; no per-skill documentation needed there.

---

### Task 1: Repo-root/id/slug mechanics + querying

**Files:**
- Create: `skills/backlog/SKILL.md`

**Interfaces:**
- Produces: a `backlog` skill, invocable as `/dotbubl:backlog`, that (a) knows how to find/create `<project-root>/backlog/`, (b) knows how to compute the next id and a slug from a title, (c) can answer "what's in the backlog" by reading `backlog/*.md` and reporting items sorted by `priority` (`P0` first) then `id`. Tasks 2 and 3 both depend on the id/slug/location mechanics defined here and must reuse them verbatim (same rules, not reimplemented).

- [ ] **Step 1: Write the failing test**

Create `/tmp/backlog-test-1.sh` (or any scratch path — this is a throwaway test script, not part of the repo):

```bash
#!/usr/bin/env bash
set -euo pipefail

DOTBUBL_DIR="/Users/santiago/Desktop/github/dotbubl/.worktrees/backlog-skill-impl"  # this plan's active worktree — NOT the main checkout, which won't have this branch's skill content until merged
SCRATCH="$(mktemp -d)"
cd "$SCRATCH"
git init -q
mkdir -p backlog

cat > backlog/0001-fix-flaky-login-test.md <<'EOF'
---
id: 1
title: Fix flaky login test
type: bug
priority: P2
tags: [ci]
created: 2026-08-01
---

## Description
The login test intermittently times out in CI.

## Acceptance Criteria
- [ ] Test passes 20/20 consecutive CI runs
EOF

cat > backlog/0002-add-dark-mode.md <<'EOF'
---
id: 2
title: Add dark mode toggle
type: feature
priority: P0
tags: [tui, theming]
created: 2026-08-02
---

## Description
Users want a dark mode toggle in settings.

## Acceptance Criteria
- [ ] Toggle persists across sessions
EOF

OUT="$(claude --plugin-dir "$DOTBUBL_DIR" -p "List everything in the backlog, sorted by priority. Format each line EXACTLY as: <priority> #<id> <title>")"
echo "$OUT"

LINE_P0=$(grep -n "P0 #2 Add dark mode toggle" <<<"$OUT" | cut -d: -f1 || true)
LINE_P2=$(grep -n "P2 #1 Fix flaky login test" <<<"$OUT" | cut -d: -f1 || true)

if [[ -z "$LINE_P0" || -z "$LINE_P2" || "$LINE_P0" -ge "$LINE_P2" ]]; then
  echo "FAIL: expected P0 item before P2 item"
  exit 1
fi
echo "PASS"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `chmod +x /tmp/backlog-test-1.sh && /tmp/backlog-test-1.sh`
Expected: FAIL — `skills/backlog/SKILL.md` doesn't exist yet, so there is no `backlog` skill to invoke; the model has no instructions for sorting/formatting backlog items this way and the exact-format assertion will not match.

- [ ] **Step 3: Write minimal implementation**

Create `skills/backlog/SKILL.md`:

```markdown
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/tmp/backlog-test-1.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add skills/backlog/SKILL.md
git commit -m "backlog skill: repo-root/id/slug mechanics + querying"
```

---

### Task 2: Explicit-ask creation

**Files:**
- Modify: `skills/backlog/SKILL.md`

**Interfaces:**
- Consumes: the id/slug/location mechanics from Task 1's "Where the backlog lives" / "Item files" sections — reuse exactly, don't restate different rules.
- Produces: creation behavior for trigger 1 (explicit ask), which Task 3 must NOT reuse as-is (trigger 2 needs the extra confirmation gate on top of this).

- [ ] **Step 1: Write the failing test**

Create `/tmp/backlog-test-2.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

DOTBUBL_DIR="/Users/santiago/Desktop/github/dotbubl/.worktrees/backlog-skill-impl"  # this plan's active worktree — NOT the main checkout, which won't have this branch's skill content until merged
SCRATCH="$(mktemp -d)"
cd "$SCRATCH"
git init -q

claude --plugin-dir "$DOTBUBL_DIR" --permission-mode acceptEdits -p "Log a backlog todo. Title: Add dark mode toggle. Type: feature. Priority: P1. Tags: tui. Description: Users want a dark mode toggle in settings. Acceptance criteria: Toggle persists across sessions."

FILE=$(find backlog -maxdepth 1 -name '0001-*.md' | head -n1)
if [[ -z "$FILE" ]]; then
  echo "FAIL: no backlog/0001-*.md file was created"
  exit 1
fi

for pattern in \
  '^id: 1$' \
  '^title: Add dark mode toggle$' \
  '^type: feature$' \
  '^priority: P1$' \
  'tui'
do
  grep -qE "$pattern" "$FILE" || { echo "FAIL: missing pattern '$pattern' in $FILE"; cat "$FILE"; exit 1; }
done
echo "PASS"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `chmod +x /tmp/backlog-test-2.sh && /tmp/backlog-test-2.sh`
Expected: FAIL — `skills/backlog/SKILL.md` has no creation behavior yet, so no file gets written (or one gets written with a shape the skill invented on its own, not matching the required frontmatter).

- [ ] **Step 3: Write minimal implementation**

Append to `skills/backlog/SKILL.md`:

```markdown
## Creating an item — explicit ask

When the user says they want to log a new todo/idea: gather, conversationally,
whatever of these isn't already given — title, `type`, `priority` (ask
directly, never default), `tags`, description, acceptance criteria. Compute
the next id and slug per "Item files" above, write
`backlog/NNNN-slug.md` with the frontmatter + body shape shown above, then
confirm what was added (id, title, path).

No separate confirmation gate is needed here — the user initiated this
directly and was present for the conversational gathering.
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/tmp/backlog-test-2.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add skills/backlog/SKILL.md
git commit -m "backlog skill: explicit-ask creation"
```

---

### Task 3: Deferred-task creation with confirmation gate

**Files:**
- Modify: `skills/backlog/SKILL.md`

**Interfaces:**
- Consumes: the id/slug/location mechanics from Task 1, and the frontmatter/body shape from Task 2 — same write behavior, gated by an extra confirm-then-yes step.
- Produces: creation behavior for trigger 2. Task 4 adds the remaining behavioral piece (completion/deletion); Task 5 only touches version numbers, not `SKILL.md` content.

- [ ] **Step 1: Write the failing test**

Create `/tmp/backlog-test-3.sh`. This tests the gate itself: turn 1 must NOT write a file (only propose + ask), turn 2 (after approval) must write it. Uses `--continue` to keep both turns in the same session/cwd:

```bash
#!/usr/bin/env bash
set -euo pipefail

DOTBUBL_DIR="/Users/santiago/Desktop/github/dotbubl/.worktrees/backlog-skill-impl"  # this plan's active worktree — NOT the main checkout, which won't have this branch's skill content until merged
SCRATCH="$(mktemp -d)"
cd "$SCRATCH"
git init -q

claude --plugin-dir "$DOTBUBL_DIR" --permission-mode acceptEdits -p "While reviewing this code you noticed the create_user function doesn't validate the email field format or check for empty password values before hashing. That's worth fixing but out of scope for this PR — propose deferring it as a follow-up: type chore, priority P2, tag validation. I approve deferring it."

if find backlog -maxdepth 1 -name '*.md' 2>/dev/null | grep -q .; then
  echo "FAIL: a file was written before explicit go-ahead"
  exit 1
fi

claude --plugin-dir "$DOTBUBL_DIR" --permission-mode acceptEdits --continue -p "Yes, go ahead and add it."

FILE=$(find backlog -maxdepth 1 -name '0001-*.md' 2>/dev/null | head -n1)
if [[ -z "$FILE" ]]; then
  echo "FAIL: no file was written after explicit go-ahead"
  exit 1
fi

for pattern in '^type: chore$' '^priority: P2$' 'validation'; do
  grep -qE "$pattern" "$FILE" || { echo "FAIL: missing pattern '$pattern' in $FILE"; cat "$FILE"; exit 1; }
done
echo "PASS"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `chmod +x /tmp/backlog-test-3.sh && /tmp/backlog-test-3.sh`
Expected: FAIL — `skills/backlog/SKILL.md` has no trigger-2-specific behavior yet, so the gating (propose → wait → write only after a second, separate "go ahead") isn't implemented; the first `-p` call may write a file immediately using Task 2's explicit-ask path instead of holding off.

- [ ] **Step 3: Write minimal implementation**

Append to `skills/backlog/SKILL.md`:

```markdown
## Creating an item — deferred task identified mid-session

When Claude (or a subagent) identifies, during work, something that could be
tackled in a future PR/MR, and the user approves deferring it: draft title,
`type`, `priority`, `tags`, description, and acceptance criteria from the
conversation context that already exists. Then show a confirmation line and
wait for an explicit yes before doing anything else:

> Adding to backlog: "<title>" [<type> / <priority> / <tags>] — sound right?

Do not write the file until the user responds affirmatively to that specific
confirmation. Once confirmed, write it using the same id/slug/frontmatter
mechanics as the explicit-ask path above.
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/tmp/backlog-test-3.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add skills/backlog/SKILL.md
git commit -m "backlog skill: deferred-task creation with confirmation gate"
```

---

### Task 4: Completing an item (deletion)

**Files:**
- Modify: `skills/backlog/SKILL.md`

**Interfaces:**
- Consumes: the id/location mechanics from Task 1 (how to find `backlog/NNNN-*.md` for a given id).
- Produces: the completion path implied by the spec's "no status field — presence means open, delete on completion" rule. Note: the design spec establishes *that* completed items get deleted but doesn't pin down the exact user-facing phrase that triggers it — this task fills that gap with a direct, reasonable behavior (confirm-then-delete, mirroring Task 3's confirm pattern, since deletion is destructive).

- [ ] **Step 1: Write the failing test**

Create `/tmp/backlog-test-4.sh`. Seeds one item, asks to mark it done, expects a confirmation (file must still exist after turn 1), then confirms and expects the file gone:

```bash
#!/usr/bin/env bash
set -euo pipefail

DOTBUBL_DIR="/Users/santiago/Desktop/github/dotbubl/.worktrees/backlog-skill-impl"  # this plan's active worktree — NOT the main checkout, which won't have this branch's skill content until merged
SCRATCH="$(mktemp -d)"
cd "$SCRATCH"
git init -q
mkdir -p backlog

cat > backlog/0001-fix-flaky-login-test.md <<'EOF'
---
id: 1
title: Fix flaky login test
type: bug
priority: P2
tags: [ci]
created: 2026-08-01
---

## Description
The login test intermittently times out in CI.

## Acceptance Criteria
- [ ] Test passes 20/20 consecutive CI runs
EOF

claude --plugin-dir "$DOTBUBL_DIR" --permission-mode acceptEdits -p "Backlog item 1 is done, the fix shipped."

if [[ ! -f backlog/0001-fix-flaky-login-test.md ]]; then
  echo "FAIL: file was deleted before explicit go-ahead"
  exit 1
fi

claude --plugin-dir "$DOTBUBL_DIR" --permission-mode acceptEdits --continue -p "Yes, remove it."

if [[ -f backlog/0001-fix-flaky-login-test.md ]]; then
  echo "FAIL: file still exists after explicit go-ahead"
  exit 1
fi
echo "PASS"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `chmod +x /tmp/backlog-test-4.sh && /tmp/backlog-test-4.sh`
Expected: FAIL — `skills/backlog/SKILL.md` has no completion behavior yet, so the file is never deleted (the first assertion may pass by accident, but the second will fail).

- [ ] **Step 3: Write minimal implementation**

Append to `skills/backlog/SKILL.md`:

```markdown
## Completing an item

When the user indicates a backlog item is done (e.g. "mark #3 done", "that
backlog item is finished", "the fix shipped"): find `backlog/NNNN-*.md` for
that id, show a confirmation line — `Remove backlog item #<id> "<title>"? —
it's assumed shipped/recorded elsewhere (e.g. the changelog), not archived
here.` — and wait for an explicit yes. Once confirmed, delete the file. There
is no status field and no archive: a completed item's only record after this
point is your changelog/commit history, not the backlog.
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/tmp/backlog-test-4.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add skills/backlog/SKILL.md
git commit -m "backlog skill: completion (confirm-then-delete)"
```

---

### Task 5: Version bump and full validation

**Files:**
- Modify: `.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

**Interfaces:**
- Consumes: nothing new — this task only bumps metadata so installed copies of the plugin notice the new skill exists.

- [ ] **Step 1: Bump `plugin.json`**

In `.claude-plugin/plugin.json`, change `"version": "0.1.0"` to `"version": "0.2.0"`.

- [ ] **Step 2: Bump `marketplace.json`**

In `.claude-plugin/marketplace.json`, change the `plugins[0].version` field from `"0.1.0"` to `"0.2.0"` (same value as Step 1 — keep them in sync).

- [ ] **Step 3: Validate structure**

Run: `claude plugin validate .`
Expected: `✔ Validation passed`

- [ ] **Step 4: Re-run all four smoke tests together**

Run:
```bash
/tmp/backlog-test-1.sh && /tmp/backlog-test-2.sh && /tmp/backlog-test-3.sh && /tmp/backlog-test-4.sh
```
Expected: all four print `PASS`, confirming the version bump didn't break anything and all four behaviors (query, explicit-ask, deferred-with-confirmation, completion) still work together.

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "Bump version to 0.2.0 for the backlog skill"
```

---

## After this plan

Push the branch and open a PR (same flow as the plugin scaffold and CLAUDE.md changes) — not part of this plan's tasks, handled via `superpowers:finishing-a-development-branch` when the human decides to.
