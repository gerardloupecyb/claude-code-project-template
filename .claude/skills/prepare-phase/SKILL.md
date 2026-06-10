---
name: prepare-phase
description: >
  Orchestrates the full phase preparation sequence. Supports `--autonomous` for zero-interaction mode.
  Invoke with /prepare-phase {N} or /prepare-phase {N} --autonomous.
  Triggers on: prepare-phase, prepare phase, phase preparation.
---

# Prepare Phase — Phase Preparation Orchestrator

Run the full preparation sequence for a GSD phase with one command.
Does NOT modify the underlying skills (GSD, CE, pre-flight) — calls them in sequence.
Does NOT launch execution — that's the user's decision after the Pre-Flight verdict.

---

## Usage

- `/prepare-phase {N}` — interactive mode (default): step-by-step with optional checkpoints
- `/prepare-phase {N} --autonomous` — autonomous mode: zero prompts, parallel agents, consolidated report

---

## Interactive Mode (default)

Runs the preparation sequence with optional user checkpoints at Steps 0.5, 1.5, 5, and 7.5.
Steps 3 and 4 run in parallel. Best for new features, user-facing phases, or sensitive changes.

### Step 0 — Context Capture (Agent-delegated)

Delegated to an Agent tool so it runs outside the main context window.

Agent reads: CLAUDE.md, LESSONS.md, `.claude/rules/*.md` (domain-relevant), source files (patterns).
Agent writes: `.claude/workspace/context-capture-{N}.md` with sections:
- `## Stack détectée` — languages, frameworks, active MCPs
- `## Patterns existants` — file:line + brief description
- `## Conventions établies` — non-negotiable rules from CARL/rules
- `## Gotchas documentés` — relevant LESSONS.md entries
- `## Questions à lever` — ambiguities detected before discuss

Agent returns: path to context-capture file + 200-word summary.
Pass file path to Step 1 as additional context.

### Step 0.5 — Product Clarity Check (ONE interaction, OPTIONAL)

Runs `/office-hours {N}` — quick product interrogation before planning.
Skip if phase is infra/tooling with no user-facing surface.

Ask user once: "Run product clarity check? [Yes / Skip]"

### Step 0.6 — Deep External Research? (ONE interaction, OPTIONAL)

Runs `/deep-research "<scoped question>"` — deep multi-source, fact-checked external research.
Complements (does NOT replace) the implementation-oriented research that `/gsd:plan-phase` runs
internally via `gsd-phase-researcher` (WebSearch + Context7).

When to run: phase introduces a new tech, a vendor/tool comparison, or an external/regulatory unknown
({{COMPLIANCE_FRAMEWORK_PRIMARY}} / {{COMPLIANCE_FRAMEWORK_HEALTH}} / {{COMPLIANCE_FRAMEWORK_FEDERAL}}, new {{CLOUD_PROVIDER}}/{{CRM_PLATFORM}} capability, market/competitive question).
Skip for: infra, tooling, refactor, or any phase whose unknowns are internal-only.

- Derive the question from the phase CONTEXT.md + Step 0 context-capture. Scope it to the **external
  unknown only** — avoid re-running the web research `gsd-phase-researcher` already does (no double spend).
- Frame {{PROJECT}} regulatory context explicitly when relevant ({{COMPLIANCE_FRAMEWORK_PRIMARY}} art. 17 cross-border, {{COMPLIANCE_FRAMEWORK_HEALTH}} {{COMPLIANCE_FRAMEWORK_HEALTH}}, {{COMPLIANCE_FRAMEWORK_FEDERAL}}).
- Output: cited report written to `.claude/workspace/deep-research-{N}.md`.
- Feed the report into Step 1 (discuss) and Step 2 (plan) as additional context — to **enrich** RESEARCH.md, not duplicate it.

Ask user once: "Run deep external research? [Yes / Skip]"

### Step 1 — Discuss Phase (automatic)

```
/gsd:discuss-phase {N}
```

Pass context-capture output from Step 0 (and the deep-research report from Step 0.6, if run). Stop on error.

### Step 1.5 — CEO Lens Challenge (ONE interaction, OPTIONAL)

Runs `/plan-ceo-review {N}` — challenges the discuss output from a CEO lens.

Ask user once: "Run CEO lens review? [Yes / Skip]"

### Step 2 — Plan Phase (automatic)

```
/gsd:plan-phase {N}
```

Produces PLAN.md. Stop on error.

### Steps 3+4 — Architecture + Document Review + Cross-Model Adversarial (PARALLEL)

Run simultaneously using four Agent tools. Agents C and D are **mandatory attempts** — they must be invoked every run, and only skipped if their runtime is genuinely unavailable (CLI missing, env var unset, quota exhausted).

- **Agent A**: `/architecture-kit {slug}` — generates architecture artefacts in `docs/architecture/{slug}/`
- **Agent B**: `/document-review PLAN.md` — runs 7 persona agents against PLAN.md
- **Agent C**: **Codex adversarial review of PLAN.md** (cross-model challenge)
  - Availability check: `which codex && codex --version` (skip only if CLI missing)
  - Invocation pattern: run `codex exec` with a prompt that ingests the full PLAN.md content **and the real target files the plan makes premises about** (see § Target-File Grounding below) and asks Codex to identify logic errors, hidden assumptions, unstated dependencies, **premise-vs-file mismatches**, edge cases, security gaps, and over-engineering risks. Model: OpenAI reasoning-first (`o3` or latest available).
  - Output: findings block written to `.claude/workspace/prepare-phase-{N}-codex-adversarial.md`
  - If skipped, write a stub noting the reason (`CLI not installed` | `auth failure`)
- **Agent D**: **Gemini adversarial review of PLAN.md** (cross-model challenge, parallel to Codex)
  - Availability check: `which gemini 2>/dev/null && [ -n "$GEMINI_API_KEY" ]` (skip only if CLI missing or env var unset)
  - Invocation pattern: `gemini -m "gemini-3-pro-preview" --yolo -p "<adversarial prompt with full PLAN.md content + target-file excerpts>"` — identical prompt shape to Agent C (incl. § Target-File Grounding) so findings are comparable
  - Fallback chain: if output contains `QuotaError|quota`, retry with `gemini-3-flash-preview`
  - Output: findings block written to `.claude/workspace/prepare-phase-{N}-gemini-adversarial.md`
  - If skipped, write a stub noting the reason (`CLI not installed` | `GEMINI_API_KEY unset` | `quota exhausted (both pro and flash)`)
- The exact command patterns and adversarial prompt template live in `.claude/skills/{{project}}-review/SKILL.md` Step 5 (Codex) and Step 6 (Gemini) — reuse them verbatim. **Critical framing difference:** {{project}}-review feeds the reviewer `git diff main` (real code already written); here the input is PLAN.md (claims about code not yet written). A plan can assert a premise the actual code/config contradicts — that is exactly the Phase 04.7 (live AA leak in prod cascade) / Phase 14.2 (cascade Route nodes not checking `Status='Skipped'`) failure class. So the input is **not** "PLAN.md instead of git diff" — it is PLAN.md **plus** the real target files (below).

**§ Target-File Grounding (obligatoire pour Agents C + D — cf. `.claude/rules/verification-discipline.md` § "Plan-Checker ≠ Adversarial Review")**

PLAN.md = des *claims* sur du code/config existant ou à venir. Un finding qui ne fait que reformuler la logique interne du plan reproduit l'angle mort du plan-checker (structure, pas sémantique). Avant de raisonner, chaque agent adversarial doit :

1. **Extraire** de PLAN.md chaque artefact concret dont le plan affirme une prémisse : cascade/workflow JSON, fichiers source, configs, définitions de route, schéma DB, conditions IF/Switch, env vars, chemins.
2. **Lire le vrai fichier**, jamais sa description dans le plan : `jq` sur le JSON {{WORKFLOW_ENGINE}}/workflow, `grep`/`rg` sur le source, `ls` sur les chemins, `Read` sur les configs — injecter les extraits pertinents dans le prompt de l'agent.
3. **Tester chaque prémisse contre le fichier** : pour tout « le plan dit X sur le fichier F », confirmer que F fait réellement X. Tout écart = **BLOCKER** avec evidence (`file:line` ou jq-path). Un fichier cible introuvable = finding (le plan référence un chemin faux/inexistant).
4. **Pondération** : un finding ancré à une evidence-fichier est fort ; un finding sans evidence-fichier est faible et doit être signalé comme « non vérifié contre la cible ».

Wait for all four agents to complete. Synthesize findings:

1. If Agents C and D both produced findings, build a **cross-model consensus table** (see `.claude/skills/{{project}}-review/SKILL.md` Step 7 — reuse format). Append to PLAN.md under a `## Cross-Model Plan Review` section.
2. Merge document-review findings + Codex findings + Gemini findings into PLAN.md revisions.
3. If PLAN.md is revised substantially: re-run `/architecture-kit {slug}`.

**Never block** the prepare-phase sequence on the presence of Codex or Gemini — they are bonus cross-model checks, not prerequisites. But you **must not silently skip** them — always record the attempt + reason in the consolidated report.

**Cross-vendor confirmation (Phase 27.1.1 D-15):** For phases touching the named class
(auth + audit + route surface + scope-guard — see `.claude/rules/verification-discipline.md`
§ Cross-vendor adversarial review), the `ADVERSARIAL-REVIEW-PASS` marker requires BOTH Codex AND
Gemini PASS. Single-vendor results are insufficient. If a vendor is unavailable, BLOCK and resume
when both are reachable. Divergence between vendors is treated as NO-GO until reconciled.

### Step 5 — Deepen Plan? (ONE interaction)

Ask user once:

```
Plan ready. Deepen with /ce:deepen-plan? [Yes (recommended) / Skip]
```

- **Yes**: run `/ce:deepen-plan` on PLAN.md — automatic
- **Skip**: proceed to pre-flight immediately
- If PLAN.md revised substantially: re-run `/architecture-kit {slug}`

### Step 6 — Pre-Flight (automatic)

```
/{{project}}-pre-flight
```

Routes to the {{PROJECT}}-local `/{{project}}-pre-flight` wrapper (W1 fix per D-10): it invokes the upstream
`pre-flight` skill for the verdict, then strictly appends the autonomy-readiness advisory. Stop if
PLAN.md not found.

### Step 7 — Return Report

Present Pre-Flight verdict (GO / CONDITIONAL GO / NO-GO) with findings.

### Step 7.5 — CEO Final Gate (ONE interaction, OPTIONAL)

Runs `/plan-ceo-review {N} --final` — CEO lens on the final plan before execution.

Ask user once: "Run CEO final gate? [Yes / Skip]"

### Step 7.6 — Marker posing gate (gate-ordering Phase 27.2)

Dernière étape avant de déclarer le plan `Ready to execute`. `ADVERSARIAL-REVIEW-PASS` ne peut être posé QUE si les DEUX conditions tiennent :
- **(a)** Codex PASS ET Gemini PASS (cross-vendor confirmation — voir Steps 3+4 note, ligne ~127), ET
- **(b)** le Step 6 pre-flight a retourné **GO**.

Si pre-flight = CONDITIONAL GO ou NO-GO : **NE PAS poser le marker.** Résoudre les findings, re-run `/{{project}}-pre-flight`, et seulement sur GO poser/rafraîchir le marker. Un marker posé avant un pre-flight GO est stale-able par construction (cf. `.claude/rules/verification-discipline.md` § Iron Law amendée — gate-ordering Phase 27.2 : adversarial et pre-flight sont des lentilles orthogonales). Si un marker pré-existe et précède le pre-flight courant, le considérer stale et le re-poser après GO.

---

## Autonomous Mode (--autonomous)

Zero interactive prompts. All optional checkpoints run as agents. Best for infra/tooling phases.

| Step | Action | Mode |
|------|--------|------|
| 0 | Context Capture | Agent (same as interactive) |
| 0.5 | Product Clarity Check | Agent (auto-run, no prompt) |
| 0.6 | Deep External Research | Agent (auto-decide: run if external/regulatory/vendor surface, skip if infra/tooling/refactor) |
| 1 | Discuss Phase | Automatic |
| 1.5 | CEO Lens Challenge | Agent (auto-run, no prompt) |
| 2 | Plan Phase | Automatic |
| 3+4+5 | Arch + Review + Codex adv + Gemini adv + Deepen | PARALLEL (five agents — Codex and Gemini are mandatory attempts, skip only on CLI/quota unavailability) |
| 6 | Pre-Flight (`/{{project}}-pre-flight` wrapper — W1 per D-10) | Automatic |
| 7 | Consolidated Report | Single output |

Key differences from interactive mode:

| Aspect | Interactive | Autonomous |
|--------|-------------|------------|
| Steps 0.5, 0.6, 1.5, 5, 7.5 | User prompted (skippable) | Run as agents (auto-decide) |
| Steps 3+4 | 4 parallel agents (arch + review + codex adv + gemini adv) | Steps 3+4+5 all parallel (5 agents: + deepen) |
| Step 5 (deepen) | User choice | Auto-run as agent |
| Step 7.5 (CEO gate) | User choice | Skipped (folded into 1.5) |
| Output | Step-by-step | Single consolidated report |

### Consolidated Report Format

```
## Prepare Phase {N}: Consolidated Report

### Product Clarity (Step 0.5)
{Summary of office-hours findings, or "Skipped — infra/tooling phase"}

### Deep External Research (Step 0.6)
{Summary of /deep-research cited report + path, or "Skipped — internal-only unknowns"}

### CEO Lens (Step 1.5)
{Summary of plan-ceo-review findings}

### Document Review (Step 4)
{Summary of 7-persona review findings}

### Codex Adversarial Review (Step 4)
{Summary of Codex findings, or "Skipped — {reason}"}

### Gemini Adversarial Review (Step 4)
{Summary of Gemini findings + model used (pro/flash), or "Skipped — {reason}"}

### Cross-Model Consensus (Step 4)
{Table of findings seen by both Codex and Gemini with HIGH confidence, or "No cross-model overlap" if only one ran}

### Deepen Plan (Step 5)
{Summary of ce:deepen-plan output, or "No substantial changes"}

### Pre-Flight Verdict
{GO / CONDITIONAL GO / NO-GO} — {summary of findings}

### Recommendation
{Next step for the user}
```

---

## Behavior Rules

- Each step waits for the previous to complete (except parallel groups)
- Error in any step: stop the chain and diagnose for the user
- Interactive: Steps 0.5, 0.6, 1.5, 5, 7.5 are optional (1 question, 2 choices each)
- Autonomous: no AskUserQuestion calls — all decisions made automatically
- Never launch execution (`/sparc`, `/gsd:execute-phase`) — that's the user's decision
- **Suspends workflow-guide.md transitions**: when this skill is active, the automatic
  post-planning transition ("Plan prêt. Lancer l'execution ?") does NOT fire — this orchestrator
  owns the sequence through pre-flight. Resume normal transitions after Step 7 (or 7.5).

## What this skill does NOT do

- Modify GSD or CE skills
- Launch SPARC or execution
- Force deepen-plan in interactive mode
- Retry failed steps automatically
- Run interactive prompts in `--autonomous` mode
