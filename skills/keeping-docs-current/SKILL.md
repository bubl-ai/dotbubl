---
name: keeping-docs-current
description: Use when checking whether CLAUDE.md, README.md, or any docs they reference are stale relative to a branch's diff against a given base ref. Dispatches the shared guideline-check subagent to do the actual analysis and reports what it finds — never edits docs itself. Needs a base ref supplied by the caller; does not auto-detect one.
---

# keeping-docs-current

Checks whether this project's documentation — starting at `CLAUDE.md` and
`README.md`, following whatever they reference — still matches the code,
relative to a base ref you're given. You never read the diff or the docs
yourself and never edit anything: you dispatch the shared `guideline-check`
subagent to do the actual analysis, then relay what it reports.

## What you need before you can run

A base ref to diff against (e.g. `main`, a commit SHA) — supplied by
whoever invoked you, as part of the request (e.g. "check docs against
main"). Never auto-detect one yourself, and never default to something
like `HEAD~1` if none was given — ask for one instead. (Auto-detecting the
base ref is `before-pr-checks`'s job, not this skill's.)

## What you do

1. Use the `Agent` tool with `subagent_type: "guideline-check"`, passing
   this prompt verbatim, with `<BASE_REF>` replaced by the ref you were
   given:

   ```
   Check whether this repository's documentation is stale relative to the
   changes between <BASE_REF> and the current working tree.

   Doc scope: start with CLAUDE.md and README.md. If either references
   other doc files (links, "see X.md" mentions, a docs/ folder), follow
   those references too, using your own Read/Grep/Glob — don't wait to be
   told where they are.

   What counts as stale:
   - A path or file the docs mention that no longer exists
   - A count or list the docs state that no longer matches reality
   - Described behavior that no longer matches what the code does
   - A doc referencing another doc file that's been deleted or moved

   Use Bash to run git diff/git log against <BASE_REF> to see what
   changed, scoped to that diff — don't flag pre-existing staleness the
   diff doesn't touch. If <BASE_REF> is invalid or the diff command
   fails, report that as an error in your final message rather than an
   empty findings list.

   Report via ReportFindings. For each finding:
   - file: the stale doc's path
   - summary: one-line staleness claim
   - failure_scenario: what changed in the code vs. what the doc still
     claims (a drift description, not a crash scenario)
   - category: "doc-staleness"

   If nothing is stale, call ReportFindings with an empty findings list.
   ```

2. Relay the subagent's final-message determination back to whoever
   invoked you, as reported — don't add your own judgment about whether
   the docs are actually stale, and don't edit any files yourself.
