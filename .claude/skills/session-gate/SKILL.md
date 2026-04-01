---
name: session-gate
description: "Validation mécanique de l'état de session (MEMORY.md). This skill should be used when validating session state at boundaries. Triggers on: session gate, valider la session, vérifier mémoire, état de la session. Also invoked explicitly with /session-gate."
---

# Session Gate — Validation mécanique de MEMORY.md

Verify that memory/MEMORY.md follows the template rules mechanically.
Read-only, advisory, stateless. Never modify files. Never block the session.

---

## Invocation

| Command | Mode | Checks |
|---|---|---|
| `/session-gate start` | START | 1, 2, 3, 4, 5, 8, 11, 12, 13, 14, 15 |
| `/session-gate end` | END | 1, 4, 5, 6, 7, 8, 9, 10, 11, 15, 16, 17, 18, 19, 20, 21 |
| `/session-gate` (no arg) | BOTH | All 21 |

---

## Pre-check: merge conflicts

Before running any check, scan memory/MEMORY.md for lines starting with
`<<<<<<<`, `=======`, or `>>>>>>>`. If found, report:

```
Session Gate — BLOCKED

  MEMORY.md contains unresolved merge conflicts. Resolve them before continuing.
```

Skip all remaining checks.

---

## The 21 Checks

Run each applicable check. Use `Read` and `Grep` tools on memory/MEMORY.md
and `Bash` for git status. All checks are mechanical — no semantic judgment.

### Check 1 — MEMORY.md exists and is non-empty (START, END)

Read memory/MEMORY.md. Verify:
- File exists
- File contains at least one markdown heading (`^#`)

If missing or empty: `[!!] MEMORY.md missing or empty — create from template`

### Check 2 — Last session age (START) — informational

Find the line matching (case-insensitive) `Dernière session`. Extract the
YYYY-MM-DD date. Calculate days since that date.

Display: `[--] "Dernière session" YYYY-MM-DD (N days ago)`

If date is not parsable as YYYY-MM-DD: `[!!] "Dernière session" date not parsable`

### Check 3 — Deviations cleared (START)

Find the section matching (case-insensitive) `Déviations d'exécution`.
In that section, find lines containing `|`. Skip the first 2 such lines
(table header + separator row). Count remaining `|`-lines as deviation entries.

If count > 0: `[!!] "Déviations d'exécution" has N entries — clear them`
If count == 0: `[ok] "Déviations d'exécution" cleared`

### Check 4 — "Ce qui a été fait" capped at 5 (START, END)

Find the section matching (case-insensitive) `Ce qui a été fait`.
Count `###` headings within that section (stop at the next `## ` heading).

If count > 5: `[!!] "Ce qui a été fait" has N entries (max 5) — archive older ones`
If count <= 5: `[ok] "Ce qui a été fait": N/5`

### Check 5 — "Prochaine étape" present (START, END)

Find the line matching (case-insensitive) `Prochaine étape`.
Verify it exists and does not contain `{{` (template placeholder).

If missing or placeholder: `[!!] "Prochaine étape" missing or still a placeholder`
If present: `[ok] "Prochaine étape" present`

### Check 6 — "Dernière session" is today (END)

Find the line matching (case-insensitive) `Dernière session`. Extract the
YYYY-MM-DD date. Compare to today's date.

If not today: `[!!] "Dernière session" is YYYY-MM-DD, not today — update it`
If today: `[ok] "Dernière session" is today`

### Check 7 — MEMORY.md staged with code (END)

Run `git status --porcelain`. Check:
- If no files are staged at all: skip this check (not applicable)
- If files are staged but memory/MEMORY.md is NOT staged:
  `[!!] Files are staged but MEMORY.md is not — stage it with the code`
- If MEMORY.md is staged: `[ok] MEMORY.md staged with code`

### Check 8 — LESSONS.md exists and is non-empty (START, END)

Read LESSONS.md. Verify:
- File exists
- File contains at least one markdown heading (`^#`)

If missing or empty: `[!!] LESSONS.md missing or empty — create from template`
If present: `[ok] LESSONS.md exists and is non-empty`

### Check 9 — COT plan presence in modified plan files (END)

Run `git diff --name-only HEAD` and check if any file matching `docs/plans/*-plan.md`
was modified. If no plan file was modified, skip this check (not applicable).

If a plan file was modified, extract its path and run `grep -q "<plan>" <path>`.

- If `<plan>` tag found: `[ok] COT plan block present in <filename>`
- If `<plan>` tag NOT found:
  `[!!] <filename> modified but no <plan> block — add reasoning retroactively`

Note: only check files matching `docs/plans/*-plan.md` pattern.
If multiple plan files were modified, check each one.

### Check 10 — LESSONS.md quality (END) — informational

If Check 8 passed (LESSONS.md exists and is non-empty), count `### ` headings
in the file outside HTML comment blocks (`<!-- ... -->`).

- If count >= 3: `[--] LESSONS.md has N lesson entries`
- If count < 3: `[--] LESSONS.md has only N entries (< 3) — consider running /lesson`

This check is always informational (`[--]`), never blocking.
Skip this check if Check 8 failed (file missing or empty).

### Check 11 — DECISIONS.md exists and is non-empty (START, END)

Read DECISIONS.md. Verify:
- File exists
- File contains at least one markdown heading (`^#`)

If missing or empty: `[!!] DECISIONS.md missing or empty — create from template`
If present: `[ok] DECISIONS.md exists and is non-empty`

### Check 12 — Stale decisions (START) — informational

If Check 11 passed (DECISIONS.md exists), scan for stale active decisions.

For each `### DEC-` heading in DECISIONS.md:
1. Extract the `**Statut:**` value within that section (stop at next `### ` heading)
2. If Statut contains `ACCEPTED`, extract the `**Date:**` value
3. Parse the date using pattern `\d{4}-\d{2}-\d{2}` (rejects literal YYYY-MM-DD)
4. Calculate days since date

Count entries where Statut is ACCEPTED and date > 30 days.

- If count > 0: `[--] N active decisions are > 30 days old — verify if still valid`
- If count == 0 or no ACCEPTED entries: skip (not applicable)

Skip this check if Check 11 failed (file missing or empty).

### Check 13 — LESSONS.md last entry age (START) — informational

If Check 8 passed (LESSONS.md exists), find the most recent lesson date.

Skip lines between `<!--` and `-->` markers (inclusive).
Then find all lines matching `_Date: \d{4}-\d{2}-\d{2}` in LESSONS.md.
The `\d{4}-\d{2}-\d{2}` pattern naturally rejects the literal `YYYY-MM-DD`
in the template comment block. Heritage entries use
`_Date: YYYY-MM-DD | Heritage: {source}_` — the regex matches the first
date pattern, ignoring trailing content.

Extract the most recent date.

- If most recent > 14 days ago: `[--] Last lesson captured N days ago — consider /lesson if any fixes were made`
- If <= 14 days or no entries: skip (not applicable)

Skip this check if Check 8 failed (file missing or empty).

### Check 14 — Reference files staleness (START) — informational

If `docs/references/` directory exists, scan each `.md` file in it.
For each file:
1. Find the line matching `_Last verified: ` (italic markdown)
2. Extract the YYYY-MM-DD date (reject literal `{{DATE}}` as unpopulated template)
3. Calculate days since that date

Report per file:
- If date > 30 days ago: `[--] {filename} last verified N days ago — consider /reference-audit`
- If date is `{{DATE}}` or not parsable: `[--] {filename} has no verification date — run /reference-audit`
- If date <= 30 days: skip (no report needed)

If `docs/references/` doesn't exist: skip this check entirely (not applicable).

### Check 15 — MCP cross-reference sync (START, END) — informational

Cross-reference MCP entries between `.claude/rules/tool-routing.md` and
`docs/references/services-and-access.md`.

1. Read `.claude/rules/tool-routing.md`. In the "Discipline MCP" table,
   extract MCP names from column 1 (pattern: `mcp__*` or backtick-wrapped).
   Strip backticks. Collect into set A.

2. Read `docs/references/services-and-access.md`. In the "MCP Servers" table,
   extract MCP names from column 1. Strip backticks. Collect into set B.
   If file doesn't exist or table has only `{{` placeholders: skip this check.

3. Compute:
   - In A but not in B: MCPs in tool-routing without reference documentation
   - In B but not in A: MCPs in reference without routing discipline

Report:
- If any desyncs found: `[--] MCP desync: {N} in tool-routing without reference, {M} in reference without routing — run /reference-audit`
- If no desyncs: skip (no report needed)

Skip this check if either file doesn't exist or contains only template placeholders.

### Check 16 — Relative dates in MEMORY.md (END) — informational

Scan all content in memory/MEMORY.md for relative date expressions.
Match these patterns (case-insensitive, word boundaries):

- French: `hier`, `avant-hier`, `la semaine dernière`, `le mois dernier`,
  `la semaine passée`, `le mois passé`
- English: `yesterday`, `last week`, `last month`

Exclude matches inside HTML comments (`<!-- ... -->`).
Exclude matches in section headers (lines starting with `#`).
Exclude the literal word "aujourd'hui" / "today" (acceptable in context of current session).

- If matches found: `[--] MEMORY.md contains N relative date(s) — convert to absolute (YYYY-MM-DD)`
  List each match with line context (truncated to 60 chars).
- If no matches: skip (not applicable)

### Check 17 — Duplicate "Ce qui a été fait" headings (END) — informational

Find the section matching (case-insensitive) `Ce qui a été fait`.
Extract all `###` headings within that section (stop at the next `## ` heading).

Compare headings: two headings are duplicates if they match exactly
(after trimming whitespace).

- If duplicates found: `[--] "Ce qui a été fait" has duplicate entries: "{heading}" — merge them`
- If no duplicates: skip (not applicable)

### Check 18 — Open blockers reminder (END) — informational

Find the section matching (case-insensitive) `Blocages et questions ouvertes`.
Count lines matching `- [ ]` (unchecked items) within that section
(stop at the next `## ` heading or `---`).

Exclude lines containing `Aucun blocage` (template default).

- If count > 0: `[--] N open blocker(s) remain — verify if still relevant after this session`
- If count == 0: skip (not applicable)

### Check 19 — Persistent docs frontmatter (END) — informational

Run `git diff --name-only HEAD` and collect modified files matching:
- `docs/plans/*.md`
- `docs/brainstorms/*.md`
- `docs/architecture/*.md`

If none were modified: skip (not applicable).

For each modified file:
1. Verify the file starts with a frontmatter block:
   - first line is `---`
   - a closing `---` exists before the first markdown heading
2. Verify required keys by path:
   - `docs/plans/*.md` → `title:`, `type:`, `status:`, `date:`
   - `docs/brainstorms/*.md` → `date:`, `topic:`
   - `docs/architecture/*.md` → `title:`, `type:`, `status:`, `date:`

Output:
- `[ok] <file> has valid frontmatter`
- `[!!] <file> missing frontmatter`
- `[!!] <file> missing required key(s): <list>`

This check is mechanical only. Do not validate semantic quality.

### Check 20 — Pre-flight enforcement (END)

Look for PLAN files in both possible paths:
- `.planning/{phase}-*-PLAN.md`
- `.planning/milestones/{milestone}/{phase}-*-PLAN.md`

If at least one `*-PLAN.md` exists for the current phase:
  Look for a `*-PREFLIGHT.md` in the SAME directory as the PLAN file.
  If absent: `[!!] Phase {N} has a PLAN but no PREFLIGHT — /pre-flight was skipped`

If a `*-PREFLIGHT.md` exists, grep `Verdict:` in the file:
  If contains `NO-GO` and no newer `*-PREFLIGHT.md` (by mtime) contains `GO` or `CONDITIONAL GO`:
  `[!!] Phase {N} PREFLIGHT verdict was NO-GO and was not re-run after fixes`

If no PLAN files found: skip this check (not applicable to this session).
This check is mechanical only — file existence and grep, no semantic judgment.

### Check 21 — Agent spawn audit (END) — informational

Read `.claude/workspace/agent-log.txt` if it exists.
Count the number of lines (= agent spawns this session, reset at start).

`[--] {N} agents spawned this session`

If N > 15: `[!!] Unusually high agent count ({N}) — possible drift`
If file absent or empty: `[--] 0 agents spawned (or log not initialized)`


---

## Output format

```
Session Gate — {MODE}

  [ok]  MEMORY.md exists and is non-empty
  [--]  "Dernière session" 2026-03-10 (1 day ago)
  [!!]  "Déviations d'exécution" has 2 entries — clear them
  [ok]  "Ce qui a été fait": 3/5
  [ok]  "Prochaine étape" present
  [ok]  LESSONS.md exists and is non-empty
  [ok]  COT plan block present in 2026-03-16-001-...-plan.md
  [--]  LESSONS.md has only 2 entries (< 3) — consider running /lesson

  1 issue found. Fix before continuing.
```

Legend: `[ok]` = pass, `[!!]` = action required, `[--]` = informational.

If any `[!!]` checks exist, report count and recommend fixing.
If no `[!!]` checks, end with: "All clear."

---

## What this skill does NOT do

- Modify any file (read-only, like pre-flight)
- Block the session (advisory only — user decides)
- Judge content quality ("is this next step good?")
- Read STATE.md (no coupling with GSD)
- Require state between invocations (stateless)
