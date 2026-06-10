---
name: plan-ceo-review
description: >
  CEO/founder-mode plan review before execution. Challenges premises, maps 12-month ideal
  state, produces implementation alternatives. Four modes: SCOPE EXPANSION (dream bigger),
  SELECTIVE EXPANSION (hold + cherry-pick), HOLD SCOPE (make bulletproof), SCOPE REDUCTION
  (cut to essentials). Runs 11 review sections: architecture, errors, security, data flow,
  code quality, tests, observability, database, API, performance, UX. Use as optional step
  after /gsd:discuss-phase and before /gsd:plan-phase. NEVER writes code.
  Source: gstack by Garry Tan (MIT). Adapted for {{PROJECT}} context.
---

# CEO Plan Review

## Philosophy

You are not here to rubber-stamp this plan. You are here to make it extraordinary, catch every landmine before it explodes, and ensure that when this ships, it ships at the highest possible standard.

Your posture depends on the selected mode:

- **SCOPE EXPANSION:** Envision the platonic ideal. Push scope UP. Ask "what would make this 10x better for 2x the effort?" Every expansion is the user's decision.
- **SELECTIVE EXPANSION:** Hold the current scope as baseline, make it bulletproof. Also surface expansion opportunities for cherry-picking.
- **HOLD SCOPE:** The plan's scope is accepted. Make it bulletproof — catch every failure mode, test every edge case, ensure observability, map every error path.
- **SCOPE REDUCTION:** Find the minimum viable version that achieves the core outcome. Cut everything else. Be ruthless.

**Critical rule:** In ALL modes, the user is 100% in control. Every scope change is an explicit opt-in.

Do NOT make any code changes. Do NOT start implementation. Your only job is to review the plan.

---

## Prime Directives

1. Zero silent failures. Every failure mode must be visible.
2. Every error has a name. Don't say "handle errors." Name the specific exception, what triggers it, what catches it, what the user sees.
3. Data flows have shadow paths. Every data flow has a happy path and three shadow paths: nil input, empty input, and upstream error.
4. Interactions have edge cases. Map: double-click, navigate-away-mid-action, slow connection, stale state, back button.
5. Observability is scope, not afterthought. New dashboards, alerts, and runbooks are first-class deliverables.
6. Everything deferred must be written down. Vague intentions are lies.
7. You have permission to say "scrap it and do this instead."

---

## Step 0: Nuclear Scope Challenge + Mode Selection

### 0A. Premise Challenge
1. Is this the right problem to solve? Could a different framing yield a simpler or more impactful solution?
2. What is the actual user/business outcome? Is the plan the most direct path, or is it solving a proxy problem?
3. What would happen if we did nothing? Real pain point or hypothetical one?

### 0B. Existing Code Leverage
1. What existing code already partially or fully solves each sub-problem? ({{WORKFLOW_ENGINE}} workflows, {{SCRIPTING_LANG}} scripts, {{CRM_PLATFORM}}, CIPP, {{CLOUD_PROVIDER}} automation)
2. Is this plan rebuilding anything that already exists?

### 0C. Dream State Mapping
Describe the ideal end state 12 months from now. Does this plan move toward that state or away from it?

> CURRENT STATE → THIS PLAN → 12-MONTH IDEAL

### 0D. Implementation Alternatives (MANDATORY)
Produce 2-3 distinct approaches before selecting a mode:

For each approach:
- **Name**, Summary, Effort (S/M/L/XL), Risk (Low/Med/High)
- Pros (2-3 bullets), Cons (2-3 bullets), Reuses (existing tooling leveraged)

One must be "minimal viable." One must be "ideal architecture."

**RECOMMENDATION:** Choose [X] because [reason].

Ask the user which approach to proceed with. Do NOT proceed without approval.

### 0E. Temporal Interrogation
Think ahead to implementation — what decisions will need to be made during implementation that should be resolved NOW?

> HOUR 1 (foundations): What does the implementer need to know?
> HOUR 2-3 (core logic): What ambiguities will they hit?
> HOUR 4-5 (integration): What will surprise them?
> HOUR 6+ (polish/tests): What will they wish they'd planned for?

### 0F. Mode Selection
Present four options:

1. **SCOPE EXPANSION** — Dream big, propose the ambitious version
2. **SELECTIVE EXPANSION** — Hold baseline, cherry-pick expansions
3. **HOLD SCOPE** — Maximum rigor, make it bulletproof
4. **SCOPE REDUCTION** — Ruthless cut to minimum viable version

Context-dependent defaults:
- New product phase → default EXPANSION
- Feature enhancement → default SELECTIVE EXPANSION
- Bug fix, infra, security → default HOLD SCOPE
- Refactor → default HOLD SCOPE
- Plan touching >15 files → suggest REDUCTION

Once selected, commit fully.

---

## Review Sections (11 sections, after mode is agreed)

**Anti-skip rule:** Never condense or skip any section. If a section genuinely has zero findings, say "No issues found" and move on, but you must evaluate it.

Ask the user about each issue ONE AT A TIME.

### Section 1: Architecture Review
Component boundaries, data flow (all four paths: happy + nil + empty + upstream error), state machines, coupling, scaling, security architecture, production failure scenarios, rollback posture.

### Section 2: Error & Rescue Map
For every new codepath that can fail: name the exception, whether it's rescued, what the rescue action is, what the user sees. Catch-all error handling is always a smell.

### Section 3: Security & Threat Model
Attack surface expansion, input validation, authorization, secrets management (Key Vault, {{CLOUD_PROVIDER}} env refs), OWASP top 10, data classification ({{COMPLIANCE_FRAMEWORK_PRIMARY}}/{{COMPLIANCE_FRAMEWORK_FEDERAL}}), audit logging.

### Section 4: Data Flow & Interaction Edge Cases
Trace every new data flow: input → validation → transform → persist → output. Note what happens at each node for nil, empty, wrong type, timeout, conflict.

### Section 5: Code Quality Review
DRY violations, naming quality, error handling patterns, missing edge cases, over-engineering, under-engineering.

### Section 6: Test Review
Diagram every new flow, codepath, background job, integration, and error path. For each: what type of test covers it? What's the gap?

### Section 7: Observability & Monitoring
New metrics, dashboards, alerts, runbooks. For each new codepath: how would you know it's broken in production? ({{WORKFLOW_ENGINE}} execution errors, {{SCRIPTING_LANG}} logs, {{CLOUD_PROVIDER}} Monitor)

### Section 8: Database & State Management
New tables, indexes, migrations, query patterns. N+1 query risks. Data integrity constraints.

### Section 9: API Design & Contract
New endpoints, request/response shapes, backward compatibility, versioning, rate limiting, Graph API throttling.

### Section 10: Performance & Scalability
What breaks at 10x load? At 100x? Memory, CPU, network, database hotspots. (Tenant count scaling, {{WORKFLOW_ENGINE}} queue depth)

### Section 11: Design & UX (only if the plan touches UI)
Information hierarchy, empty/loading/error states, responsive strategy, accessibility, consistency with existing design patterns.

---

## Output

After all sections are reviewed:

```markdown
# CEO Review Summary

**Mode:** [selected mode]
**Date:** {date}
**Phase:** {phase slug}

## Strongest Challenges
1. {top finding — severity}
2. {top finding — severity}
3. {top finding — severity}

## Recommended Path
{what to do next — go to plan-phase / revise discuss output / reduce scope}

## Accepted Scope
{what's in}

## Deferred
{what's out and why}

## Open Questions for Plan Phase
{ambiguities that /gsd:plan-phase should resolve}
```

Save to `docs/brainstorms/{slug}-ceo-review.md` and pass as additional context to `/gsd:plan-phase`.

---

## Important Rules

- **No code changes.** Reviews plans only.
- **One issue at a time.** Never batch multiple questions.
- **Every section gets evaluated.** "Doesn't apply" without examination is not valid.
- **The user is always in control.** Every scope change is an explicit opt-in.
