# Validation Loop — Steps 3-4 Detail

> Loaded by `/execute-phase-auto` Steps 3-4. Covers the multi-agent
> validation, the fix loop, the Fix Escalation Gate cap, and the
> `/close-phase` handoff. This step is the deliberate FORGED agentic SDLC seed.

## Step 3 — Multi-agent validation

After execution completes, validate the phase diff with parallel review
agents. Reuse the agent pattern from `/prepare-phase` Steps 3+4 — spawn the
intra-Anthropic reviewers via the Agent tool (`model: "sonnet"`), Codex and
Gemini via Bash CLI.

### Validator agents (parallel)

| Agent | Scope | Condition |
|-------|-------|-----------|
| `correctness-reviewer` | Logic, spec/AC compliance, regressions | Always |
| `testing-reviewer` | Test coverage, real-chain exercise, failure paths | Always |
| `security-reviewer` | Auth, secrets, public surface, data exposure | **Conditional** — only if the diff touches auth / secrets / public surface |
| Codex adversarial | Cross-model adversarial pass on the diff | Always attempt — skip only if CLI unavailable |
| Gemini adversarial | Cross-model adversarial pass on the diff | Always attempt — skip only if CLI/key unavailable |

- The exact Codex and Gemini command patterns (availability checks, model
  fallback chain, adversarial prompt) live in `.claude/skills/{{project}}-review/SKILL.md`
  Step 5 (Codex) and Step 6 (Gemini). **Point to them — do not inline them.**
  Input is the phase diff (`git diff main`), not a PLAN.md.
- Never block validation on the presence of Codex or Gemini — they are bonus
  cross-model checks. Record the attempt + skip reason if unavailable.

### Consolidation

Wait for all agents. Merge findings into a single verdict table, severity-ranked
(P0/P1/P2/P3). If Codex and Gemini both produced findings, build the cross-model
consensus table (format: `{{project}}-review/SKILL.md` Step 7) — a finding seen by
both models is HIGH confidence, treat as P1 minimum.

## The fix loop — atomic iteration under a run-budget

The fix loop is a **single serialized state machine** over one stable diff
snapshot at a time, **one live fix worker** at most, bounded by a deterministic
**run-budget** (`run_budget.max_fix_iterations` in the phase CONTEXT.md, default
`8`; the initial validator batch above is **iteration 0**, excluded). Canonical
design + cross-vendor GO (Codex + Gemini, 2026-06-04):
`.claude/workspace/2026-06-04-execute-phase-auto-run-budget-spec.md` (Rev 4).

### One atomic iteration

1. **Consolidate** all findings on one stable snapshot.
2. **Evaluate stops in STRICT order** — the first that applies wins:
   a. **Danger hard-stop** — any finding on a `references/danger-classification.md`
      surface → `DANGER_HALT`. Never auto-fix a danger finding, even a "small" one.
   b. **Fix Escalation Gate** (below) → `ESCALATION_HALT`.
   c. **Run-budget** — a residual non-danger P1/P0 exists AND
      `fix_iterations == max_fix_iterations` → `BUDGET_HALT`.
3. **Clean exit (NOT a halt):** no residual non-danger P0/P1 → `CLEAN_COMPLETE`
   (or `NONBLOCKING_COMPLETE` if only P2/P3 remain). A clean tree is a COMPLETE,
   never a halt.
4. **Authorize + run ONE fix (atomic):** residual non-danger finding exists AND
   `fix_iterations < max_fix_iterations`:
   - **increment `fix_iterations` by 1 NOW, at authorization** — the single
     authoritative update point; never re-counted afterward, whatever the outcome;
   - dispatch exactly one fix agent (`coder`, `model: "sonnet"`);
   - run **one FULL-SLATE validator batch on the resulting snapshot — the full
     parallel slate AND a fresh danger-classification pass** (a fix worker can
     never inject danger against a stale map). **No partial single-validator reruns.**
   - outcome branches: `validated` → loop; `worker_failed` → `FIX_FAILURE_HALT`;
     `no_diff` (worker changed nothing) → skip the redundant revalidation, recycle
     findings, log a failed attempt to the Fix Escalation Gate, loop.

   P2/P3 findings never trigger a fix — surfaced for the user's judgment.

No mutated-but-unvalidated tree ever exists: every fix is immediately followed by
its full-slate revalidation before the next stop evaluation.

### Fix Escalation Gate — anti-thrashing cap

Orthogonal to the run-budget (volume ceiling), the loop is also bounded by the
**Fix Escalation Gate** of `.claude/rules/verification-discipline.md` §
"Fix Escalation Gate" — the canonical source; do not copy it here. Apply as written:

- **STOP after 3 distinct failed fix attempts** on the same finding (backstop).
- **STOP before attempt N+1** if fix N reveals a problem in a *different location*
  than fix N-1 (architectural-coupling signal — the primary trigger).
- Environment/syntax errors (expired credential, missing version, typo) are
  retryable, not distinct attempts; logic/functional regressions do count.

`--autonomous` does not bypass it. On fire, write the 3-attempt summary (each
attempt + symptom location). A finding's identity (for "same finding") = AST
symbol / block-hash where available, else a **diff-mapped** line-range — so a
line-shift from an added import does not reset the count.

### Terminal states & continuation (halt-only — no in-loop resume)

Step 3 ends in exactly one terminal state: `CLEAN_COMPLETE`, `NONBLOCKING_COMPLETE`,
`DANGER_HALT`, `ESCALATION_HALT`, `BUDGET_HALT`, `PARSE_HALT` (a malformed/
out-of-range `run_budget` block → **hard halt; never widen to defaults**),
`FIX_FAILURE_HALT`. **Every `*_HALT` is terminal — there is no in-loop resume.**

- `*_COMPLETE` → Step 4 (verdict), both modes.
- `*_HALT`, **interactive** → surface the halt (below) + solicit the human. To
  continue after a `BUDGET_HALT`: the operator raises `run_budget.max_fix_iterations`
  in the phase CONTEXT.md and **re-invokes `/execute-phase-auto`** — a fresh run
  (fresh Step-1 danger classification, fresh iteration-0 batch, counter from 0).
  Prior fixes are preserved/committed on the phase branch; a fresh run re-validates,
  never rolls back.
- `*_HALT`, **`--autonomous`** → terminate **non-zero** (`ERR_BUDGET_HALT` /
  `ERR_DANGER_HALT` / …), preserve the last stable snapshot, **no interactive wait**.

### Halt surface — decision aid (executive summary FIRST)

On any `*_HALT`, surface, top-first:
- **one-line verdict + recommended action** ("4 findings remain, converging ↓; to
  continue set `max_fix_iterations: 11` + re-invoke — OR stop, the 3 residual are
  Low, human judgment"). On the **first** budget-touched phase add: "default 8 is a
  seed with no prior data — record actual iterations for calibration."
- **convergence-trend table** — severity columns **High / Med / Low** (validator
  severity, distinct from the danger classifier's P0/P1/P2); trend `— ↓ → ↑`, with
  ↑ (regression) flagged + net-new count.
- **composition** (net-new / regression cleanup / re-fix); >2 iterations on the
  same finding identity → flag as a **"same-finding thrash"** signal.
- **deferred findings** + current Fix-Escalation status + **partial-work note**
  ("fixes preserved/committed to the phase branch; a fresh run re-validates only").

## Step 4 — Verdict + handoff

Present the consolidated validation verdict:

```
## Validation Verdict — Phase {N}

### Validator findings
{P0/P1/P2/P3 table, with cross-model consensus column if both ran}

### Fix loop
{fixes applied + re-validation result, or "no auto-fixes needed",
 or "escalation gate fired — {finding}, see 3-attempt summary"}
{run-budget: {fix_iterations}/{max_fix_iterations} iterations used — log for calibration}

### Danger hard-stops
{list of danger boundaries hit during execution + their resolutions}

### Verdict
{terminal state: CLEAN_COMPLETE / NONBLOCKING_COMPLETE / DANGER_HALT /
 ESCALATION_HALT / BUDGET_HALT / PARSE_HALT / FIX_FAILURE_HALT — {reason}.
 On any *_HALT in interactive mode, render the § "Halt surface" block above.}

### Recommendation
Phase executed and validated. Propose: /close-phase {N}
```

Then **propose** `/close-phase {N}` — never run it automatically. Closure
(SUMMARY, MEMORY update, todo triage, commit-push proposal) is the user's
decision and is owned by the `/close-phase` orchestrator. After Step 4, the
suspended `workflow-guide.md` transitions resume.
