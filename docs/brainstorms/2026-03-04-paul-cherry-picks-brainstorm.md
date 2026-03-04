# PAUL Framework Cherry-Picks for project-template-v2

**Date:** 2026-03-04
**Status:** Approved for planning
**Source:** [PAUL Framework](https://github.com/christopherKahler/paul)

## What We're Building

Integrating 4 concepts from the PAUL (Plan-Apply-Unify Loop) framework into project-template-v2 to close the gap between planning and execution reconciliation.

### The Gap Today

The template's flywheel captures **what we learned** (docs/solutions/, CARL rules, Supermemory). But nothing enforces reconciling **what we planned** vs **what we did**. Plans can be executed, things can drift, and nobody notices. Verification lacks objective criteria.

### What We're Adding

1. **Mandatory Loop Closure** — After every phase execution, require a summary comparing planned vs actual, logging decisions and deferred items
2. **BDD Acceptance Criteria** — Require Given/When/Then criteria in plans (for non-trivial plans with 3+ tasks)
3. **Boundary Protection** — Plans explicitly declare files/directories that must NOT be touched
4. **Deviation Logging** — When execution diverges from plan, log the deviation and reason before proceeding

## Why This Approach

**Cherry-picking > full adoption** because:
- PAUL's 26-command system overlaps too heavily with GSD + Compound Engineering
- PAUL's `.paul/` directory is redundant with `.planning/`
- PAUL's in-session-only philosophy conflicts with GSD's parallel subagent model
- But PAUL's execution discipline concepts fill a real gap in our template

**Lightweight implementation** because:
- 2 new CARL rules in the domain template (closure + deviation)
- Plan template format updates (BDD criteria + boundaries section)
- No new commands, no new directories, no new skills needed

## Key Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Adopt PAUL entirely? | No | Too much overlap with existing GSD + Compound stack |
| Which concepts to take? | All 4 cherry-picks | Complementary, minimal overhead, high value |
| BDD criteria always? | Only for plans with 3+ tasks | Avoids overkill on trivial changes |
| Implementation method? | CARL rules + template updates | Stays within existing architecture |
| New commands needed? | No | Closure integrates into existing `/workflows:compound` flow |

## Implementation Scope

### CARL Domain Template (`.carl/domain.template`)
- Add `RULE_4: LOOP CLOSURE` — After phase execution, create summary: planned vs actual, decisions, deferred items (RULE_3 is already CREDENTIALS SAFETY)
- Add `RULE_5: DEVIATION LOGGING` — When deviating from plan during execution, log reason in MEMORY.md before proceeding

### Plan Template Updates
- Add `## Acceptance Criteria` section with BDD format (for plans with 3+ tasks)
- Add `## Boundaries` section listing protected files/directories

### CLAUDE.md.template
- Update workflow section to reference closure as mandatory after execution
- Add acceptance criteria guidance to planning step

## Open Questions

None — approach is approved. Proceed to `/workflows:plan`.

## What We're NOT Doing

- Not installing PAUL as a dependency
- Not adding `/paul:*` commands
- Not creating a `.paul/` directory
- Not changing GSD's parallel subagent model
- Not adding a new skill (concepts are enforced via CARL rules)
