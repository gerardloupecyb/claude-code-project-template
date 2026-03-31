---
name: sparc
description: >
  Micro-execution methodology for complex tasks INSIDE a GSD phase.
  SPARC = Specification, Pseudocode, Architecture, Refinement, Completion.
  Invoke explicitly with /sparc "description". Works standalone too.
  Triggers on: sparc, micro-execution, phase execution, execute task.
---

# SPARC — Micro-Execution for Complex Tasks

Structured 5-phase execution for tasks inside a GSD phase (or standalone).
SPARC does NOT wrap `/gsd:execute-phase` — it is an independent skill.
Phase 4 delegates to GSD standard execution.

---

## Entry Points

| Trigger | When | Context |
|---------|------|---------|
| After `/prepare-phase` GO | Default for any GSD phase task | PLAN.md + ACs in `.planning/` |
| `/sparc "description"` standalone | Complex isolated task | SPARC asks for context if needed |

**Default in phase**: Use SPARC for all GSD phase tasks unless user explicitly invokes `/gsd:fast`.

---

## Phase 1 — Specification

Spawn agent `spec-writer` (ref: `.claude/rules/swarm-patterns.md`, tier 2):

- Input: task description + phase ACs (from `.planning/`)
- Output: detailed requirements + measurable ACs
- Write to: `.claude/workspace/sparc-spec.md`

**Validation**: Show spec to user. Wait for confirmation before Phase 2.

---

## Phase 2 — Pseudocode

Spawn agent `logic-planner` (ref: swarm-patterns.md, tier 2):

- Input: spec from Phase 1
- Output: high-level logic + TDD anchors (which tests to write first)
- Write to: `.claude/workspace/sparc-pseudo.md`

**Validation**: Show pseudocode to user. Wait for confirmation before Phase 3.

---

## Phase 3 — Architecture (dual-agent)

Spawn 2 agents IN PARALLEL (ref: swarm-patterns.md):

- `architect` (tier 3): propose optimal design based on spec + pseudo
- `critic` (tier 3): receives same input, finds flaws, alternatives, simplifications

If `docs/architecture/contexts.md` exists: pass it to both agents as constraint.

Claude principal synthesizes both outputs.
- Write to: `.claude/workspace/sparc-arch.md`

**Validation**: Show architecture to user. Wait for confirmation before Phase 4.
If architect and critic contradict: surface the contradiction clearly and ask user to arbitrate.

---

## Phase 4 — Refinement (implementation)

Ask user once:

```
Implement with: (A) Claude Code [default] or (B) Codex (/codex:rescue)?
```

**Option A (default)**: GSD standard execution applies.
- Rules in `.claude/rules/execution-quality.md` apply automatically
- TDD: write tests first (anchors from Phase 2), then implement
- Commit per logical unit (ref: execution-quality.md commit heuristics)

**Option B (Codex)**: Pass Phase 1-3 workspace files as context to Codex:
```
/codex:rescue "implement based on .claude/workspace/sparc-spec.md, sparc-pseudo.md, sparc-arch.md"
```

---

## Phase 5 — Completion (dual review)

Launch 2 reviews AUTOMATICALLY IN PARALLEL:

**Review A — CE:review** (multi-agent, Claude):
- Reviews produced code against Phase 1 ACs
- Checks: architecture, patterns, code quality, maintainability

**Review B — Codex adversarial**:
```bash
/codex:adversarial-review --background --base main
```
- Challenges: design approach, tradeoffs, risks
- Skip silently if Codex not installed

Claude synthesizes both reviews → **GO / NO-GO verdict**:
- **GO**: task complete, close associated todos
- **NO-GO**: return to Phase 4 with specific findings from both reviews

Close associated todos with `/todo close {ID}` on GO.

---

## Skip Rules

- Skip Phase 2 (Pseudocode) for tasks with obvious logic (CRUD, simple config)
- Skip Phase 3 (Architecture) for trivial implementation tasks
- Skip Phase 5 Codex review if Codex not installed (CE:review still runs)
- Never auto-chain without user validation between phases (except Phase 5 which runs automatically after Phase 4)

## What SPARC Does NOT Do

- Replace GSD (SPARC lives INSIDE a GSD phase)
- Force all phases (explicit skip is valid)
- Wrap or modify `/gsd:execute-phase`
- Auto-proceed without user validation (except Phase 5)
