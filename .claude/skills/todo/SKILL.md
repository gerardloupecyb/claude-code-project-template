---
name: todo
description: >
  CRUD operations for the .planning/todos/ directory. Encapsulates ID sequencing,
  file movement, and validation. Use instead of direct Write/Edit to .planning/todos/.
  Triggers on: /todo, todo create, todo close, todo done, todo validate, todo list, todo stale.
---

# Todo — Encapsulated CRUD for .planning/todos/

All todo operations go through this skill. Never write directly to `.planning/todos/` with
Write or Edit — use `/todo` instead. This ensures sequential IDs and clean state.

---

## Directory Structure

```
.planning/todos/
  pending/    ← active todos
  complete/   ← done, not yet verified
  done/       ← verified complete
```

---

## Actions

### `/todo create "description"`

**ID scheme: date-prefixed (collision-resistant across parallel branches).** The legacy
numeric `MAX+1` scheme computed the next ID from the *local branch's* view, so two branches
working in parallel both picked the same number and collided at merge (observed 2026-05-26:
~14 collisions across 16–24 branches — IDs 058–066, 071, 072, 093–095). Date-prefixed IDs
need no global counter, so parallel branches never collide.

1. `slug` = kebab-case of description (max 40 chars)
2. `id` = `{today YYYY-MM-DD}-{slug}` (e.g., `2026-05-27-fix-cascade-retry`)
3. If `.planning/todos/{pending,complete,done}/{id}.md` already exists (same date **and** same
   slug — rare), append `-2`, `-3`, … to the id to disambiguate
4. Write `.planning/todos/pending/{id}.md`

Frontmatter:
```yaml
---
id: {id}            # date-prefixed, e.g. 2026-05-27-fix-cascade-retry
title: "{description}"
status: pending
phase: "{XX.Y}"   # REQUIRED — GSD phase number (quoted, zero-padded: "04", "14", "04.2"). Standalone: "—"
created_at: {today YYYY-MM-DD}
---
```

> **Legacy numeric IDs** (pre-2026-05-27) stay as-is — found by slug, never reused, never
> renumbered (renumbering is futile: each lives on 16–24 branches and would re-collide at merge).
> `close` / `done` / `list` handle both schemes (they match the id arg as a filename substring).

> Format canonique et anti-patterns : voir `.claude/rules/todo-discipline.md` § "Todo-phase association".

> `{ID}` = the full id (date-prefixed `2026-05-27-slug` **or** legacy numeric `095`) or any unique
> filename substring. Match with `*{ID}*.md`; error if 0 matches (not found) or >1 (ambiguous — pass a longer id).

### `/todo close {ID}`

1. Find `.planning/todos/pending/*{ID}*.md` — error if 0 or >1 match
2. `git mv` it to `.planning/todos/complete/` (preserve the filename)
3. Update frontmatter: `status: complete`, add `completed_at: {today}`

### `/todo done {ID}`

1. Find `.planning/todos/complete/*{ID}*.md` — error if not in complete/ (must be closed first) or >1 match
2. `git mv` it to `.planning/todos/done/` (preserve the filename)
3. Update frontmatter: `status: done`, add `verified_at: {today}`

### `/todo validate`

Scan all three directories. Report:
- Duplicate ids (same id in multiple files) — **legacy numeric collisions are known/harmless** (see create note, ~14 pre-2026-05-27); flag only NEW date-prefixed dups
- Files in wrong directory vs their `status:` frontmatter field
- Files missing required frontmatter keys (id, title, status, created_at)

> No "ID gap" check — date-prefixed ids have no sequence, and legacy numeric gaps are expected.

Output format:
```
Todo Validate
  [ok]  No new duplicate ids (N legacy numeric collisions — known, harmless)
  [!!]  .planning/todos/pending/5-foo.md has status: complete — should be in complete/
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

### `/todo stale`

Cross-reference pending todos against completed phases in ROADMAP.md. Reports todos whose `phase:` matches a `[x]` phase.

**Algorithm:**

1. Parse `.planning/ROADMAP.md` — extract all phase numbers from `[x]` lines (regex: `^\- \[x\] \*\*Phase (\d+(?:\.\d+)?):`)
2. Scan `.planning/todos/pending/*.md` — extract `phase:` from each frontmatter
3. Match: if todo's phase is in the completed set → stale

**Output:**

```
Todo Stale Check — {date}

{count} stale todo(s) on completed phases:

  Phase {N} ({phase name}) — completed {date}
    [{ID}] {title}  →  close / reassign to Phase {X} / standalone

  No action needed:
    {count} pending todos on active/planned phases

  → /todo close {ID}          close a resolved todo
  → /todo list                full inventory
```

If 0 stale: `✓ No stale todos — all pending todos are on active or planned phases.`

---

## What this skill does NOT do

- Modify todo content (descriptions, notes) — edit the file directly
- Delete todos — move to done/ instead (audit trail)
- Work with TodoWrite tool (that's for Claude's internal session tracking, not .planning/todos/)
