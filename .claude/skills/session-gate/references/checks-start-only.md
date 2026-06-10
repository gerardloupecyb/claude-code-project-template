# Checks START-only (2, 3, 12, 13, 14)

Run each applicable check using `Read` and `Grep` on the relevant files. All checks are mechanical — no semantic judgment.

---

### Check 2 — Last session age (START) — informational

Find the line matching (case-insensitive) `Dernière session`. Extract the
YYYY-MM-DD date. Calculate days since that date.

Display: `[--] "Dernière session" YYYY-MM-DD (N days ago)`

If date is not parsable as YYYY-MM-DD: `[!!] "Dernière session" date not parsable`

---

### Check 3 — Deviations cleared (START)

Find the section matching (case-insensitive) `Déviations d'exécution`.
In that section, find lines containing `|`. Skip the first 2 such lines
(table header + separator row). Count remaining `|`-lines as deviation entries.

If count > 0: `[!!] "Déviations d'exécution" has N entries — clear them`
If count == 0: `[ok] "Déviations d'exécution" cleared`

---

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

---

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

---

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
