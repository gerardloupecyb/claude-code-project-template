# Checks END-only (6, 7, 9, 10, 16, 17, 18, 19, 20, 21, 22)

Run each applicable check using `Read`, `Grep`, and `Bash` tools. All checks are mechanical — no semantic judgment.

---

### Check 6 — "Dernière session" is today (END)

Find the line matching (case-insensitive) `Dernière session`. Extract the
YYYY-MM-DD date. Compare to today's date.

If not today: `[!!] "Dernière session" is YYYY-MM-DD, not today — update it`
If today: `[ok] "Dernière session" is today`

---

### Check 7 — MEMORY.md staged with code (END)

Run `git status --porcelain`. Check:
- If no files are staged at all: skip this check (not applicable)
- If files are staged but memory/MEMORY.md is NOT staged:
  `[!!] Files are staged but MEMORY.md is not — stage it with the code`
- If MEMORY.md is staged: `[ok] MEMORY.md staged with code`

---

### Check 9 — COT plan presence in modified plan files (END)

Run `git diff --name-only HEAD` and check if any file matching `docs/plans/*-plan.md`
was modified. If no plan file was modified, skip this check (not applicable).

If a plan file was modified, extract its path and run `grep -q "<plan>" <path>`.

- If `<plan>` tag found: `[ok] COT plan block present in <filename>`
- If `<plan>` tag NOT found:
  `[!!] <filename> modified but no <plan> block — add reasoning retroactively`

Note: only check files matching `docs/plans/*-plan.md` pattern.
If multiple plan files were modified, check each one.

---

### Check 10 — LESSONS.md quality (END) — informational

If Check 8 passed (LESSONS.md exists and is non-empty), count `### ` headings
in the file outside HTML comment blocks (`<!-- ... -->`).

- If count >= 3: `[--] LESSONS.md has N lesson entries`
- If count < 3: `[--] LESSONS.md has only N entries (< 3) — consider running /lesson`

This check is always informational (`[--]`), never blocking.
Skip this check if Check 8 failed (file missing or empty).

---

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

---

### Check 17 — Duplicate "Ce qui a été fait" headings (END) — informational

Find the section matching (case-insensitive) `Ce qui a été fait`.
Extract all `###` headings within that section (stop at the next `## ` heading).

Compare headings: two headings are duplicates if they match exactly
(after trimming whitespace).

- If duplicates found: `[--] "Ce qui a été fait" has duplicate entries: "{heading}" — merge them`
- If no duplicates: skip (not applicable)

---

### Check 18 — Open blockers reminder (END) — informational

Find the section matching (case-insensitive) `Blocages et questions ouvertes`.
Count lines matching `- [ ]` (unchecked items) within that section
(stop at the next `## ` heading or `---`).

Exclude lines containing `Aucun blocage` (template default).

- If count > 0: `[--] N open blocker(s) remain — verify if still relevant after this session`
- If count == 0: skip (not applicable)

---

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

---

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

---

### Check 21 — Agent spawn audit (END) — informational

Read `.claude/workspace/agent-log.txt` if it exists.
Count the number of lines (= agent spawns this session, reset at start).

`[--] {N} agents spawned this session`

If N > 15: `[!!] Unusually high agent count ({N}) — possible drift`
If file absent or empty: `[--] 0 agents spawned (or log not initialized)`

---

### Check 22 — GOVERNANCE.md freshness (END) — informational

Read `docs/GOVERNANCE.md`. Check that it was modified within the last 30 days
(by reading the frontmatter `date:` field or by checking git log on the file).
If the date is more than 30 days old AND significant governance changes happened
in session (new standards, new registers, new risk docs), emit:
`WARN: docs/GOVERNANCE.md may be stale — last updated: {date}. Update if new governance docs were created this session.`
This is advisory only, never blocking.
