---
name: rules-distill
description: >
  Distills repeating patterns from LESSONS.md into CARL rules.
  Identifies cross-cutting clusters and proposes rules for user validation.
  Triggers on: rules-distill, distill rules, lessons to CARL.
---

# Rules Distill — LESSONS → CARL Flywheel Automator

Automates the manual "promote a lesson to CARL" step in the flywheel.
Reads LESSONS.md, groups related lessons into clusters, proposes one CARL
rule per cluster for user validation.

---

## Usage

```
/rules-distill
```

---

## Process

### Step 1 — Read LESSONS.md

Read `LESSONS.md`, extract all entries from `## Lecons`.

If LESSONS.md is missing or has no lessons → report and stop:
```
Aucune leçon trouvée dans LESSONS.md.
```

### Step 2 — Identify clusters

Group lessons by shared domain or mechanism. A cluster requires ≥ 2 lessons with:
- Same technical area (hooks, models, tests, deployments, agents…)
- Same failure mode (race condition, auth gap, missing validation…)
- Same pattern ("always X before Y", "never Z without W")

If no cluster found → report and stop:
```
Pas assez de patterns répétés pour distiller une règle. Ajoutez des leçons.
```

### Step 3 — Formulate rules

For each cluster:

1. Identify the best-fit CARL domain (match to `.carl/` domain files)
2. Read `.carl/{domain}` — count existing rules to find next N
3. Draft rule: `{DOMAIN_UPPER}_RULE_{N}=Toujours X quand Y.`
4. List source lessons (date + first line of each)

### Step 4 — Present one at a time

For each proposed rule, present:

```
Règle proposée : HOOKS_RULE_3=Toujours exit 0 dans les hooks pour ne pas bloquer Claude.
Sources        :
  - [2026-03-16] Le deepening multi-agent previent les bugs structurels...
  - [2026-03-20] set -euo pipefail cause des crash dans les hooks...
Domaine CARL   : .carl/hooks

Valider ? [Oui / Modifier / Ignorer]
```

Wait for user response before presenting the next rule.

### Step 5 — Add validated rules

- **Oui** → invoke `/carl:tasks:add-rule` with the rule and domain
- **Modifier** → incorporate user's changes, confirm, then add
- **Ignorer** → skip, proceed to next

---

## Behavior Rules

- Never add a rule without explicit user validation
- Never write to or modify LESSONS.md
- One rule per cluster — do not split a cluster into multiple rules
- If `.carl/{domain}` does not exist → propose creating it, do not fail silently
- After all clusters processed → summarize: N rules added, N skipped
