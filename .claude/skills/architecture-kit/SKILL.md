# Architecture Kit — Generate & Update Architecture Artefacts

Generate or update the standard architecture documentation for a solution.
Two modes: **create** (after plan-phase) and **update** (at closure).

---

## Usage

```
/architecture-kit {slug}                    # Create mode (default)
/architecture-kit {slug} --update           # Update mode (closure)
```

**Triggers:** "architecture-kit", "architecture kit", "generate architecture", "architecture artefacts".

---

## Slug Discipline — the unit is the capability, not the phase

`{slug}` MUST name a **durable product capability or system** (kebab-case) — never a
phase number. A phase is a unit of *work* (ephemeral); the capability is a unit of
*product* (durable). The capability owns the architecture dir; every phase that touches
it updates the same dir.

| Correct | Wrong |
|---------|-------|
| `billing` | `15-billing-stripe-pad-...` |
| `{{hosting_vendor}}-infra-hardening` | `15.2-{{hosting_vendor}}-infra-hardening` |
| `cascade-workflow-decomposition` | `14.4-cascade-...` |

- A phase that **extends** an existing capability re-uses that capability's slug and
  runs `--update`. It does NOT create a new phase-numbered dir.
- A phase that **builds a new capability** creates `docs/architecture/{capability-slug}/`.
- If unsure which capability a phase maps to, check `LIVE-ARCHITECTURE.md` § Per-Solution
  before creating anything.

### Mandatory pre-proposal protocol

Before ANY proposal of a slug, the agent MUST answer (in the output, to the user) two
framing questions:

1. **What durable feature is being shipped?** — one sentence, in product terms (not in
   phase terms, not in "we add X to Y" terms).
2. **What will this capability be called in 6 months when 3 phases have extended it?** —
   if the answer involves multiple phase numbers, the slug must abstract above them.

If the answer to question 2 contains a phase number instead of a feature name, the slug
is wrong — STOP and reformulate.

**Guardrail (hard)**: any candidate slug containing a phase number pattern
(`\d+(\.\d+)?-…`, e.g. `24.7-…`, `15.2-…`, `16-…`) is REJECTED. Reframe before proceeding.

---

## When To Use

| Moment | Mode | Invocation |
|--------|------|-----------|
| After `/gsd:plan-phase`, before `/document-review` and `/pre-flight` | **Create** | `/architecture-kit {slug}` |
| After any PLAN.md revision (document-review findings, deepen, pre-flight NO-GO) | **Create** (re-run) | `/architecture-kit {slug}` |
| At closure, after execution | **Update** | `/architecture-kit {slug} --update` |
| Manual, anytime | Either | `/architecture-kit {slug}` or `/architecture-kit {slug} --update` |

`/prepare-phase` calls this automatically after plan-phase and before document-review / pre-flight.
Re-run whenever PLAN.md changes after the initial generate — before the next downstream review or gate.
Closure protocol calls `--update` automatically if architecture artefacts exist for the solution.

---

## Create Mode

### Step 0 — Capability framing (mandatory pre-step)

BEFORE reading any PLAN.md or proposing artefacts, output the following framing and
wait for explicit user confirmation of the slug:

```
Capability framing for `{invocation slug}`:

  Feature being shipped (one sentence):
    {durable capability in plain product terms}

  Existing kits checked for overlap (LIVE-ARCHITECTURE.md § Per-Solution):
    - {nearest kit 1} → how this new kit is distinct
    - {nearest kit 2} → how this new kit is distinct

  Proposed slug: {capability-slug}
  Phases that will touch this capability over time: [{current N}] + {others if foreseeable}

  Confirm slug? [Yes / Adjust]
```

If the user adjusts the slug, restart Step 0 with the new slug. Do not proceed to
Step 1 until the slug is explicitly confirmed.

Apply the **Slug Discipline guardrail** (above): if the candidate slug contains a phase
number pattern (`\d+(\.\d+)?-…`), STOP and reframe — do not even present it.

### Step 1 — Read Context

1. Read the PLAN.md of the active phase (from `.planning/`)
2. Read `docs/templates/architecture/README.md` for the decision rules
3. Read existing artefacts in `docs/architecture/{slug}/` if any

### Step 2 — Evaluate Artefacts

Apply the decision rules from the README:

**Core (always):**
- Solution Architecture
- Logical Architecture
- Security Architecture
- Operating Model
- Deployment Architecture (if runtime exists)
- Solution Diagram (`.excalidraw` preferred, Mermaid `.md` fallback)

**Optional — evaluate each trigger:**

| Artefact | Trigger | Check in PLAN.md |
|----------|---------|-----------------|
| Data Architecture | BDD, analytics, PII, rétention | Data model, PII mentioned, storage decisions |
| Integration Architecture | Multiple SaaS / APIs / webhooks / queues / connectors | External system dependencies, API calls, webhooks |
| Domain / Business Architecture | Complex business rules, pricing, workflows, multi-actors | Business rules, approval flows, billing logic |
| ~~Solution Diagram~~ | *Moved to Core (always produced)* | — |

**Plans instanciés — evaluate:**

| Plan | Trigger | Check |
|------|---------|-------|
| Migration Plan | Existing system being modified | Migration steps, coexistence, cutover in PLAN.md |
| Deployment Plan | First rollout or major infra change | New services, new environments in PLAN.md |

### Step 3 — Propose To User

Present the artefact list:

```
Architecture Kit for {slug}:

CORE:
  ✓ Solution Architecture
  ✓ Logical Architecture
  ✓ Security Architecture
  ✓ Deployment Architecture
  ✓ Operating Model

OPTIONAL (triggered):
  ✓ Integration Architecture — {reason}
  ✗ Data Architecture — no BDD/PII detected
  ...

PLANS:
  ✓ Deployment Plan — first rollout detected
  ✗ Migration Plan — no existing system modified

Confirm? [Yes / Adjust]
```

Wait for user confirmation. One interaction only.

### Step 4 — Generate

For each confirmed artefact:

1. Create `docs/architecture/{slug}/` directory
2. Copy template, replacing `{Solution}` and `{solution-slug}` placeholders
3. Pre-fill sections from PLAN.md context where possible:
   - Solution Architecture § Scope, § Decisions from PLAN.md decisions
   - Logical Architecture § Components from PLAN.md component list
   - Security Architecture § Auth model from PLAN.md threat model
   - Integration Architecture § Systems from PLAN.md dependencies
4. Set frontmatter: `status: draft`, `last_verified: {today}`, `owner: {{OWNER}}`,
   `slug: {capability-slug}`, `phases: [list of phases that touched this capability]`
   (a capability is touched by multiple phases over time — use a list, not a single `phase:`)

### Step 5 — Solution Diagram (core — always produced)

The solution diagram is a core artefact. It provides the visual architecture overview that complements the markdown documents.

**Step 5a — Check skill availability and select format:**

| Condition | Format | Output file |
|---|---|---|
| `/excalidraw-diagram` skill available | Excalidraw (preferred) | `docs/architecture/{slug}/{slug}-solution-diagram.excalidraw` + `.png` |
| `/excalidraw-diagram` skill NOT available | Mermaid (fallback) | `docs/architecture/{slug}/{slug}-solution-diagram.md` |

**Step 5b — Read source material:**

1. Read the just-generated artefacts:
   - Solution Architecture → components list, scope
   - Logical Architecture → component relationships, boundaries
   - Security Architecture → auth model, encryption, trust boundaries

**Step 5c — Generate diagram:**

**If Excalidraw (preferred):**
1. Invoke `/excalidraw-diagram` with a **simple/conceptual** depth level and these instructions:
   - **Components**: Main system components as rectangles, sized by importance
   - **Data flow**: Arrows between components showing high-level data movement (not every API call — just the essential flows)
   - **Security annotations**: Trust boundaries (dashed lines), auth mechanisms (labels), encryption points (lock annotations)
   - Pattern: typically **assembly line** or **fan-out** depending on system topology
   - No evidence artifacts, no code snippets — this is a conceptual overview
2. Render & validate per excalidraw skill rules (2-4 iterations)
3. Output: `.excalidraw` + rendered `.png`

**If Mermaid (fallback):**
1. Create `docs/architecture/{slug}/{slug}-solution-diagram.md` with:
   - A YAML frontmatter: `title`, `status: draft`, `last_verified: {today}`, `format: mermaid`
   - A `## Solution Diagram` heading
   - A Mermaid `flowchart` or `graph` block showing the same content as the Excalidraw version would:
     - Main components as nodes, sized/styled by role (subgraphs for boundaries)
     - Data flows as labeled arrows
     - Trust boundaries as subgraph borders
     - Color coding via Mermaid `style` or `classDef` directives
   - A `## Diagram Notes` section explaining the key flows and any color/style conventions used
2. No render step needed — Mermaid renders natively in GitHub, VS Code, and most markdown viewers

### Step 6 — Link & Index

- Add to Solution Architecture § 9 "Artefacts associés": links to all generated artefacts (including diagram if generated)
- In the PLAN.md, add a section or note: `Architecture: docs/architecture/{slug}/`
- In `docs/architecture/LIVE-ARCHITECTURE.md`, add or update a row in the `## Per-Solution Architecture` table: `{slug}` → `docs/architecture/{slug}/` → `draft`
- **Graphify sync**: run `/graphify docs/architecture/{slug}/ --update --no-viz` to index the new artefacts into the knowledge graph. If graph not yet built, skip silently.

Report: `Architecture kit generated → docs/architecture/{slug}/ ({N} artefacts{, + diagram if applicable})`

---

## Update Mode (--update)

Used at closure to reconcile artefacts with reality.

### Step 0 — Slug sanity (mandatory pre-step)

Before reading anything:

1. Apply the **Slug Discipline guardrail** — if `{slug}` contains a phase number
   pattern (`\d+(\.\d+)?-…`), STOP and reframe to the durable feature name.
2. Verify `docs/architecture/{slug}/` exists. If not, the capability has no kit yet —
   suggest Create mode instead (`/architecture-kit {slug}` without `--update`).
3. Read the frontmatter `phases:` list of an existing artefact — confirm the current
   phase belongs to this capability (or should be added to the list). If the phase
   maps to a different capability, redirect to that capability's slug instead.

### Step 1 — Read Context

1. Read PLAN.md of the phase
2. Read SUMMARY.md of the phase (planned vs actual, deviations)
3. Read existing artefacts in `docs/architecture/{slug}/`

### Step 2 — Identify Deviations

Compare PLAN.md vs SUMMARY.md. For each deviation:
- Does it impact an architecture artefact?
- Which section specifically?

### Step 3 — Propose Updates

```
Architecture Kit Update for {slug}:

Deviations detected:
  - {deviation 1} → impacts Logical Architecture § Components
  - {deviation 2} → impacts Deployment Architecture § Services

Propose updates:
  1. Logical Architecture: add component X, update flux Y
  2. Deployment Architecture: update service list

Solution Diagram (core):
  ⚠ Diagram may be impacted by deviations {1, 2} — regenerate? [Yes / Skip]

Apply? [Yes / Adjust / Skip]
```

If diagram regeneration is confirmed, re-run Step 5 from Create Mode using the updated artefacts as source.

### Step 4 — Apply

For each confirmed update:
1. Edit the artefact section
2. Bump `last_verified` to today
3. Change `status` from `draft` to `active` for artefacts that now reflect reality

Report: `Architecture kit updated → {N} artefacts modified, status: active`

---

## Maintenance Alerts

The skill also supports a maintenance check (invoked at session start or manually):

```
/architecture-kit --check
```

Scans all `docs/architecture/*/` for artefacts where `last_verified` > 180 days.
Also checks for `.excalidraw` diagrams that may be stale relative to their companion markdown artefacts.
Reports stale artefacts with recommendation to review.

---

## Behavior Rules

- `{slug}` is always a durable capability name, never a phase number (see § Slug Discipline)
- **Step 0 (Capability framing in Create / Slug sanity in Update) is mandatory** — skipping it is a discipline violation, not an optimization
- A candidate slug containing a phase-number pattern (`\d+(\.\d+)?-…`) is REJECTED at Step 0 — reframe before presenting anything to the user
- Never generate artefacts without user confirmation
- Never modify PLAN.md beyond adding an architecture pointer
- Pre-fill from context but leave sections empty if no data available — don't invent
- One interaction for create, one for update — not chatty
- If no PLAN.md exists for the phase, stop and report error
- Templates live in `docs/templates/architecture/` — always read fresh, never cache

## Consultation data-compliance-advisor

**Quand consulter :**
- Conception d'un systeme qui collecte, stocke, ou traite des renseignements personnels
- Conception d'un flux de donnees inter-juridictions (QC -> US, QC -> EU, etc.)
- Definition d'un schema DB contenant PII, PHI, ou donnees financieres
- Design d'un systeme multi-tenant ou l'isolation de donnees impacte la conformite ({{COMPLIANCE_FRAMEWORK_PRIMARY}} art. 3.3, 3.5)
- Design d'une integration tierce qui partage des PI avec un sous-traitant
- Redaction d'une ADR (Architecture Decision Record) qui touche privacy ou data residency

**Ne pas consulter :**
- Design d'un systeme purement interne sans PI (ex: CI/CD pipeline, build system)
- Choix de librairie / framework sans impact sur les donnees
- Refactor structurel sans changement de flux de donnees

**Pattern :**
```
1. Rediger le draft ADR ou architecture note
2. Avant validation, invoquer data-compliance-advisor avec payload :
   { "context": "architecture-decision",
     "artifact_path": "<path to ADR or design doc>",
     "jurisdictions": ["QC", "CA"],
     "data_categories": [<categories PI/PHI/financial>],
     "data_flows": [<source -> destination avec juridictions>],
     "retention_plan": "<duree + justification>" }
3. Integrer les recommandations DCA dans la section "Privacy & Compliance" de l'ADR
4. Documenter les mitigations retenues (minimisation, consentement, contrats sous-traitant, etc.)
```

**Sources canoniques :**
- Lois : `docs/references/frameworks/loi25.md`, `docs/references/frameworks/pipeda.md`, `docs/references/frameworks/loi5.md`
- DCA integration patterns : `.claude/skills/data-compliance-advisor/references/integration-patterns.md`

---

## What This Skill Does NOT Do

- Define the architecture framework (that's `docs/templates/architecture/README.md`)
- Replace solution architecture decisions (that's the architect's job)
- Execute code or deploy (that's SPARC's job)
- Review artefacts (that's `/{{project}}:review` or `/pre-flight`)
