---
name: execute-phase-auto
description: >
  Orchestrates autonomous phase execution around /gsd:execute-phase, with danger-gated human
  solicitation and a multi-agent validation loop. Twin of /prepare-phase for the execution side.
  Invoke with /execute-phase-auto {N} or /execute-phase-auto {N} --autonomous.
  Triggers on: execute-phase-auto, exécution autonome de phase.
---

# /execute-phase-auto — Autonomous Phase Execution Orchestrator

Run a planned GSD phase end-to-end with one command: gate check, danger classification,
autonomous execution, multi-agent validation, verdict.
Does NOT modify the underlying skills (GSD, {{project}}:review) — calls them in sequence.
Does NOT auto-close — closure is the user's decision after the verdict.
Deliberate seed for the future FORGED agentic SDLC.

## References

| Fichier | Charger quand |
|---------|---------------|
| `references/danger-classification.md` | Step 1 — scanning PLAN files, building the danger map |
| `references/execution-flow.md` | Steps 0-2 — gate check, /gsd:execute-phase call, danger hard-stops |
| `references/validation-loop.md` | Steps 3-4 — validator agents, fix loop, escalation gate, /close-phase handoff |

## Usage

- `/execute-phase-auto {N}` — interactive mode (default): danger map confirmed by the user
- `/execute-phase-auto {N} --autonomous` — autonomous mode: zero prompts except danger hard-stops

## Workflow

- **Step 0 — Gate check.** Verify `PLAN-CHECKER-PASS` marker AND a GO / CONDITIONAL GO pre-flight verdict exist for the phase. Absent → refuse, route to `/prepare-phase {N}`. See `references/execution-flow.md`.
- **Step 1 — Danger classification.** Run the **deterministic scan** in `references/danger-classification.md` over the phase `*-PLAN.md` files — a fixed pattern, not a judgment call. The LLM may escalate a scan `no→yes`, but can NEVER downgrade a scan `yes`. Present the danger map. Interactive: user confirms. Autonomous: proceed.
- **Step 2 — Autonomous execution.** Call `/gsd:execute-phase {N}`. Non-dangerous plans run unprompted; every danger boundary triggers a hard-stop awaiting the human. See `references/execution-flow.md`.
- **Step 3 — Multi-agent validation.** Spawn parallel reviewers on the diff (correctness, testing, conditional security, Codex + Gemini adversarial). P1/P0 on non-dangerous code → dispatch a fix agent and re-validate; danger-surface finding → hard-stop. See `references/validation-loop.md`.
- **Step 4 — Verdict + handoff.** Present the validation verdict, propose `/close-phase {N}`. See `references/validation-loop.md`.

## Behavior Rules

- Each step waits for the previous to complete (except parallel agent groups in Step 3).
- Error in any step → stop the chain and diagnose for the user; never silently continue.
- **`--autonomous` NEVER bypasses a danger hard-stop** — danger always solicits the human, both modes.
- **`--autonomous` NEVER bypasses the Fix Escalation Gate** of `.claude/rules/verification-discipline.md`: the fix loop STOPS and solicits the human after 3 distinct failed attempts, OR when fix N reveals a problem in a different location than fix N-1. Applies to non-dangerous findings too — anti-thrashing protection.
- **`--autonomous` NEVER bypasses the run-budget.** Step 3's fix loop is a single atomic-iteration state machine (`1 fix = 1 full-slate revalidation incl. a fresh danger pass = 1 increment, counted at authorization`) bounded by `run_budget.max_fix_iterations` (phase CONTEXT, default 8; iteration 0 = initial batch, excluded). Stop conditions evaluate in **strict order danger → Fix Escalation Gate → run-budget**; the first fires a terminal halt. **No in-loop resume** — continue by raising the cap in CONTEXT and re-invoking (a fresh run). In `--autonomous`, any halt exits non-zero, never waits. See `references/validation-loop.md` (canonical: `.claude/workspace/2026-06-04-execute-phase-auto-run-budget-spec.md`, cross-vendor GO).
- Never auto-close the phase — `/close-phase {N}` is always a proposal.
- **Suspends `workflow-guide.md` transitions**: while this skill is active the automatic post-execution transition does not fire — this orchestrator owns the sequence through Step 4. Normal transitions resume after Step 4.

## MCP Routing

> Exemption : skill d'orchestration pur — aucune dépendance MCP. Codex/Gemini sont appelés via CLI (Bash), les validateurs via l'outil Agent. Rien à router.

## What this skill does NOT do

- Modify GSD, {{project}}:review, or any upstream skill — it only calls them
- Execute a phase whose gate (Step 0) is not satisfied
- Bypass a danger hard-stop, even in `--autonomous` mode
- Bypass the Fix Escalation Gate of `verification-discipline.md`
- Continue the Step-3 fix loop past `run_budget.max_fix_iterations`, carry run-budget state across invocations, leave a mutated-but-unvalidated tree, or conflate a clean `*_COMPLETE` with a halt
- Auto-close the phase or run `/close-phase` without user confirmation
- Retry a failed `/gsd:execute-phase` wave automatically
