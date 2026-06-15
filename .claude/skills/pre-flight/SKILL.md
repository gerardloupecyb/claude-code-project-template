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

## Execution — 4 parallel agents + 1 sequential critic

Launch Agents 1-4 simultaneously using the Agent tool. Each agent
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

**STRIDE-per-boundary extension (Phase 24.7 R2):**

Activate a STRIDE-per-boundary analysis when the plan body matches ANY keyword in this frozen list (Option A per Phase 24.7 RESEARCH):

```
\b(auth|authentication|authorization|oauth|jwt|session|mfa)\b
\b(public\s+API|webhook|graphql\s+endpoint|cross-tenant|multi-tenant)\b
\b(llm|claude|gpt|openai|anthropic|embeddings|rag)\b
```

**Word-boundary regex MANDATORY** (per Phase 24.7 Gemini cross-model review 2026-04-20). Without `\b` anchors, bare tokens like `auth`, `rag`, `gpt`, `mfa`, `llm` match substrings (`Egypt`, `storage`, `author`, `authoritative`), firing STRIDE on nearly every plan — directly contradicting Pitfall 5. Match invocation: `grep -Eiw` (word-match) or `grep -Ei '\b(...)\b'`.

**Comment-marker exclusion MANDATORY** (per Phase 24.7 pre-flight 2026-04-20 CONDITIONAL GO — Required Change 2). Before keyword matching, exclude commented-out reminder lines matching `^(\s*(//|--)|\s+#)\s*(TODO|NOTE|FIXME|XXX)` — a line like `// TODO: add oauth later` describes a non-existent boundary and would fire a ghost STRIDE section. The `#` arm requires leading whitespace (`\s+#`): a column-0 `# TODO: ...` in a Markdown PLAN.md is an ATX heading, not a comment, and must be kept — excluding it would mask a real boundary (a false negative, worse than a ghost section). Filter these out first (`grep -Ev '^(\s*(//|--)|\s+#)\s*(TODO|NOTE|FIXME|XXX)'`), then run the word-boundary keyword match on the remainder.

Case-insensitive. If zero whole-word matches, **SKIP** the STRIDE section entirely — do NOT emit an N/A table (RESEARCH Pitfall 5).

When at least one keyword matches:
1. Identify each trust boundary in the plan (crossings where untrusted input enters trusted code: client→API, webhook receiver→runbook, cross-tenant data, LLM input→prompt)
2. For each boundary, emit one STRIDE table using this schema:

```
### STRIDE — Boundary: {boundary_name}

| Category | Threat | Mitigation in plan | Severity | Rubric link |
|----------|--------|--------------------|----------|-------------|
| S (Spoofing) | {specific threat, or "N/A" with rationale} | {what plan does to mitigate, or "GAP"} | {Critical/High/Medium/Low/Info} | docs/references/security-review/scoring-rubric.md#per-cwe-example-bands |
| T (Tampering) | ... | ... | ... | ... |
| R (Repudiation) | ... | ... | ... | ... |
| I (Info disclosure) | ... | ... | ... | ... |
| D (DoS) | ... | ... | ... | ... |
| E (Elevation) | ... | ... | ... | ... |
```

All 6 rows MUST be present per boundary. "N/A" is acceptable in the Threat column with a one-line rationale — it is NOT acceptable in the Severity column (use "Info" for N/A threats).

Each STRIDE finding Severity MUST be both categorical and numeric band per `docs/references/security-review/scoring-rubric.md` (D-07 contract). Append composite severity per `#composite-severity-for-chained-findings` when a chain spans multiple STRIDE categories.

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

### Agent 4b: {{JURISDICTION}} Privacy Lens (parallel with Agents 1-4, conditional)

```
subagent_type: quebec-privacy-lens-reviewer
```

**Activate only if** the plan touches any of these {{JURISDICTION}}/Canada privacy signals:
- Renseignements personnels, renseignements de santé, or prospection data
- Cross-border storage/transit ({{CLOUD_PROVIDER}} region choice, SaaS routing, backup geo-replication)
- {{CRM_PLATFORM}}, {{ACCOUNTING_PLATFORM}}, or any US-hosted SaaS carrying {{PROJECT}} client data
- Consent collection, SAR/portability flow, retention/destruction policy
- Law references: {{COMPLIANCE_FRAMEWORK_PRIMARY}}, {{COMPLIANCE_FRAMEWORK_HEALTH}} ({{COMPLIANCE_FRAMEWORK_HEALTH}}/LRSSS), LPRPSP, {{COMPLIANCE_FRAMEWORK_FEDERAL}}, art. 17, art. 27, art. 3.3

If activated, pass the plan + the stable path hint so the subagent can load
framework docs from `docs/references/frameworks/` at runtime (it does not inherit
parent skill context — it reads the files itself).

This agent anchors every finding in a specific law article. It replaces the
default "generic privacy reflex" that `security-sentinel` applies when it
encounters PII — the two are complementary, not redundant.

### Agent 5: Architecture Critic (sequential — waits for Agent 1 output)

```
role: critic (ref: .claude/rules/swarm-patterns.md)
model: Opus (tier 3)
```

Receives: Agent 1 (Architecture Strategist) output + original plan.
Skip if plan is trivial (Agent 1 returned no findings).

Mission: actively challenge Agent 1's proposals:
- Are alternatives explored?
- Is there over-engineering?
- Are tradeoffs explicit?
- Are hidden costs identified?
- Is this the simplest design that satisfies the ACs?

If architecture artefacts exist in `docs/architecture/{slug}/`: verify the plan respects documented constraints.

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

### {{JURISDICTION}} Privacy (if activated)
- {finding 1 — law article anchor — severity: À RISQUE/NON-CONFORME}
- {finding 2 — law article anchor — severity: À RISQUE/NON-CONFORME}

### Architecture Challenge
- {Agent 1 proposal} → {Critic challenge} → {Resolution}
- {Agent 1 proposal} → {Critic challenge} → {Resolution}

### Design Verdict
{Summary: which design retained, why, which critic reservations are valid}

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

## Codex Cross-Model Challenge (automatic, non-blocking)

After the 5 agents + synthesis, launch automatically:

```bash
codex review --base main
```

The Codex review challenges the **plan** (not code — none exists yet).
Integrate findings in the report under a "Cross-Model Challenge" section:

```markdown
### Cross-Model Challenge
{Codex findings on plan design, tradeoffs, risks}
```

If Codex is not installed: skip silently. Never block pre-flight on Codex availability.

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
