---
name: prepare-phase
description: >
  Orchestrates the full phase preparation sequence in one command:
  discuss → plan → deepen? → pre-flight → report.
  Invoke with /prepare-phase {N} where N is the phase number.
  Triggers on: prepare-phase, prepare phase, phase preparation.
---

# Prepare Phase — Phase Preparation Orchestrator

Run the full preparation sequence for a GSD phase with one command.
Does NOT modify the underlying skills (GSD, CE, pre-flight) — calls them in sequence.
Does NOT launch execution — that's SPARC's job.

---

## Usage

```
/prepare-phase {N}
```

where N is the phase number (e.g., `/prepare-phase 1`).

---

## Sequence

### Step 0 — Context Capture (automatic)

Objective: capture everything needed during implementation *before* discussing
or planning. Principle: "if you would search for it during implementation, capture now."

Actions:

1. Read `CLAUDE.md` — extract stack, active tools, conventions
2. Read `LESSONS.md` — identify lessons relevant to the requested feature
3. Grep `.claude/rules/*.md` for rules applicable to the feature domain
4. Grep source files for patterns similar to the feature
   (limit to `.claude/`, project root, and `src/` — max 1 level deep)
5. Write `.claude/workspace/context-capture-{N}.md` with:
   - `## Stack détectée` — languages, frameworks, active MCPs
   - `## Patterns existants` — file:line + brief description
   - `## Conventions établies` — non-negotiable rules from CARL/rules
   - `## Gotchas documentés` — relevant LESSONS.md entries
   - `## Questions à lever` — ambiguities detected before discuss
6. Report: `Context capture → .claude/workspace/context-capture-{N}.md`
7. Pass this file path to Step 1 (discuss) as additional context

If LESSONS.md is empty or no patterns found: write empty sections, do not fail.
If CLAUDE.md is missing: skip actions 1 and 3, continue with what's available.

### Step 1 — Discuss Phase (automatic)

```
/gsd:discuss-phase {N}
```

Captures decisions and clarifies requirements before planning.
If this fails: stop, report error to user.

### Step 2 — Plan Phase (automatic)

```
/gsd:plan-phase {N}
```

Produces PLAN.md in `.planning/`.
If this fails: stop, report error to user.

### Step 3 — Deepen Plan? (ONE interaction)

Ask user once:

```
Plan ready. Deepen with /ce:deepen-plan? [Yes (recommended) / Skip]
```

- **Yes**: run `/ce:deepen-plan` on the produced PLAN.md — automatic
- **Skip**: proceed to pre-flight immediately

### Step 4 — Pre-Flight (automatic)

```
/pre-flight
```

Runs the 5 Claude agents + Codex adversarial review (if installed).
If pre-flight fails to locate PLAN.md: stop, report to user.

### Step 5 — Return Report

Present the Pre-Flight Report to the user with the verdict:

- **GO**: inform user they can run `/sparc "description"` to begin execution
- **CONDITIONAL GO**: present MEDIUM findings, ask user to confirm or fix first
- **NO-GO**: present required changes, suggest re-running `/gsd:plan-phase` with findings

---

## Behavior Rules

- Each step waits for the previous to complete before proceeding
- If any step returns an error: stop the chain and diagnose for the user
- Deepen-plan is the only interactive step (1 question, 2 choices)
- Never launch execution (`/sparc`, `/gsd:execute-phase`) — that's the user's decision

## What this skill does NOT do

- Modify GSD or CE skills
- Launch SPARC or execution
- Force deepen-plan (user opts in)
- Retry failed steps automatically
