# Gap Analysis Review -- Upstream Sync CE v2.46 + GSD v1.27

**Date:** 2026-03-20
**Type:** UX flow analysis + completeness review
**Input:** docs/plans/2026-03-20-001-analysis-upstream-sync-gaps-plan.md
**Status:** REVIEW COMPLETE

---

## User Flow Overview

The plan identifies 21 recommendations across 4 phases. Below is the complete map of user flows this plan affects, numbered for reference.

### Flow 1 -- Session Lifecycle (start -> work -> checkpoint -> end)

```
Session start
  -> SessionStart hook fires (auto-inject MEMORY.md + LESSONS.md)
  -> /session-gate start (optional, 9 checks: 1,2,3,4,5,8,11,12,13)
  -> Work phase
     -> Context degradation detected -> /context-checkpoint
        OR
     -> Context monitor (GSD v1.27, NEW rec 1.6) proactively warns
  -> Closure protocol (7 steps)
  -> /session-gate end (optional, 9 checks: 1,4,5,6,7,8,9,10,11)
  -> /project-sync (optional)
  -> /gsd:session-report (NEW rec 1.7, optional)
  -> Commit
```

### Flow 2 -- Task Routing (user has a task, which path?)

```
User describes task
  -> /gsd:do (NEW rec 2.3, natural language router)
     OR manual classification:

  Route A: Trivial (NEW rec 2.1)
    -> /gsd:fast "description"
    -> Update MEMORY.md only (no SUMMARY.md)
    -> Done

  Route B: Standard (existing)
    -> /gsd:plan-phase -> /pre-flight -> /gsd:execute-phase
    -> closure -> /lesson -> /gsd:verify-work -> /ce:review
    -> /gsd:ship (NEW rec 2.6)

  Route C: Complex (existing)
    -> /ce:brainstorm -> /ce:plan
    -> /gsd:discuss-phase -> /gsd:plan-phase -> /pre-flight -> /gsd:execute-phase
    -> closure -> /lesson -> /gsd:verify-work -> /ce:review -> /ce:compound
    -> /gsd:ship (NEW rec 2.6)

  Route D: Autonomous milestone (NEW rec 2.4)
    -> /gsd:autonomous [--from N]
    -> Chains: discuss -> plan -> execute for each phase
    -> Pauses at decision points
    -> Automatic closure

  Route E: Auto-advance (NEW rec 2.2)
    -> /gsd:next (detects state, invokes next logical step)
    -> Shortcut usable from any point in Routes B/C
```

### Flow 3 -- Planning Lifecycle

```
Ideation (NEW rec 3.6)
  -> /ce:ideate (pre-brainstorm, evidence-based idea generation)
  -> /ce:brainstorm (requirements exploration)
  -> /ce:plan OR /gsd:plan-phase
     -> Rule de consultation: LESSONS.md -> DECISIONS.md -> recall Supermemory -> agent docs/solutions/
     -> CARL RULE_8 enforces recall (existing, from layer2 plan)
     -> Plan depth classification (NEW rec 3.2): Lightweight / Standard / Deep
     -> Execution posture signaling (NEW rec 3.1): test-first, characterization-first per unit
     -> Technical design for Deep plans (NEW rec 3.3): pseudo-code, mermaid, data flow
     -> Decision IDs (NEW rec 3.4): DEC-NNN references in plans
     -> Requirements coverage gate (NEW rec 2.8): all requirements covered by plan
  -> /pre-flight (4 parallel agents: archi, secu, perf, spec-flow)
     -> GO / CONDITIONAL GO / NO-GO
  -> /gsd:execute-phase
     -> Cross-phase regression gate (NEW rec 2.7): re-runs previous phase tests
     -> Stub detection (NEW rec 2.10): catches TODOs, placeholder code
     -> execution-quality.md rules auto-injected
  -> /gsd:verify-work
     -> /gsd:audit-uat (NEW rec 2.9): verification debt tracking
  -> /ce:review (internal agents) AND/OR /gsd:review --all (NEW rec 4.1, external CLIs)
  -> /gsd:ship (NEW rec 2.6): close loop -> PR
```

### Flow 4 -- Context Management (which memory artifact when?)

```
MEMORY.md          = session state, current context, what's next (every session)
auto memory        = Claude's native ~/.claude/projects/<project>/memory/ (NEW rec 1.1)
DECISIONS.md       = ADR-light register, architectural decisions (at planning time)
LESSONS.md         = learned lessons cache, cap 50 (every session, at planning time)
CARL domains       = critical rules, auto-injected per context
Supermemory        = archived lessons + cross-project (at planning time via recall)
docs/solutions/    = detailed patterns, code (fallback when Supermemory unavailable)
.planning/STATE.md = GSD technical position (auto-managed by GSD)
threads (NEW 1.3)  = /gsd:thread for cross-session investigation/debug on specific topics
HANDOFF.json (1.4) = machine-readable handoff from /gsd:pause-work
WAITING.json (1.5) = signal for user decision points in autonomous/multi-agent flows
session-report     = token usage + session summary (optional, end of session)
```

### Flow 5 -- Lesson/Knowledge Capture

```
/lesson            = rapid capture of a learned lesson (quand/faire/parce que -> LESSONS.md)
/lesson migrate    = when cap 50 reached, migrate 10 oldest to Supermemory + docs/solutions/
/ce:compound       = heavy patterns with code + anti-patterns -> docs/solutions/ + CARL + Supermemory
/gsd:note (NEW 2.5)= zero-friction idea capture (immediate, no structure)
/gsd:plant-seed    = future ideas with trigger conditions (surfaced by /gsd:new-milestone)
```

### Flow 6 -- Review Lifecycle

```
/ce:review         = internal multi-agent review (15 specialized Claude sub-agents)
                     Used after: closure + /gsd:verify-work
                     Reads: VERIFICATION.md, SUMMARY.md, code diff
                     Output: review findings

/gsd:review --all  = external CLI review (NEW rec 4.1)
                     Invokes: Gemini CLI, Claude CLI, Codex
                     Used after: /ce:review (diversity of perspective)
                     Prerequisite: at least one external CLI installed
                     Output: cross-AI review findings
```

---

## Flow Permutations Matrix

| Dimension | Flow 1 (Session) | Flow 2 (Task Routing) | Flow 3 (Planning) | Flow 4 (Context) | Flow 5 (Capture) | Flow 6 (Review) |
|-----------|------------------|-----------------------|--------------------|-------------------|--------------------|--------------------|
| First-time user | Hook may not fire (no settings.json yet) | Unknown which route to choose | No LESSONS.md, no DECISIONS.md | Cold start, empty state | Nothing to capture yet | No verification baseline |
| Returning user | Hook fires, MEMORY.md injected | Knows routes, uses /gsd:next | Full context available | All artifacts populated | Active cap management | Full pipeline available |
| After compaction | session-start.sh re-injects | Task state partially lost | Plan files intact on disk | MEMORY.md re-read, but in-session context lost | Mid-capture state unclear | Mid-review state lost |
| After /clear | session-start.sh re-injects | Task state lost | Plan files intact on disk | MEMORY.md re-read | Mid-capture state lost | Review must restart |
| GSD not installed | Hooks still fire (pre-compact, session-start) | Only Route C available (CE-only) | /ce:plan works, /gsd:plan-phase absent | STATE.md absent, HANDOFF/WAITING absent | /lesson works, /gsd:note absent | Only /ce:review available |
| CE not installed | Hooks still fire | Only Route A/B available | /gsd:plan-phase works, no /ce:brainstorm/plan | No /ce:compound flywheel | /lesson works, /ce:compound absent | Only /gsd:review available |
| Supermemory unavailable | No impact | No impact | Recall step skipped gracefully | Cross-project blind | /lesson migrate partial (docs/solutions/ only) | No impact |
| No external CLIs | No impact | No impact | No impact | No impact | No impact | /gsd:review --all fails |
| Autonomous mode | Session may span multiple phases | All routing handled by /gsd:autonomous | Planning chained automatically | Multiple closures per session | Multiple capture opportunities | Review at milestone end |

---

## Missing Elements and Gaps

### Category: Rollback and Recovery

**Gap R1 -- No rollback procedure for failed GSD update**
The plan says "Mettre a jour GSD: /gsd:update" (Phase 1, 5 min). But what if /gsd:update fails mid-way? What if it introduces a breaking change that corrupts .planning/ state? There is no documented rollback. GSD update modifies files in ~/.claude/commands/gsd/ -- is there a version pinning mechanism? Can you revert to the prior GSD version?
Impact: A failed update could leave the system in an inconsistent state between CE and GSD versions.

**Gap R2 -- No rollback for failed CE plugin update**
Same concern for `bunx @every-env/compound-plugin install compound-engineering`. If the update fails or introduces incompatible skill signatures, there is no documented recovery path.
Impact: CE skills referenced in CLAUDE.md.template and workflows may stop working.

**Gap R3 -- No incremental update strategy**
The plan proposes updating CE from v2.40 to v2.46 (6 versions) and GSD from ~v1.24 to v1.27 (3 versions) in one shot. This is a significant jump. What if an intermediate version has breaking changes that are documented in its changelog but silently affect flows?
Impact: Big-bang updates increase the blast radius of incompatibilities.

### Category: Feature Overlap and Confusion

**Gap O1 -- /gsd:note vs /gsd:plant-seed vs /lesson -- distinction unclear**
The plan (rec 2.5) acknowledges this but the proposed documentation ("note pour les idees immediates, plant-seed pour les idees futures, lesson pour les patterns appris") is insufficient. The boundaries are fuzzy. Example: user discovers that "the API always returns paginated results even for single items" -- is this a /lesson (pattern learned), a /gsd:note (idea to fix it), or a /gsd:plant-seed (future refactor)?
Impact: Users will default to whichever command they remember, creating inconsistent capture.

**Gap O2 -- /ce:review vs /gsd:review -- unclear sequencing and overlap**
The plan recommends adding /gsd:review --all "dans le parcours post-verification" but the existing workflow already places /ce:review after verification. The plan does not specify:
- Do you run both? Always?
- What if /ce:review finds issues -- do you fix them before /gsd:review, or run both and consolidate?
- What if external CLIs disagree with internal agents?
Impact: Without clear sequencing, users will either skip one or run both redundantly.

**Gap O3 -- auto memory vs MEMORY.md vs threads -- three memory layers with unclear boundaries**
The plan adds auto memory (rec 1.1) and threads (rec 1.3) to the existing MEMORY.md. The documentation says "thread = sujet specifique cross-session, MEMORY.md = etat global" but auto memory is described as "insights perdus par le contexte apres compaction." This creates three overlapping persistence layers for session context:
- MEMORY.md: manual, structured, per-session
- auto memory: automatic, unstructured, post-compaction survivals
- /gsd:thread: manual, topic-scoped, cross-session
Impact: Users and Claude will not know which to consult when. The Rule de consultation does not include auto memory or threads in its sequence.

**Gap O4 -- HANDOFF.json vs MEMORY.md at session boundary**
/gsd:pause-work generates HANDOFF.json (rec 1.4). The existing closure protocol writes MEMORY.md. When resuming:
- Does /gsd:resume-work read HANDOFF.json OR MEMORY.md OR both?
- What if they are out of sync?
- Does the SessionStart hook inject HANDOFF.json alongside MEMORY.md?
Impact: Two sources of truth at session boundary. Risk of stale or contradictory resume state.

**Gap O5 -- /gsd:fast closure vs standard closure**
The plan says /gsd:fast results in "closure (MEMORY.md only, pas de SUMMARY.md)". But the existing closure protocol is a 7-step checklist. Which steps are skipped for /gsd:fast? Is the quality score (step 6) skipped? Is the decision capture (step 7) skipped? What about /lesson proposal (step 4)?
Impact: Undefined partial closure risks losing important signals from trivial tasks.

### Category: Context Budget and Token Economics

**Gap T1 -- Context monitor coexistence with pre-compact.sh**
The plan identifies this risk ("Tester la coexistence avant d'activer") but provides no test procedure and no fallback if they conflict. What does "conflict" look like? Both trying to write MEMORY.md simultaneously? Both triggering at different thresholds?
Impact: Two competing context management systems could interfere, causing data loss or duplicate writes.

**Gap T2 -- CLAUDE.md.template growth beyond 500 lines**
The plan acknowledges the template is at ~446 lines and the new recommendations would add ~50-80 lines. The budget target was 200 lines (per Anthropic). Even with extraction to .claude/rules/, the plan adds 5 new parcours entries (fast, autonomous, ideate, /gsd:next, /gsd:do), a capture rapide section, context monitor references, auto memory documentation, and thread documentation. This risks pushing the template well beyond the already-exceeded budget.
Impact: Further adherence degradation. The very features being added may not be followed because the instruction set is too large.

**Gap T3 -- Cumulative token cost of all new .claude/rules/ files**
execution-quality.md is 630 tokens. tool-routing.md and flywheel-workflow.md are already loaded. Adding more rules (or expanding existing ones per recs 2.7, 3.1, 3.2) increases the baseline token consumption for every session and subagent.
Impact: Diminishing returns as the rules corpus grows. No explicit token budget for .claude/rules/ total.

### Category: Testing and Validation

**Gap V1 -- No validation strategy per recommendation**
The plan has a "Phase 1: Mises a jour upstream" with verify versions. But Phases 2-4 have no validation strategy. How do you verify that:
- /gsd:fast actually works inline without subagents?
- /gsd:next correctly detects project state?
- The context monitor does not conflict with pre-compact.sh?
- Cross-phase regression gate actually re-runs previous tests?
- /gsd:review --all works with no external CLIs installed (graceful degradation)?
Impact: Recommendations may be integrated into docs but never tested end-to-end.

**Gap V2 -- No acceptance criteria for the plan itself**
Unlike the other plans in docs/plans/ (which all have explicit AC sections), this gap analysis has "Metriques de succes" but no formal acceptance criteria. The metrics are aspirational ("-50% sessions interrompues") not testable.
Impact: No clear definition of done for the sync effort.

**Gap V3 -- No test for existing project migration**
The context-management plan (2026-03-16-001) identified existing project migration as a "Known Gap." This plan compounds it: it adds even more features that existing projects won't have.
Impact: The gap between new and existing projects widens with each recommendation.

### Category: Sequencing and Dependencies

**Gap S1 -- Phase 2 actions 1-8 have undocumented inter-dependencies**
The plan lists 8 actions in Phase 2 but does not specify execution order. Some have implicit dependencies:
- Action 4 (Enrichir Regle #8 with execution posture + plan depth) depends on the CE plugin being updated (Phase 1)
- Action 5 (cross-phase regression gate in execution-quality.md) depends on GSD being updated (Phase 1)
- Action 8 (/gsd:review --all) requires external CLIs installed -- not listed as a Phase 1 prerequisite
Impact: Parallel execution of Phase 2 actions could fail if prerequisites are not met.

**Gap S2 -- Dependency on Layer 2 retention gaps plan (not yet implemented)**
MEMORY.md "Prochaine etape" says the next step is implementing the Layer 2 plan (DECISIONS.md, closure quality score, etc.). This plan assumes some of those features exist (it references DECISIONS.md in the Rule de consultation, decision IDs in plans). The ordering is unclear.
Impact: If this sync plan executes before the Layer 2 plan, references to DECISIONS.md and DEC-NNN will be broken.

**Gap S3 -- No consideration of the project-sync plan (2026-03-12)**
The project-sync plan introduces .claude/integrations.md and a /project-sync skill. This upstream sync plan does not mention it. But several GSD features (autonomous mode, session-report) could interact with project-sync.
Impact: Missed integration opportunity. /gsd:autonomous completing phases could trigger project-sync to update Linear issues.

### Category: Security and Safety

**Gap X1 -- Security hardening (rec 4.2) has no testing procedure**
The plan says gsd-prompt-guard "s'installe automatiquement" but does not specify how to verify it is working. What does a blocked prompt injection look like? Is there a log?
Impact: Security features that are not tested may create false confidence.

**Gap X2 -- Autonomous mode (rec 2.4) safety boundaries**
/gsd:autonomous chains discuss -> plan -> execute for all remaining phases. What prevents it from:
- Executing destructive operations without user confirmation?
- Spending excessive tokens on a multi-phase chain?
- Getting stuck in an infinite loop between discuss and plan?
The plan says it "pause uniquement pour les decisions utilisateur" but does not define what constitutes a "decision utilisateur" vs a routine choice.
Impact: Autonomous mode without clear guardrails could cause significant damage or waste.

### Category: Missing Flows

**Gap M1 -- Upgrade flow for the template itself**
When upstream CE/GSD versions change again (v2.47, v1.28), the same sync analysis will need to happen. There is no documented meta-workflow for "how to sync the template with upstream updates." This plan is a one-off analysis.
Impact: The sync process is not repeatable without re-doing this entire analysis manually.

**Gap M2 -- Degradation flow when GSD or CE is partially available**
What if GSD update succeeds but CE update fails? The template would have mixed versions. Several features depend on both being at target versions (e.g., execution posture signaling needs CE v2.44+ AND the template Rule #8 update).
Impact: No documented partial-update state. The system could be in an untested configuration.

**Gap M3 -- New user onboarding flow**
The plan adds /gsd:do (natural language routing), /gsd:next (auto-advance), and /gsd:fast (trivial path). These are great for onboarding but there is no documented "first session" experience. A new user encounters: 5 workflow parcours, 8+ slash commands for task routing alone, 3 review commands, 5 capture commands. Where do they start?
Impact: The template becomes powerful but opaque. Paradox of choice.

**Gap M4 -- /gsd:thread lifecycle not specified**
The plan mentions threads (rec 1.3) but does not specify:
- How is a thread created? (/gsd:thread create "topic"?)
- How is a thread resumed in a new session?
- How is a thread closed/archived?
- Where do thread files live? (.planning/threads/? memory/threads/?)
- Do session-gate checks apply to threads?
Impact: Without lifecycle specification, threads will be created and abandoned.

**Gap M5 -- Error recovery flow for /gsd:autonomous**
If autonomous mode fails mid-execution of phase 3 out of 5:
- Is the state saved?
- Can it be resumed with /gsd:autonomous --from 3?
- What state artifacts exist to restart from?
- Is the closure protocol run for the partially-completed phase?
Impact: Autonomous mode failure without recovery leaves orphaned state.

---

## Critical Questions Requiring Clarification

### Critical (blocks implementation or creates risk)

**Q1.** What is the exact rollback procedure if /gsd:update or CE plugin update fails or introduces breaking changes? Specifically, is there a version pin or snapshot mechanism?
- Why it matters: Phase 1 is the prerequisite for everything else. Failure here blocks all 21 recommendations.
- Default assumption if unanswered: Manual git restore of ~/.claude/commands/gsd/ and reinstall of previous CE version. Document this before starting.

**Q2.** What is the execution order between this plan and the Layer 2 retention gaps plan? Several recommendations here reference DECISIONS.md and DEC-NNN which do not exist yet.
- Why it matters: Broken references in CLAUDE.md.template if Layer 2 plan executes after.
- Default assumption if unanswered: Layer 2 plan executes first. Add explicit prerequisite.

**Q3.** How does /gsd:autonomous define "decision utilisateur" that triggers a pause? Is there a formal boundary between routine choices (which approach? which library?) and user decisions (delete this data? change the API contract?)?
- Why it matters: Without this boundary, autonomous mode either pauses too often (defeating its purpose) or too rarely (causing damage).
- Default assumption if unanswered: Autonomous mode pauses for anything that would require a DEC-NNN entry in DECISIONS.md. This needs GSD upstream confirmation.

**Q4.** How do the GSD context monitor (rec 1.6) and the existing pre-compact.sh hook coexist? What is the specific test to verify they do not conflict?
- Why it matters: Dual context management systems writing to the same files could corrupt MEMORY.md.
- Default assumption if unanswered: Start with context monitor disabled (hooks.context_monitor: false). Enable after explicit coexistence testing with a reproducibility procedure.

### Important (significantly affects UX or maintainability)

**Q5.** For the /gsd:fast "parcours immediat": which steps of the 7-step closure protocol apply? Is the quality score (step 6) required? Decision capture (step 7)?
- Why it matters: Undefined partial closure creates inconsistency. A trivial fix that introduces a decision would not be captured.
- Default assumption if unanswered: /gsd:fast closure = steps 2 (MEMORY.md update) and 4 (/lesson proposal if non-trivial) only. Steps 1, 3, 5, 6, 7 skipped.

**Q6.** What is the concrete distinction between /gsd:note, /gsd:plant-seed, and /lesson? Provide three examples of each that clearly do not overlap.
- Why it matters: Users will not read nuanced descriptions. They need a clear decision tree.
- Default assumption if unanswered: /lesson = "I learned something from a mistake or discovery" (reactive). /gsd:note = "I want to remember this for later today" (ephemeral). /gsd:plant-seed = "This should be done someday, triggered by X" (deferred action).

**Q7.** When should a user run /ce:review only, /gsd:review only, or both? What is the recommended sequence?
- Why it matters: Running both every time doubles review time. Running neither misses issues.
- Default assumption if unanswered: /ce:review always (internal baseline). /gsd:review --all optional, recommended for milestone boundaries or high-risk changes. Sequence: /ce:review first -> fix issues -> /gsd:review if warranted.

**Q8.** What is the CLAUDE.md.template line budget after all 21 recommendations are implemented? Has the math been done to ensure it stays under 500 lines (or ideally approaches 200)?
- Why it matters: The plan adds 5 new parcours, a capture section, context monitor text, auto memory text, and thread documentation. Without line-level budget, the template will grow beyond control.
- Default assumption if unanswered: Extract the new parcours (fast, autonomous) and the capture rapide section into a new .claude/rules/workflow-routing.md file. Add a 1-line reference in CLAUDE.md.template.

**Q9.** What happens when /gsd:review --all is invoked but no external CLI is installed? Does it fail silently? Inform the user? Fall back to /ce:review?
- Why it matters: Many users will not have Gemini CLI or Codex installed.
- Default assumption if unanswered: GSD handles this natively with a "no external CLIs found" message. Confirm this behavior after update. Document the prerequisite in CLAUDE.md.template.

### Nice-to-have (improves clarity but has reasonable defaults)

**Q10.** Should /gsd:session-report (rec 1.7) be part of the standard closure protocol or remain fully optional?
- Why it matters: If it generates valuable metrics (token usage), it should be at least suggested in closure.
- Default assumption if unanswered: Fully optional. Mention in Rule #2 with "Optionnellement, lancer /gsd:session-report pour un rapport de consommation."

**Q11.** Should the Rule de consultation sequence be updated to include auto memory (rec 1.1) and threads (rec 1.3)?
- Why it matters: Currently the sequence is LESSONS.md -> DECISIONS.md -> Supermemory -> docs/solutions/. Auto memory and threads are not consulted during planning.
- Default assumption if unanswered: Auto memory is consulted by CE natively (per v2.45). Threads are not part of planning -- they are investigation artifacts. No change to Rule de consultation.

**Q12.** How does /gsd:ship interact with the existing CE review flow? Does it expect /ce:review to have already run? Does it create a PR that includes review status?
- Why it matters: The plan says "Ajouter /gsd:ship apres /ce:review" but does not define the handoff.
- Default assumption if unanswered: /gsd:ship runs after /ce:review. It creates a PR with the SUMMARY.md and VERIFICATION.md as context. It does not re-review.

---

## Recommended Next Steps

### Step 1: Resolve dependencies BEFORE Phase 1

1. **Implement the Layer 2 retention gaps plan first** (DECISIONS.md, closure quality score, session-gate checks 11-13). Multiple recommendations in this sync plan reference DEC-NNN and DECISIONS.md.
2. **Document rollback procedures** for both GSD update and CE plugin update before executing Phase 1.
3. **Verify the project-sync plan status** and decide if it integrates with the autonomous/session-report features.

### Step 2: Define clear boundaries for overlapping features

4. **Create a decision tree** (not just descriptions) for note vs seed vs lesson. Format as a simple flowchart: "Did you learn something from a mistake? -> /lesson. Do you have an idea for later? -> /gsd:plant-seed. Do you want to jot down something ephemeral? -> /gsd:note."
5. **Define the review sequence** explicitly: /ce:review (always) -> /gsd:review (for milestones or when diversity needed). Document in the "parcours standard" and "parcours complet."
6. **Define /gsd:fast closure** as a subset: MEMORY.md update + /lesson proposal only.

### Step 3: Budget the CLAUDE.md.template additions

7. **Extract new parcours to .claude/rules/workflow-routing.md**: the 5 new routes (fast, autonomous, ideate, /gsd:do, /gsd:next) plus the "Capture rapide" section. This keeps CLAUDE.md.template under control.
8. **Set a hard token budget for .claude/rules/ total**: propose 3000 tokens max across all rules files combined. Currently at ~1800 (tool-routing 1000 + execution-quality 630 + flywheel ~200). New additions must fit within 1200 remaining tokens.

### Step 4: Add validation criteria

9. **Add acceptance criteria to each Phase** (not just Phase 1). Example for Phase 2 Action 1: "AC: /gsd:fast executes a single-file change inline, produces a git commit, updates MEMORY.md, and completes in < 2 minutes."
10. **Add a coexistence test for context monitor + pre-compact.sh**: define the test scenario (long session -> context monitor fires -> shortly after, compaction triggers -> verify MEMORY.md is coherent).
11. **Test graceful degradation for each optional feature**: /gsd:review with no CLIs, /gsd:autonomous with WAITING.json, /gsd:thread resume after session end.

### Step 5: Address the meta-workflow gap

12. **Document this sync analysis as a repeatable process** in docs/solutions/workflow/upstream-sync-process.md. Next time CE or GSD updates, follow the same structure: delta analysis -> gap identification -> prioritized recommendations -> phased rollout with rollback.
13. **Consider a /template-sync skill** that automates the changelog comparison and gap identification for future upstream updates.

---

## Summary of Findings

| Category | Gaps Found | Critical | Important | Nice-to-have |
|----------|-----------|----------|-----------|--------------|
| Rollback/Recovery | 3 (R1-R3) | 2 | 1 | 0 |
| Feature Overlap | 5 (O1-O5) | 0 | 5 | 0 |
| Token Economics | 3 (T1-T3) | 1 | 2 | 0 |
| Testing/Validation | 3 (V1-V3) | 0 | 3 | 0 |
| Sequencing | 3 (S1-S3) | 1 | 2 | 0 |
| Security/Safety | 2 (X1-X2) | 1 | 1 | 0 |
| Missing Flows | 5 (M1-M5) | 0 | 3 | 2 |
| **Total** | **24** | **5** | **17** | **2** |

The plan is thorough in identifying WHAT upstream features exist and recommending their integration. Its primary weaknesses are:

1. **No rollback/recovery procedures** for the most critical phase (upstream updates)
2. **Overlapping features without clear boundaries** (5 capture commands, 3 memory layers, 2 review systems)
3. **No validation strategy** for any phase beyond Phase 1
4. **Missing dependency ordering** relative to the Layer 2 retention gaps plan
5. **CLAUDE.md.template growth risk** that could undermine the very features being added

The recommendations above are ordered by priority. Steps 1-2 should be resolved before any implementation begins.
