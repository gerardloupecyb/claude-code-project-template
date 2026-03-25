---
title: "plan: Multi-LLM Task Router — Opus Orchestrator + Codex Executor"
type: plan
status: ready
date: 2026-03-20
deepened: 2026-03-20
---

# Multi-LLM Task Router: Claude Orchestrator + Codex MCP Executor

## Enhancement Summary

**Deepened on:** 2026-03-20
**Agents used:** architecture-strategist, spec-flow-analyzer, code-simplicity-reviewer, agent-native-reviewer, best-practices-researcher

### Key Improvements
1. Simplified 4 context layers → 2 (Context + Task) — less overlap, easier to generate
2. Added failure/retry protocol and return signal — critical gaps
3. v1 scope reduced: start with Opus + 1 external executor, add models after validation

### Gaps Fixed
- Task lifecycle (pending → dispatched → completed → reviewed → rejected)
- Failure protocol: max 2 retries → escalade Opus
- Return signal: user types `Codex done {slug}` to trigger Claude review
- Self-check simplified: 5 questions → 1 gate question
- Brief frontmatter: 6 → 2 champs (status + target_model)
- Brief sections: 6 → 4 (Context + Task + AC + Anti-patterns)
- Tasks d'implémentation: 5 → 3
- Routing rules dans `.claude/rules/model-routing.md` (auto-chargé, même pattern que tool-routing.md)
- Pas de CARL rule — `.claude/rules/` est déjà auto-chargé, redondant
- Intégration automatique dans GSD execute-phase + `/task-router` manuel optionnel
- Skill = packaging seulement (review/retry géré par model-routing.md, pas dupliqué dans le skill)

---

## Objectif

Pipeline multi-modèle où chaque LLM est utilisé pour ses forces :
- **Claude Opus 4.6** = think (architecture, design, review, orchestration) — DEFAULT
- **GPT-5.4 Pro** = build & orchestrate (automation, implementation from architecture)
- **Claude Sonnet 4.6** = code fast (day-to-day coding, quick reviews, docs)
- **GPT-5.3 Codex** = execute in terminal (PowerShell, CLI, scripting)

**Principe clé :** Claude est le **context orchestrator** — Codex/GPT sont les **executors**. Claude décide exactement ce que chaque modèle voit, dans un package structuré, et valide l'output.

### Scope v1 vs v2

| | v1 (implémenter maintenant) | v2 (après validation) |
|---|---|---|
| **Modèles** | Opus (stay) + Codex VS Code (handoff) | + Sonnet subagent + GPT-5.4 Pro |
| **Couches contexte** | 2 (Context + Task) | Optionnel: split si besoin |
| **Fichiers** | SKILL.md + briefs générés | + routing rules séparé si complexité |
| **Sonnet** | Déjà natif via `Agent tool model:"sonnet"` — pas besoin de routing | Routing explicite si patterns émergent |

**Raison :** Sonnet fonctionne déjà nativement dans Claude Code. Le routing n'apporte de la valeur que pour les handoffs externes (Codex, GPT-5.4 Pro). Commencer simple, ajouter après.

---

## Architecture: Layered Context Bridge

### Le problème résolu

Envoyer tout le repo à Codex = code générique. Envoyer rien = code qui casse l'architecture.
Solution : **context packages structurés par couches**.

### 2 couches de contexte → sources dans `docs/references/`

| Couche brief | Contenu | Source (`docs/references/`) |
|--------------|---------|----------------------------|
| **Context** | Architecture, security, coding patterns, conventions — tout ce qui contraint le code | `architecture-security.md` (L1) + `coding-patterns.md` (L2) + `services-and-access.md` (L3 si infra) |
| **Task** | Instructions, code pertinent, AC, anti-patterns | Plan GSD + `codebase-context.md` (L3) pour les snippets pertinents |

Le routing tree de `docs/references/Reference-files-index-routing.md` guide le task-router :
- **Tâche archi/security** → extraire de L1
- **Tâche code** → extraire de L2 + L3 (codebase-context)
- **Tâche infra** → extraire de L3 (services-and-access)

> Les fichiers `docs/references/` sont la source de vérité structurée.
> Le task-router extrait les sections pertinentes — pas les fichiers entiers.

**Règle : L'executor ne voit jamais de code non pertinent, mais voit tout ce qui est nécessaire.**

### Format du context package

Claude génère un fichier `.task-briefs/{NNN}-{slug}.md` structuré :

```markdown
---
status: pending          # pending | dispatched | completed | reviewed | rejected
target_model: codex      # codex | gpt54pro
---

# Task: {titre}

## Context
[Extraits pertinents de docs/references/ :]
[- architecture-security.md (L1) si archi/security]
[- coding-patterns.md (L2) si code]
[- services-and-access.md (L3) si infra]
[+ .claude/rules/ si conventions spécifiques]
[+ Diffs ou snippets des modules/classes que la tâche touche — PAS les fichiers entiers]

### path/to/file.py (lines 45-80)
```python
# le module que tu étends
```

## Task
[Instructions concrètes, courtes]

## Acceptance Criteria
- [ ] [AC1]
- [ ] [AC2]

## Anti-patterns — DO NOT
- [X parce que Y]
```

### Self-check avant envoi

**Gate unique :** "Le brief contient-il tout pour que l'executor produise du code qui compile et passe les AC sans lire d'autres fichiers ?"

Si non → compléter avant de présenter le handoff.

---

## Pipeline d'exécution (v1)

```
┌─────────────────────────────────────────────────────┐
│ PHASE 1: PLAN (Claude Opus — inchangé)               │
│ - gsd:plan-phase comme d'habitude                    │
│ - Les routing rules dans .claude/rules/model-        │
│   routing.md sont auto-chargées                      │
└──────────────┬──────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────┐
│ PHASE 2: CLASSIFY + PACKAGE (pendant execute-phase)  │
│ Claude lit model-routing.md (auto-chargé) et pour    │
│ chaque tâche :                                       │
│                                                       │
│ "Est-ce de l'archi/design/review ?"                  │
│   OUI → opus (exécute directement)                   │
│   NON → external :                                   │
│     1. Collecte contexte (archi + patterns + code)   │
│     2. Écrit .task-briefs/{NNN}-{slug}.md            │
│     3. Self-check gate                               │
│     4. Affiche handoff instruction                   │
└──────────────┬──────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────┐
│ PHASE 3: EXECUTE                                     │
│                                                       │
│ Opus tasks ──→ Claude exécute directement            │
│                                                       │
│ External tasks ──→ Handoff Codex VS Code             │
│   User: "lis .task-briefs/001-slug.md et exécute"   │
└──────────────┬──────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────┐
│ PHASE 4: REVIEW (Claude Opus — toujours)             │
│ Signal: user tape "Codex done {slug}"                │
│ - git diff analyse                                   │
│ - Vérifie AC du brief                                │
│ - Si PASS → status: reviewed → next task             │
│ - Si FAIL → retry protocol (max 2) ou escalade      │
│ - Update GSD state                                   │
└─────────────────────────────────────────────────────┘
```

---

## Routing Rules (v1 — 2 modèles)

Les règles complètes vivent dans `.claude/rules/model-routing.md` (auto-chargé).

### v1 : classification binaire

| La tâche est... | Routing | Canal |
|-----------------|---------|-------|
| Architecture, design, trade-offs, review, audit, planification, ambiguë | **opus** (stay) | Session Claude Code |
| Implémentation code, scripting, automation, CI/CD, tests | **external** (handoff) | Codex VS Code → `.task-briefs/` |

**Default si ambiguë → opus.**

> **v2 :** Les routing rules 4 modèles (GPT-5.4 Pro, Sonnet, Codex) seront écrites dans model-routing.md quand v1 est validé. Pas de section v2 pré-écrite — YAGNI.

---

## Canaux d'exécution (v1)

| Modèle | Canal | Automatique ? |
|--------|-------|---------------|
| **Opus** | Session principale Claude Code | Oui — c'est le défaut |
| **External** | Codex VS Code | Semi-auto — user copie 1 phrase |

> **Sonnet** fonctionne déjà nativement via `Agent tool model:"sonnet"` sans routing.
> **GPT-5.4 Pro** et **Codex** routing détaillé activable en v2.

---

## Failure & Retry Protocol

```
Codex retourne du code
  │
  ▼
Claude review (git diff + AC check)
  │
  ├── PASS → status: reviewed ✓ → next task
  │
  └── FAIL → attempt += 1
        │
        ├── attempt ≤ max_attempts (2)
        │   → Claude écrit les corrections nécessaires dans le brief
        │   → status: pending (retry)
        │   → User: "lis .task-briefs/{slug}.md et corrige"
        │
        └── attempt > max_attempts
            → status: rejected
            → Claude escalade: exécute la tâche lui-même (Opus)
            → Log dans le brief: "Escalated: [raison]"
```

**Règle :** Jamais plus de 2 retries. Si Codex ne peut pas après 2 tentatives, le contexte est probablement insuffisant et Opus reprend.

---

## Return Signal Protocol

Le handoff a besoin d'un signal retour clair.

**Quand Codex a fini dans VS Code :**
1. User revient dans Claude Code
2. User tape : `Codex a terminé {slug}` ou `/review {slug}`
3. Claude :
   - `git diff` pour voir les changements
   - Vérifie chaque AC du brief
   - Met à jour `status` dans le frontmatter du brief
   - Si PASS → next task. Si FAIL → retry protocol.

**Raccourci accepté :**
- `Codex done 001` → review `.task-briefs/001-*.md`

---

## Incremental Context Loading (large codebases — v2)

Pour les projets volumineux :
1. Charger le contexte par chunks
2. Codex traite un module/fonction à la fois
3. Claude orchestre la séquence → merge les outputs
4. Token usage bas, pas d'erreurs "missing context"

> **Note v1 :** Pas nécessaire pour le scope initial. Ajouter si les briefs dépassent régulièrement les limites de tokens de Codex.

---

## Implémentation : skill `/task-router`

### Ce que le skill fait (v1) — packaging seulement

1. **Input :** Prend le plan GSD courant (ou un plan passé en argument)
2. **Classify :** Pour chaque tâche, applique les routing rules → `opus` (stay) ou `external` (handoff)
3. **Package :** Pour chaque tâche external :
   - Collecte le contexte (extraits de `docs/references/` + snippets code pertinents)
   - Écrit `.task-briefs/{NNN}-{slug}.md` avec frontmatter (status + target_model)
   - Self-check (1 gate question)
4. **Handoff :** Affiche les instructions :
   ```
   → Codex VS Code: "lis .task-briefs/001-create-auth-middleware.md et exécute"
   ```

> La review (`Codex done {slug}`) et le retry protocol sont définis dans `model-routing.md` (auto-chargé). Le skill ne fait que le packaging — pas de duplication de responsabilité.

### Fichiers à créer / modifier

| Fichier | Rôle | Task |
|---------|------|------|
| `.claude/rules/model-routing.md` | Règles de routing + review + retry (auto-chargé) | Task 1 |
| `CLAUDE.md.template` | Ajouter 1 ligne "Outils actifs" | Task 1 |
| `.claude/skills/task-router/SKILL.md` | Packaging des briefs seulement | Task 2 |
| `.task-briefs/` + `.gitignore` | Directory gitignored pour briefs runtime | Task 3 |

### Intégration GSD — automatique

Le routing est **intégré dans le flow GSD**, pas une commande séparée :

1. `gsd:plan-phase` → plan comme d'habitude
2. `gsd:execute-phase` → Claude voit `model-routing.md` (auto-chargé via rules/)
3. Pour chaque tâche, Claude applique le routing :
   - **opus** → exécute directement (comportement actuel inchangé)
   - **external** → génère le brief dans `.task-briefs/`, affiche le handoff
4. Signal retour : `Codex done {slug}` → Claude review via git diff + AC check
5. Retry/escalade intégré dans le review loop

**Pas de `/task-router` manuel nécessaire.** Le skill existe pour les cas où on veut pré-générer les briefs sans lancer l'exécution.

---

## Exemple concret (v1)

Plan GSD avec 5 tâches :

| # | Tâche | Routing v1 | Canal |
|---|-------|------------|-------|
| 1 | Design API auth architecture | **opus** | Claude exécute directement |
| 2 | Implement JWT middleware | **external** | `.task-briefs/002-jwt-middleware.md` → Codex VS Code |
| 3 | Write unit tests | **opus** | Claude exécute (subagent sonnet natif) |
| 4 | Create CI/CD pipeline | **external** | `.task-briefs/004-cicd-pipeline.md` → Codex VS Code |
| 5 | PowerShell deploy script | **external** | `.task-briefs/005-deploy-script.md` → Codex VS Code |

Claude exécute #1 et #3 automatiquement.
Pour #2, #4, #5 Claude affiche : "Dis à Codex VS Code : lis `.task-briefs/002-jwt-middleware.md` et exécute"
Quand fini, user tape `Codex done 002`. Claude review.

---

## Tâches d'implémentation

### Task 1 : Créer `.claude/rules/model-routing.md` + mettre à jour `CLAUDE.md.template`

Le fichier de routing modèles, auto-chargé par Claude Code (même mécanisme que `tool-routing.md`).

Contenu model-routing.md :
- Section v1 active : classification binaire opus/external avec table de routing
- Fallback rules (default → opus)
- Return signal protocol (`Codex done {slug}` → git diff + AC check)
- Failure & retry protocol (max 2 → escalade Opus)
- Référence vers `docs/references/` comme source de contexte pour les briefs

Contenu CLAUDE.md.template :
- Ajouter 1 ligne dans "Outils actifs" : `- Routing modèles → voir .claude/rules/model-routing.md`

AC :
- [ ] `model-routing.md` est dans `.claude/rules/` (auto-chargé)
- [ ] Les règles v1 sont claires et non-ambiguës
- [ ] Return signal et retry protocol sont dans le fichier
- [ ] La ligne existe dans CLAUDE.md.template "Outils actifs"

### Task 2 : Créer `.claude/skills/task-router/SKILL.md`

Le skill de packaging des context briefs (packaging seulement — review/retry dans model-routing.md).

Contenu :
- Lit le plan GSD courant
- Pour chaque tâche classifiée "external" par model-routing.md :
  - Lit `docs/references/Reference-files-index-routing.md` pour savoir quels fichiers L1-L3 consulter
  - Extrait les sections pertinentes de `docs/references/` (pas les fichiers entiers)
  - Écrit `.task-briefs/{NNN}-{slug}.md` avec frontmatter (status + target_model)
  - Self-check gate (1 question)
- Affiche les instructions handoff

AC :
- [ ] `/task-router` génère des briefs dans `.task-briefs/`
- [ ] Les briefs contiennent le frontmatter (status + target_model)
- [ ] Le contexte est extrait de `docs/references/` (pas inventé)
- [ ] Le self-check gate valide que le brief est autosuffisant
- [ ] Le skill ne duplique PAS le review/retry (c'est dans model-routing.md)

### Task 3 : Ajouter `.task-briefs/` au `.gitignore`

Les briefs sont générés à runtime, pas versionnés.

AC :
- [ ] `.task-briefs/` est dans `.gitignore`

## Boundaries

- `.carl/` (ne pas modifier — `.claude/rules/` est auto-chargé, CARL serait redondant)
- `.claude/rules/tool-routing.md` (ne pas modifier)
- `.claude/rules/execution-quality.md` (ne pas modifier)
- `.claude/skills/` existants (ne pas modifier)
- `docs/references/*.md.template` contenu existant (ne pas modifier)

---

## Research Insights (from deepening)

### Landscape — outils existants comparés

| Outil | Ce qu'il fait | Différence avec notre plan |
|-------|---------------|---------------------------|
| **Claude Code Router** | Proxy qui route par type de tâche (API level) | Routing par modèle, pas de context curation |
| **Claude Octopus** | Multi-model avec consensus 75% | Consensus adversarial, pas de briefs structurés |
| **OpenRouter MCP** | Accès à 400+ modèles via tool calls | Plomberie seulement, pas d'intelligence routing |
| **VS Code Multi-Agent** (Feb 2026) | Claude + Codex + Copilot côte à côte | Environment d'exécution, pas de format brief |
| **AGENTS.md standard** | Format ouvert pour guider les coding agents | Confirme notre approche brief-based |

### Ce qui est novel dans notre approche

**Personne ne fait de curation intelligente de contexte pour le cross-model handoff.** Tout le monde passe tout (wasteful, code générique) ou rien (code cassé). Nos 2 couches extraites avec self-check gate sont la contribution unique.

### Patterns à considérer pour v2

- **Token-count auto-routing** (Claude Code Router) — si tâche > X tokens → auto-route vers large context model
- **Cross-session state** (Claude Octopus `.octo-continue.md`) — persistence des handoffs entre sessions
- **Handoff ID structuré** (MCP Handoff Server) — metadata machine-readable dans le frontmatter
- **MCP resources** — exposer les briefs comme MCP resources pour consommation native par VS Code
