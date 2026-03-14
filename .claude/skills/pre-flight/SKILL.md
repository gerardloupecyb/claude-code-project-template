---
name: pre-flight
description: >
  Multi-agent review of GSD plans BEFORE execution. Runs architecture,
  security, performance, and spec-flow agents in parallel against PLAN.md
  files to catch design flaws before they become code. Trigger when user
  says "pre-flight", "preflight", "gate check", "validate plan",
  "review plan before executing", or between /gsd:plan-phase and
  /gsd:execute-phase.
---

# Pre-Flight — Multi-Agent Plan Review

Validate that a GSD plan is **sain** (not just complet) before execution.
GSD's plan checker verifies structural completeness against requirements.
Pre-flight verifies the plan won't create security holes, performance
bottlenecks, architectural anti-patterns, or missed user flows.

---

## When to trigger

- After `/gsd:plan-phase` completes successfully
- Before `/gsd:execute-phase` starts
- When user explicitly asks for plan validation
- When the plan touches: authentication, payments, data migration,
  external APIs, or user-facing flows

---

## Inputs

Locate the plan files to review:

1. Read `STATE.md` or `.planning/` to identify the current phase number
2. Find all `{phase}-{N}-PLAN.md` files for that phase
3. Also read `REQUIREMENTS.md` and `{phase}-CONTEXT.md` if they exist
4. Check `docs/solutions/` for relevant learnings (via Agent Explore)

If no plan files found, inform the user and suggest running `/gsd:plan-phase` first.

---

## Execution — launch 4 agents in parallel

Launch ALL four agents simultaneously using the Agent tool. Each agent
receives the plan content + requirements + context as input.

### Agent 1: Architecture Strategist

```
subagent_type: architecture-strategist
```

Review the plan for:
- Component boundaries and coupling
- Data flow and state management patterns
- API design consistency
- Separation of concerns violations
- Over-engineering or under-engineering

### Agent 2: Security Sentinel

```
subagent_type: security-sentinel
```

Review the plan for:
- Authentication/authorization gaps
- Input validation missing at system boundaries
- Hardcoded secrets or credential handling
- OWASP top 10 exposure in planned implementation
- Data exposure risks in API responses

### Agent 3: Performance Oracle

```
subagent_type: performance-oracle
```

Review the plan for:
- N+1 query patterns in data access plans
- Missing indexes on queried fields
- Unbounded queries or pagination gaps
- Caching opportunities missed
- Scalability concerns in the planned approach

### Agent 4: Spec Flow Analyzer

```
subagent_type: spec-flow-analyzer
```

Review the plan for:
- All user flows covered (happy path + error paths)
- Edge cases not addressed in tasks
- Missing error handling or fallback behaviors
- Incomplete state transitions
- Flows that dead-end without user feedback

---

## Output — Pre-Flight Report

After all 4 agents complete, synthesize their findings into a structured report.

### Format

```markdown
# Pre-Flight Report — Phase {N}

**Date:** {date}
**Plans reviewed:** {list of plan files}
**Verdict:** GO / CONDITIONAL GO / NO-GO

## Summary

{2-3 sentence overall assessment}

## Findings

### Architecture
- {finding 1 — severity: LOW/MEDIUM/HIGH/CRITICAL}
- {finding 2}

### Security
- {finding 1 — severity: LOW/MEDIUM/HIGH/CRITICAL}
- {finding 2}

### Performance
- {finding 1 — severity: LOW/MEDIUM/HIGH/CRITICAL}
- {finding 2}

### Spec Completeness
- {finding 1 — severity: LOW/MEDIUM/HIGH/CRITICAL}
- {finding 2}

## Verdict Rationale

{Why GO/CONDITIONAL/NO-GO}

## Required Changes (if CONDITIONAL or NO-GO)

1. {Change 1 — which plan file, which task, what to fix}
2. {Change 2}

## Recommended Improvements (optional, non-blocking)

1. {Improvement 1}
2. {Improvement 2}
```

### Verdict rules

- **GO** — No HIGH or CRITICAL findings. Proceed to `/gsd:execute-phase`.
- **CONDITIONAL GO** — Has MEDIUM findings. Can proceed if user acknowledges.
  List each MEDIUM finding and ask user to confirm proceed or fix first.
- **NO-GO** — Has HIGH or CRITICAL findings. Must fix before execution.
  Provide specific changes needed in which plan files.

---

## Post-report actions

- If **GO**: inform user they can run `/gsd:execute-phase {N}`
- If **CONDITIONAL GO**: present findings, ask user to choose proceed or fix
- If **NO-GO**: present required changes. Suggest re-running `/gsd:plan-phase`
  with the findings as additional context, or manual edits to plan files.

Save the report to `.planning/milestones/{milestone}/{phase}-PREFLIGHT.md`
(or `.planning/{phase}-PREFLIGHT.md` if no milestone structure exists).

---

## What this skill does NOT do

- Replace GSD's plan checker (structural completeness remains GSD's job)
- Modify plan files (read-only analysis, user decides what to fix)
- Block execution (user can override CONDITIONAL GO)
- Review code (this reviews plans, /ce:review reviews code)

---

## Integration with other tools

- **GSD**: reads plan files from `.planning/`, writes report to `.planning/`
- **Compound**: uses the same review agents already installed
- **CARL**: findings classified as "reusable" can feed the flywheel
- **MEMORY.md**: pre-flight verdict noted in session state
