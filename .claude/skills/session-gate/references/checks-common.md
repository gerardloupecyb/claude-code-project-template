# Checks communs — START et END (1, 4, 5, 8, 11, 15)

Run each applicable check using `Read` and `Grep` on memory/MEMORY.md. All checks are mechanical — no semantic judgment.

---

### Check 1 — MEMORY.md exists and is non-empty (START, END)

Read memory/MEMORY.md. Verify:
- File exists
- File contains at least one markdown heading (`^#`)

If missing or empty: `[!!] MEMORY.md missing or empty — create from template`

---

### Check 4 — "Ce qui a été fait" capped at 5 (START, END)

Find the section matching (case-insensitive) `Ce qui a été fait`.
Count `###` headings within that section (stop at the next `## ` heading).

If count > 5: `[!!] "Ce qui a été fait" has N entries (max 5) — archive older ones`
If count <= 5: `[ok] "Ce qui a été fait": N/5`

---

### Check 5 — "Prochaine étape" present (START, END)

Find the line matching (case-insensitive) `Prochaine étape`.
Verify it exists and does not contain `{{` (template placeholder).

If missing or placeholder: `[!!] "Prochaine étape" missing or still a placeholder`
If present: `[ok] "Prochaine étape" present`

---

### Check 8 — LESSONS.md exists and is non-empty (START, END)

Read LESSONS.md. Verify:
- File exists
- File contains at least one markdown heading (`^#`)

If missing or empty: `[!!] LESSONS.md missing or empty — create from template`
If present: `[ok] LESSONS.md exists and is non-empty`

---

### Check 11 — DECISIONS.md exists and is non-empty (START, END)

Read DECISIONS.md. Verify:
- File exists
- File contains at least one markdown heading (`^#`)

If missing or empty: `[!!] DECISIONS.md missing or empty — create from template`
If present: `[ok] DECISIONS.md exists and is non-empty`

---

### Check 15 — MCP cross-reference sync (START, END) — informational

Cross-reference MCP entries between `.claude/rules/tool-routing.md` and
`docs/codebase/services-and-access.md`.

1. Read `.claude/rules/tool-routing.md`. In the "Discipline MCP" table,
   extract MCP names from column 1 (pattern: `mcp__*` or backtick-wrapped).
   Strip backticks. Collect into set A.

2. Read `docs/codebase/services-and-access.md`. In the "MCP Servers" table,
   extract MCP names from column 1. Strip backticks. Collect into set B.
   If file doesn't exist or table has only `{{` placeholders: skip this check.

3. Compute:
   - In A but not in B: MCPs in tool-routing without reference documentation
   - In B but not in A: MCPs in reference without routing discipline

Report:
- If any desyncs found: `[--] MCP desync: {N} in tool-routing without reference, {M} in reference without routing — run /reference-audit`
- If no desyncs: skip (no report needed)

Skip this check if either file doesn't exist or contains only template placeholders.
