---
name: todo
description: >
  CRUD operations for the todos/ directory. Encapsulates ID sequencing,
  file movement, and validation. Use instead of direct Write/Edit to todos/.
  Triggers on: /todo, todo create, todo close, todo done, todo validate, todo list.
---

# Todo — Encapsulated CRUD for todos/

All todo operations go through this skill. Never write directly to `todos/` with
Write or Edit — use `/todo` instead. This ensures sequential IDs and clean state.

---

## Directory Structure

```
todos/
  pending/    ← active todos
  complete/   ← done, not yet verified
  done/       ← verified complete
```

---

## Actions

### `/todo create "description"`

1. List all files in `todos/pending/`, `todos/complete/`, `todos/done/`
2. Extract numeric IDs from filenames (pattern: `{ID}-*.md`)
3. Find max ID across all three directories; next ID = max + 1 (start at 1 if empty)
4. Write `todos/pending/{ID}-{slug}.md` where slug = kebab-case of description (max 40 chars)

Frontmatter:
```yaml
---
id: {ID}
title: "{description}"
status: pending
phase: {current GSD phase if known, else "—"}
created_at: {today YYYY-MM-DD}
---
```

### `/todo close {ID}`

1. Find `todos/pending/{ID}-*.md` — error if not found
2. Run `git mv todos/pending/{ID}-*.md todos/complete/{ID}-*.md`
3. Update frontmatter: `status: complete`, add `completed_at: {today}`

### `/todo done {ID}`

1. Find `todos/complete/{ID}-*.md` — error if not in complete/ (must be closed first)
2. Run `git mv todos/complete/{ID}-*.md todos/done/{ID}-*.md`
3. Update frontmatter: `status: done`, add `verified_at: {today}`

### `/todo validate`

Scan all three directories. Report:
- Duplicate IDs (same ID in multiple files)
- ID gaps (missing IDs in sequence)
- Files in wrong directory vs their `status:` frontmatter field
- Files missing required frontmatter keys (id, title, status, created_at)

Output format:
```
Todo Validate
  [ok]  No duplicate IDs
  [!!]  ID gap: 3 is missing
  [!!]  todos/pending/5-foo.md has status: complete — should be in complete/
  [ok]  All frontmatter keys present
```

### `/todo list`

Display pending todos grouped by phase, with counts:

```
Todo List — {date}

  Phase {N}: {phase name}
    [{ID}] {title}
    [{ID}] {title}

  Summary: {P} pending / {C} complete / {D} done
```

---

## SPARC Integration

SPARC Phase 5 (Completion) runs `/todo close {ID}` on the task's todos when
the GO verdict is issued.

---

## What this skill does NOT do

- Modify todo content (descriptions, notes) — edit the file directly
- Delete todos — move to done/ instead (audit trail)
- Work with TodoWrite tool (that's for Claude's internal session tracking, not todos/)
