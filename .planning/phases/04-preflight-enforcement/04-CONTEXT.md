# Phase 4: Pre-flight Enforcement - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Executing a GSD phase without a completed pre-flight is mechanically blocked. Two enforcement layers: hard gate in execute-phase workflow + advisory telemetry in session-gate. CARL rule in domain.template ensures the rule propagates to all new projects.

</domain>

<decisions>
## Implementation Decisions

### Check numbering reconciliation (ENFC-03/04 vs actual)
- **D-01:** Update REQUIREMENTS.md to reference Check 20 (the actual number in session-gate), not Check 18
- **D-02:** Do NOT renumber session-gate checks — too risky with cross-references in other files
- **D-03:** Verify Check 20 logic matches ENFC-03/04/05 requirements exactly (it already does from Track A)

### CARL rule instantiation scope
- **D-04:** Goal is template correctness — ensure `domain.template` has RULE_9 (already done from Track A)
- **D-05:** Create a live `.carl/project-template` domain that instantiates RULE_0 through RULE_10, so the template project dogfoods its own rules
- **D-06:** The `n8nautomation` domain in `.carl/` is a leftover from skill development — leave as-is (out of scope)

### Enforcement mechanism — dual layer (ENFC-06)
- **D-07:** Hard gate lives in `execute-phase` workflow, not just session-gate. Session-gate is advisory only (documented at SKILL.md:328, :338) — too late to prevent bad execution
- **D-08:** Session-gate Check 20 stays as governance telemetry — catches skipped pre-flight retroactively at session boundaries
- **D-09:** execute-phase checks for `*-PREFLIGHT.md` BEFORE spawning any agents. Three outcomes:
  - Missing PREFLIGHT: `Execution blocked: Phase {N} has PLAN.md but no PREFLIGHT.md. Run /pre-flight first, then re-run /gsd:execute-phase {N}.`
  - Latest verdict NO-GO: `Execution blocked: latest PREFLIGHT verdict is NO-GO. Fix required changes, re-run /pre-flight, then re-run /gsd:execute-phase {N}.`
  - Verdict CONDITIONAL GO: pause for explicit user confirmation before proceeding (not auto-pass)
- **D-10:** Override flag: `--skip-preflight --reason "description"` — narrow and loud, mandatory reason string, logged in SUMMARY.md and MEMORY.md. Not a casual escape hatch — for doc-only/gap-closure/trivial phases only
- **D-11:** Error messages must include the exact next command to run (actionable, not descriptive)

### Claude's Discretion
- Exact implementation of the preflight check in execute-phase (where in the step sequence, how to parse verdict)
- Whether to add the check as a gsd-tools.cjs command or inline in the workflow
- Format of the override logging in SUMMARY.md

</decisions>

<specifics>
## Specific Ideas

- Error shape example (from user): `Execution blocked: Phase 05 has PLAN.md but no PREFLIGHT.md. Run /pre-flight first, then re-run /gsd:execute-phase 05.`
- CONDITIONAL GO confirmation aligns with existing contracts in pre-flight/SKILL.md:182, :192 and prepare-phase/SKILL.md:97
- Override must be `--skip-preflight --reason "..."` (not just `--skip-preflight`) to prevent it becoming the default path

</specifics>

<canonical_refs>
## Canonical References

### Session-gate (existing Check 20)
- `.claude/skills/session-gate/SKILL.md` §Check 20 (lines 281-296) — Existing advisory pre-flight detection logic
- `.claude/skills/session-gate/SKILL.md` §lines 328, 338 — Advisory-only, does not block

### Execute-phase workflow (gate insertion point)
- `~/.claude/get-shit-done/workflows/execute-phase.md` §validate_phase step — Where hard gate should be added

### Pre-flight verdicts
- `.claude/skills/pre-flight/SKILL.md` §lines 182, 192 — CONDITIONAL GO semantics
- `.claude/skills/prepare-phase/SKILL.md` §line 97 — CONDITIONAL GO handling in prepare-phase

### CARL template
- `.carl/domain.template` §RULE_9 — PREFLIGHT ENFORCEMENT rule (already exists)

### Requirements
- `.planning/REQUIREMENTS.md` §ENFC-01 to ENFC-06 — Phase 4 requirements (Check 18 → update to Check 20)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Check 20 in session-gate: complete detection logic for missing PREFLIGHT and NO-GO verdicts — can be mirrored in execute-phase
- `domain.template` RULE_9: ready-to-instantiate CARL rule
- `gsd-tools.cjs`: may have phase file discovery that can be reused for PREFLIGHT detection

### Established Patterns
- Session-gate checks use `[!!]` for blocking-severity, `[--]` for informational — Check 20 already uses `[!!]`
- execute-phase uses `AskUserQuestion` for checkpoint handling — same pattern for CONDITIONAL GO confirmation
- Phase file naming: `{phase_num}-PREFLIGHT.md` in phase directory

### Integration Points
- execute-phase workflow: gate check after `validate_phase` step, before `discover_and_group_plans`
- REQUIREMENTS.md: update Check 18 references to Check 20
- `.carl/project-template`: new domain file instantiating template rules

</code_context>

<deferred>
## Deferred Ideas

- Renumbering session-gate checks to be sequential (too risky now, consider in a future cleanup phase)
- Cleaning up `n8nautomation` CARL domain (leftover, out of scope for this phase)

</deferred>

---

*Phase: 04-preflight-enforcement*
*Context gathered: 2026-04-02*
