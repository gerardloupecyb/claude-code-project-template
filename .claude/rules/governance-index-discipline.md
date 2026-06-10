---
description: governance index co-update discipline
paths:
  - docs/standards/*.md
  - docs/registers/*.md
  - docs/risk/*.md
  - docs/procedures/*.md
  - docs/playbooks/*.md
  - docs/architecture/security/*.md
  - .claude/rules/*.md
  - .claude/skills/*/SKILL.md
---

# Governance Index Discipline

> Path-scoped soft rule. Fires when Claude opens a file matching the paths above.
> Enforces `docs/GOVERNANCE.md` as the canonical governance index.

## The Co-Update Obligation

When a file matching the paths above is **created or superseded**, `docs/GOVERNANCE.md`
must be updated in the **same commit**. No exceptions.

## Format for a New Entry

Add a row to the nearest relevant section in GOVERNANCE.md:

```
| [`path/to/file.md`](relative/link.md) | One-line description of purpose | version or status |
```

- Relative link from `docs/` — e.g. `standards/new-standard.md`
- Description: one line, purpose-first, no verbs like "contains" or "covers"
- Version: semver, date, or status word (Active / Draft / Promoting)

## For Superseded Documents

In GOVERNANCE.md, add `[SUPERSEDED by X]` after the description and link to the replacement:

```
| [`docs/old.md`](old.md) | Old purpose [SUPERSEDED by [`docs/new.md`](new.md)] | v1.0 |
```

Do not delete the row — the audit trail is required.

## Scope

- **In scope:** Any `.md` file created or significantly revised under the watched paths
- **Out of scope:** Cosmetic edits, typo fixes, frontmatter-only updates, file deletions

## What NOT to do

- Do not duplicate document content in GOVERNANCE.md — it is an index only
- Do not create a new GOVERNANCE section for a single document — use the nearest existing section
- Do not skip the co-update because the document is "temporary" or "draft"

## When a Section Doesn't Fit

If the document genuinely does not fit any existing section, add a new
`## Section Name {#anchor}` to GOVERNANCE.md and mention it in the PR description.

## Relationship to governance.md

This rule is narrower than `.claude/rules/governance.md` (which covers file ownership
and co-update obligations broadly). This rule targets the governance index specifically
and fires on the path-scoped trigger above.
