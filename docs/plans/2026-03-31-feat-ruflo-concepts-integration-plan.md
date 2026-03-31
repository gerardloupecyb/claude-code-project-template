---
title: "feat: Integrate ruflo orchestration concepts — SPARC, dual-agent, AgentDB, DDD"
type: feat
status: draft
date: 2026-03-31
tracks: 2
source: ruvnet/ruflo (analysis session 2026-03-31)
---

# Integrate ruflo Orchestration Concepts into project-template-v2

## Overview

Extraire et adapter les concepts clés de [ruvnet/ruflo](https://github.com/ruvnet/ruflo) dans le project template, **sans aucune dépendance sur ruflo**. Deux tracks parallèles : enrichissements template (Track A) et AgentDB self-hosted (Track B).

## Problem Statement

Le template actuel a des gaps identifiés par comparaison avec ruflo :

1. **Pas de méthodologie de micro-exécution** — GSD gère le macro (roadmap, phases) mais pas le micro (comment exécuter une tâche complexe étape par étape)
2. **Review mono-perspective** — un seul agent review le code, pas de challenge structuré
3. **Design validation faible** — pre-flight a 4 agents mais aucun "devil's advocate" qui challenge les décisions architecturales
4. **Enforcement pre-flight absent** — pre-flight est recommandé mais pas forcé, Claude peut (et a déjà) skip
5. **Mémoire sémantique médiocre** — Supermemory recall retourne du bruit, pas de contrôle sur l'indexation ni débuggabilité
6. **Conventions multi-agent implicites** — pas de règles formelles pour orchestrer les subagents (topologie, max agents, anti-drift)
7. **Décisions architecturales perdues** — DECISIONS.md est maintenu manuellement, les décisions faites pendant l'exécution passent à la trappe
8. **Pas de tracking DDD** — bounded contexts non documentés, violations cross-domaine non détectées

## Proposed Solution

### Track A — Template enrichments

Modifications des fichiers template existants + 3 nouveaux fichiers. Zéro dépendance externe.

### Track B — AgentDB self-hosted

MCP server self-hosted sur VPS avec vector DB (Qdrant), embedding service, et thin client local. Remplace Supermemory à 100% (y compris cross-projet).

## Decision Log

| Décision | Alternative rejetée | Raison |
|----------|-------------------|--------|
| Pas de dépendance ruflo (claude-flow MCP, ruv-swarm, AgentDB ruflo) | Intégrer les packages npm ruflo | Trop lourd, risque de breaking changes, chaque collègue doit installer |
| Agent roles fusionnés dans swarm-patterns.md | Répertoire agents/ séparé avec YAML | Duplication, risque de stale entre 2 sources |
| Dual-agent design dans pre-flight (pas skill standalone) | Skill `/dual-agent` séparé | Encore une commande à mémoriser, redondant avec pre-flight et ce:brainstorm |
| Dual-agent review dans SPARC Phase 5 | Skill `/codex-review` séparé | Même pattern, source du code (interne/Codex) ne change pas la mécanique |
| Enforcement pre-flight CARL + session-gate combinés | Règle seule ou hook seul | Claude viole les règles parfois — défense en profondeur requise |
| AgentDB sur VPS (pas local SQLite) | DB locale chaque machine | Collègues voient la même chose en temps réel, pas de rebuild local, meilleur modèle embedding possible |
| Supermemory remplacé (pas amélioré) | Mieux structurer les entrées Supermemory | Problème fondamental = boîte noire non débuggable, pas juste des tags mal structurés |
| DDD léger (1 fichier + règle) | DDD tracking complet comme ruflo | La plupart des projets ont des domaines, pas besoin d'un système de tracking lourd |

---

## Track A — Template Enrichments

### A1. swarm-patterns.md — single source of truth

**Fichier :** `.claude/rules/swarm-patterns.md`
**Budget :** < 80 lignes, < 1200 tokens

Contient TOUT ce qui concerne l'orchestration multi-agent :

#### Section 1 — Agent Roles

Définitions des rôles référencés par SPARC et pre-flight :

| Rôle | Responsabilité | Model tier | Biais |
|------|---------------|------------|-------|
| `architect` | Design système, APIs, boundaries | Sonnet/Opus | Propose la meilleure solution |
| `critic` | Challenge, edge cases, over-engineering | Sonnet/Opus | Cherche activement les problèmes |
| `coder` | Implémentation, TDD | Sonnet | Best practices |
| `reviewer` | Code review structurée | Sonnet/Opus | Qualité + sécurité |
| `tester` | Tests, edge cases, couverture | Sonnet | Couverture exhaustive |
| `security-auditor` | OWASP, auth, data exposure | Sonnet/Opus | Paranoid |
| `spec-writer` | Requirements, AC mesurables | Sonnet | Clarté + traçabilité |
| `logic-planner` | Pseudocode, logique, TDD anchors | Sonnet | Structure |

#### Section 2 — Topologie et anti-drift

3 patterns extraits de ruflo, adaptés pour Agent tool natif :

**Pattern 1 — Topologie hiérarchique**
- Claude principal = lead, subagents = workers
- Le lead lit les outputs et synthétise
- Jamais de workers qui s'appellent entre eux (context flooding)

**Pattern 2 — Anti-drift**
- Toujours passer le contexte complet dans chaque prompt d'agent (les subagents ne lisent pas le contexte parent)
- Checkpoint après chaque agent : lire l'output avant de spawner le suivant
- Si un agent retourne < 3 lignes ou "unable to proceed" → arrêter la chaîne, diagnostiquer

**Pattern 3 — Shared namespace explicite**
- Pas de mémoire partagée magique entre subagents
- Convention : écrire les outputs dans `.claude/workspace/{task-id}-{agent}.md`
- Les agents suivants lisent explicitement ces fichiers

#### Section 3 — Model routing (3-tier)

| Tier | Modèle | Quand | Exemples |
|------|--------|-------|----------|
| 1 | Haiku | Tâche simple, < 30% complexité | Recherche, formatting, grep, rename |
| 2 | Sonnet | Implémentation standard | Feature, bugfix, refactor, tests |
| 3 | Opus | Décisions critiques, architecture | Design, sécurité, dual-agent, SPARC arch |

#### Section 4 — Limites

- Max agents simultanés : 6-8 pour tâches courantes, 12 pour systèmes complexes
- Chaque agent doit retourner < 200 mots de résumé (sauf si fichier output demandé)
- Ne jamais spawner un agent sans vérifier que le précédent a réussi (sauf parallèle explicite)

**Success criteria :**
- [ ] Fichier < 80 lignes
- [ ] Tous les rôles référencés dans SPARC et pre-flight y sont définis
- [ ] Conventions testables mécaniquement (max agents, output size)

---

### A2. Pre-flight enrichi — Agent 5 Critic

**Fichier modifié :** `.claude/skills/pre-flight/SKILL.md`

Ajouter un 5ème agent au pre-flight existant :

**Agent 5 : Architecture Critic**

```
Rôle : critic (ref swarm-patterns.md)
```

- Reçoit les findings de l'Agent 1 (Architecture Strategist) + le plan original
- Mission : challenger activement les propositions de l'Agent 1
  - Les alternatives sont-elles explorées ?
  - Y a-t-il de l'over-engineering ?
  - Les tradeoffs sont-ils explicites ?
  - Les coûts cachés sont-ils identifiés ?
  - Le design est-il le plus simple qui répond aux AC ?

**Changement dans le flow :**

```
Avant : 4 agents en parallèle → synthèse → verdict
Après : 4 agents en parallèle → Agent 5 Critic reçoit Agent 1 output → synthèse → verdict
```

L'Agent 5 n'est PAS en parallèle avec les 4 autres — il attend l'output de l'Agent 1 car il doit le challenger. Les agents 2-4 restent en parallèle.

**Modifications au format du report :**

Ajouter une section dans le Pre-Flight Report :

```markdown
### Architecture Challenge
- {Proposition Agent 1} → {Challenge Critic} → {Résolution}
- {Proposition Agent 1} → {Challenge Critic} → {Résolution}

### Design Verdict
{Résumé : quel design retenu, pourquoi, quelles réserves du critic sont valides}
```

**Intégration DDD :** L'Agent 5 Critic vérifie aussi que le plan respecte les bounded contexts définis dans `docs/architecture/contexts.md` (si le fichier existe).

**Success criteria :**
- [ ] Agent 5 défini dans pre-flight SKILL.md
- [ ] Référence rôle `critic` de swarm-patterns.md
- [ ] Section "Architecture Challenge" dans le report template
- [ ] N'exécute que si Agent 1 a retourné des findings (skip si plan trivial)

---

### A3. SPARC skill

**Fichier :** `.claude/skills/sparc/SKILL.md`

Méthodologie de micro-exécution pour tâches complexes DANS une phase GSD. SPARC = Specification, Pseudocode, Architecture, Refinement, Completion.

**Deux points d'entrée :**

| Déclencheur | Quand | Contexte |
|-------------|-------|----------|
| Automatique | `/gsd:execute-phase` invoque SPARC en interne | PLAN.md + AC passés automatiquement |
| Manuel | `/sparc "description"` directement | SPARC demande le contexte à l'utilisateur |

SPARC est invoqué explicitement par l'utilisateur (`/sparc "description"`) ou par `/prepare-phase` en séquence.
**SPARC ne wrappe PAS /gsd:execute-phase** — c'est un skill template indépendant.
Claude affiche "Exécution via SPARC (5 phases)" — l'utilisateur voit le flow.

**Positionnement dans le workflow :**

```
GSD macro :  discuss → plan → pre-flight → execute-phase
                                              │ (wrappé par le template)
SPARC micro :                                 ├── Phase 1 Spec
                                              ├── Phase 2 Pseudo
                                              ├── Phase 3 Arch (dual-agent)
                                              ├── Phase 4 Refine (impl + tests)
                                              └── Phase 5 Complete (dual review)
```

#### Phase 1 — Specification

- Spawn agent `spec-writer` (ref swarm-patterns.md, tier 2)
- Input : description de la tâche + AC de la phase GSD
- Output : requirements détaillés + AC mesurables dans `.claude/workspace/sparc-spec.md`
- Validation : user confirme avant de passer à Phase 2

#### Phase 2 — Pseudocode

- Spawn agent `logic-planner` (ref swarm-patterns.md, tier 2)
- Input : spec de Phase 1
- Output : logique haut niveau + TDD anchors (quels tests écrire d'abord)
- Output dans `.claude/workspace/sparc-pseudo.md`
- Validation : user confirme

#### Phase 3 — Architecture (dual-agent)

- Spawn 2 agents EN PARALLÈLE (ref swarm-patterns.md) :
  - `architect` (tier 3) : propose le design optimal basé sur spec + pseudo
  - `critic` (tier 3) : reçoit le même input, cherche failles, alternatives, simplifications
- Claude principal synthétise les deux outputs
- Output : design validé dans `.claude/workspace/sparc-arch.md`
- Validation : user confirme
- Si `docs/architecture/contexts.md` existe : les deux agents le reçoivent comme contrainte

#### Phase 4 — Refinement

- Exécution GSD standard (pas de spawn SPARC spécifique)
- Les rules `execution-quality.md` s'appliquent normalement
- TDD : écrire les tests d'abord (anchors de Phase 2), puis implémenter
- Commit par unité logique complète

#### Phase 5 — Completion (dual-agent review)

- Spawn 2 agents EN PARALLÈLE :
  - `reviewer` (tier 3) : review le code produit contre les AC de Phase 1
  - `critic` (tier 3) : cherche failles, edge cases manqués, sécurité, over-engineering
- Claude principal synthétise et produit un verdict GO/NO-GO
- Si NO-GO : retour Phase 4 avec les findings
- Si GO : marquer la tâche comme complète

**Ce que SPARC ne fait PAS :**
- Remplacer GSD (SPARC vit DANS une phase GSD)
- Forcer toutes les phases (pour une tâche simple, skip Phase 2 et 3)
- Auto-chain sans validation (chaque phase attend le user confirm)

**Quand utiliser SPARC :**
- Dans une phase GSD → SPARC toujours, par defaut, quelle que soit la complexite
- Hors phase GSD (tache isolee) → CE:work
- Quick fix explicite → /gsd:fast (l'utilisateur shortcute consciemment)

**Success criteria :**
- [ ] SKILL.md < 150 lignes
- [ ] Référence swarm-patterns.md pour tous les rôles
- [ ] Phases 3 et 5 utilisent le pattern dual-agent
- [ ] Chaque phase attend validation avant la suivante
- [ ] Phase 4 = exécution GSD standard (pas de duplication)
- [ ] Fonctionne standalone (sans GSD) pour du code Codex review (Phase 5 seule)

---

### A4. CARL rule — enforcement pre-flight

**Fichier :** `.carl/{CARL_DOMAIN}` (ou domaine template si applicable)

Règle :

```
TEMPLATE_RULE_X = Ne jamais exécuter /gsd:execute-phase sans un fichier
*-PREFLIGHT.md pour la phase courante dans .planning/ ou
.planning/milestones/{milestone}/. Si absent dans les deux paths,
exécuter /pre-flight d'abord.
```

**Pourquoi CARL et pas juste une règle dans .claude/rules/ :** CARL est injecté dynamiquement dans le prompt, les .claude/rules/ sont auto-chargés mais Claude peut les ignorer (observation confirmée). CARL a un track record légèrement meilleur d'adhérence car les règles sont marquées comme critiques.

**Limitation honnête :** Même CARL a été violé dans des cas observés. C'est pourquoi A5 (session-gate) est nécessaire comme filet de sécurité.

**Success criteria :**
- [ ] Règle ajoutée dans le bon domaine CARL
- [ ] Formulation actionnable (verbe + condition + action)
- [ ] Numéro de règle séquentiel correct

---

### A5. Session-gate Check 18 — pre-flight enforcement mécanique

**Fichier modifié :** `.claude/skills/session-gate/SKILL.md`

Ajouter Check 18 applicable au mode END (Check 17 est deja pris par le frontmatter docs) :

```
### Check 18 — Pre-flight enforcement (END)

Chercher les fichiers PLAN dans les deux paths possibles :
  - .planning/{phase}-*-PLAN.md
  - .planning/milestones/{milestone}/{phase}-*-PLAN.md

Si au moins un fichier *-PLAN.md existe pour la phase courante :
  Chercher un fichier *-PREFLIGHT.md dans le MÊME répertoire que le PLAN.
  Si absent : [!!] Phase {N} has a PLAN but no PREFLIGHT — /pre-flight was skipped

Si un *-PREFLIGHT.md existe, grep "Verdict:" dans le fichier :
  Si contient "NO-GO" et qu'aucun *-PREFLIGHT.md plus récent (par mtime) n'existe
  avec "GO" ou "CONDITIONAL GO" :
  [!!] Phase {N} PREFLIGHT verdict was NO-GO and was not re-run after fixes
```

**Mécanique :** Ce check utilise l'existence de fichiers, leur path, et un grep sur "Verdict:". Pas de jugement sémantique. Les deux paths (.planning/ et .planning/milestones/) sont couverts car pre-flight écrit dans l'un ou l'autre selon la structure du projet.

**Success criteria :**
- [ ] Check 18 ajouté avec mode END
- [ ] Vérifie existence fichier (pas contenu sémantique)
- [ ] Message d'erreur actionnable

---

### A6. ADR auto-tracking — règle execution-quality.md

**Fichier modifié :** `.claude/rules/execution-quality.md`

Ajouter une section :

```markdown
## Decision Tracking

When making an architectural decision during execution (choice of pattern,
library, data model, API design, or rejection of an alternative), propose
a DECISIONS.md entry BEFORE continuing implementation:

| Field | Content |
|-------|---------|
| Decision | What was decided |
| Alternatives | What was considered and rejected |
| Rationale | Why this choice |
| Scope | What this affects |
| Date | Today |

Skip for trivial decisions (variable naming, formatting, imports).
Only track decisions that a colleague joining next week would need to know.
```

**Budget :** ~15 lignes ajoutées. Le fichier passe de 42 à ~57 lignes, toujours sous le cap de 80.

**Success criteria :**
- [ ] Section ajoutée dans execution-quality.md
- [ ] Skip heuristic pour éviter le bruit
- [ ] Fichier total reste < 80 lignes

---

### A7. DDD léger — docs/architecture/contexts.md

**Fichier template :** `docs/architecture/contexts.md.template`

```markdown
# Bounded Contexts — {{PROJECT_NAME}}

> Définit les domaines du projet et leurs frontières.
> Référencé par pre-flight (Agent 5 Critic) et SPARC (Phase 3).
> Mettre à jour quand un nouveau domaine émerge ou qu'une frontière change.

## Contexts

### {{CONTEXT_1}}
- **Responsabilité :** {{description}}
- **Entités principales :** {{liste}}
- **Interfaces exposées :** {{APIs, events, services}}

### {{CONTEXT_2}}
- **Responsabilité :** {{description}}
- **Entités principales :** {{liste}}
- **Interfaces exposées :** {{APIs, events, services}}

## Règles de frontière

- Un context ne doit PAS accéder directement aux entités d'un autre context
- Communication cross-context via : {{events / APIs / service objects}}
- Si une violation est détectée, le code doit être refactoré ou une exception documentée
```

**Intégration :**
- Pre-flight Agent 5 (Critic) reçoit ce fichier comme contrainte
- SPARC Phase 3 (Architecture) : architect et critic le reçoivent
- Règle dans execution-quality.md : "Avant de modifier du code qui touche un autre domaine, vérifier contexts.md"
- init-project.sh copie le template

**Si un projet n'a pas de DDD :** Le fichier template contient des placeholders. Si non rempli, les agents l'ignorent (pas de contenu = pas de contrainte).

**Success criteria :**
- [ ] Template créé avec placeholders
- [ ] Pre-flight SKILL.md référence le fichier
- [ ] SPARC SKILL.md référence le fichier
- [ ] 1 ligne ajoutée dans execution-quality.md

---

### A8. Hook PreToolUse Agent — enforcement swarm patterns

**Fichier :** `.claude/hooks/pre-agent.sh`
**Fichier modifié :** `.claude/settings.json`

Hook léger qui s'exécute avant chaque appel Agent tool. Ne bloque pas, logge seulement.

Le hook reçoit le tool input en JSON sur stdin (PreToolUse convention Claude Code).
Il en extrait le description field et le subagent_type pour un log exploitable.

```bash
#!/bin/bash
# Log agent spawns for session-gate audit
# Receives tool input JSON on stdin
TIMESTAMP=$(date +%Y-%m-%dT%H:%M:%S)
LOG_FILE="$CLAUDE_PROJECT_DIR/.claude/workspace/agent-log.txt"
INPUT=$(cat)
DESC=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('description','unknown'))" 2>/dev/null || echo "unknown")
TYPE=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('subagent_type','general'))" 2>/dev/null || echo "general")
echo "$TIMESTAMP | $TYPE | $DESC" >> "$LOG_FILE"
exit 0
```

**Dans settings.json :**

```json
"PreToolUse": [
  {
    "matcher": "Agent",
    "hooks": [
      {
        "type": "command",
        "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/pre-agent.sh",
        "timeout": 3000
      }
    ]
  }
]
```

**Reset au session start :** Le hook `session-start.sh` existant doit être modifié pour vider le log au démarrage :

```bash
# Ajout dans session-start.sh existant
> "$CLAUDE_PROJECT_DIR/.claude/workspace/agent-log.txt"
```

Ceci garantit que le compteur est par session, pas cumulatif.

**Consommateur : session-gate Check 18 (END, informational)**

```
### Check 19 — Agent spawn audit (END) — informational

Lire .claude/workspace/agent-log.txt si existant.
Compter le nombre de lignes (= spawns dans cette session, reset au start).
Afficher : [--] {N} agents spawned this session
Si N > 15 : [!!] Unusually high agent count ({N}) — possible drift
```

**Pourquoi log et pas block :** Bloquer les agents casserait trop de workflows légitimes. Le log enrichi (type + description) permet un audit post-session réel.

**Success criteria :**
- [ ] Hook créé et fonctionnel
- [ ] settings.json mis à jour avec le matcher Agent
- [ ] Log dans .claude/workspace/agent-log.txt (gitignored)
- [ ] Exit 0 toujours (ne bloque jamais)

---

### A9. CLAUDE.md.template + init-project.sh

**Fichiers modifiés :**
- `CLAUDE.md.template`
- `init-project.sh`

#### CLAUDE.md.template modifications

**Section Outils actifs** — ajouter :

```markdown
- SPARC                  → micro-exécution pour tâches complexes (dans une phase GSD)
- Swarm patterns         → conventions multi-agent (voir `.claude/rules/swarm-patterns.md`)
- AgentDB               → mémoire sémantique self-hosted (remplace Supermemory)
```

**Section Workflows** — ajouter le parcours SPARC :

```markdown
### Parcours tâche complexe dans une phase

/sparc "description" → Spec → Pseudo → Arch (dual-agent) → Refine (GSD execute) → Complete (dual-agent review)
```

**Section Skills installés** — ajouter SPARC dans la table.

**Section Fichiers mémoire** — remplacer les références Supermemory par AgentDB :

| Avant | Après |
|-------|-------|
| `Supermemory (projet)` | `AgentDB (projet namespace)` |
| `recall` Supermemory | `agentdb_search` |
| `/lesson migrate` → Supermemory | `/lesson migrate` → AgentDB |

**Règle de consultation** — remplacer étape 3 :

```markdown
3. `agentdb_search` avec les mots-clés du domaine → leçons sémantiques
```

#### init-project.sh modifications

- Copier `docs/architecture/contexts.md.template` → `docs/architecture/contexts.md`
- Copier `.claude/hooks/pre-agent.sh`
- Mettre à jour settings.json avec le hook PreToolUse Agent
- Ajouter `.claude/workspace/` au .gitignore
- Copier `.agentdb/config.json.template` (pour Track B)

**Success criteria :**
- [ ] CLAUDE.md.template < 200 lignes (budget Anthropic)
- [ ] init-project.sh copie tous les nouveaux fichiers
- [ ] Références Supermemory remplacées par AgentDB
- [ ] Parcours SPARC documenté

---

## Track B — AgentDB Self-Hosted

### Architecture

```
VPS (ton serveur):
  ├── qdrant/              ← Vector DB (Docker)
  ├── embedding-service/   ← sentence-transformers API (Docker)
  └── agentdb-api/         ← REST API (Node.js ou Python)

Projet local (chaque collègue):
  ├── .claude/mcp/agentdb/ ← MCP thin client (HTTP calls)
  ├── .agentdb/
  │   ├── entries/         ← markdown source files (git-tracked)
  │   └── config.json      ← VPS URL + project namespace
  └── scripts/
      └── agentdb-reindex.sh  ← rattrapage sync manuelle (Node.js)
```

**Principes :**
- Source de vérité = fichiers markdown dans `.agentdb/entries/` (git-tracked)
- VPS = index de recherche (cache rebuilable)
- Si VPS down → entries toujours dans git, rebuild quand il revient
- Cross-projet = namespace différent sur le même VPS

### B1. VPS Setup — Qdrant + Embedding Service

**Infrastructure :**

```yaml
# docker-compose.yml sur VPS
services:
  qdrant:
    image: qdrant/qdrant:latest
    ports: ["6333:6333"]
    volumes: ["./qdrant-data:/qdrant/storage"]

  embedding:
    image: ghcr.io/huggingface/text-embeddings-inference:latest
    # Modèle : nomic-embed-text-v1.5 ou bge-large-en-v1.5
    # Plus gros que all-MiniLM-L6-v2, meilleure qualité
    environment:
      MODEL_ID: nomic-ai/nomic-embed-text-v1.5
    ports: ["8080:80"]

  agentdb-api:
    build: ./agentdb-api
    ports: ["3100:3100"]
    environment:
      QDRANT_URL: http://qdrant:6333
      EMBEDDING_URL: http://embedding:80
```

**API endpoints :**

| Endpoint | Méthode | Description |
|----------|---------|-------------|
| `POST /entries` | Store | Embed + index une entrée |
| `POST /search` | Search | Recherche sémantique avec filtres |
| `GET /entries` | List | Liste les entrées d'un namespace |
| `DELETE /entries/:id` | Delete | Supprime une entrée |
| `POST /reindex` | Admin | Rebuild l'index depuis les fichiers |

**Schéma d'une entrée dans Qdrant :**

```json
{
  "id": "perf-n1-query-invoices",
  "vector": [0.023, -0.041, ...],
  "payload": {
    "title": "N+1 query pattern on invoices",
    "domain": "performance",
    "classification": "reusable",
    "date": "2026-03-15",
    "author": "gerard",
    "project": "project-alpha",
    "namespace": "project-alpha",
    "source_file": "entries/perf-n1-query-invoices.md",
    "content_preview": "Quand on charge des invoices avec line_items..."
  }
}
```

**Success criteria :**
- [ ] Docker compose fonctionne sur VPS
- [ ] Embedding service retourne des vecteurs pour du texte
- [ ] Qdrant accepte et retourne des résultats de recherche
- [ ] API REST répond sur les 5 endpoints

---

### B2. MCP Thin Client

**Fichier :** `.claude/mcp/agentdb/`

```
.claude/mcp/agentdb/
  ├── index.js          ← MCP server (thin client HTTP)
  ├── package.json
  └── README.md
```

**Outils MCP exposés :**

| Outil | Params | Description |
|-------|--------|-------------|
| `agentdb_store` | `title`, `content`, `domain`, `classification`, `metadata` | Ecrit le fichier local dans .agentdb/entries/ PUIS sync vers VPS |
| `agentdb_search` | `query`, `domain?`, `scope?` ("project"/"global"/"all"), `min_score?`, `limit?` | Recherche sémantique |
| `agentdb_list` | `domain?`, `limit?` | Liste les entrées |
| `agentdb_delete` | `id` | Supprime une entrée |
| `agentdb_debug` | `query` | Retourne les scores bruts pour diagnostiquer |

**Contrat local-first :** `agentdb_store` écrit TOUJOURS le fichier markdown dans `.agentdb/entries/` d'abord (source de vérité git-tracked), puis sync vers le VPS en arrière-plan. Si le VPS est down, le fichier local existe quand même. Le VPS est un index de recherche rebuilable, pas la source de vérité.

**Le client n'est PAS un simple proxy HTTP** — il gère l'écriture locale + la sync. La recherche est côté VPS.

**Config :** `.agentdb/config.json`

```json
{
  "vps_url": "https://agentdb.ton-vps.com",
  "api_key": "${AGENTDB_API_KEY}",
  "project_namespace": "project-alpha",
  "default_scope": "project",
  "default_min_score": 0.6
}
```

**Success criteria :**
- [ ] MCP server démarre et se connecte au VPS
- [ ] Les 5 outils fonctionnent
- [ ] `agentdb_debug` retourne les scores bruts
- [ ] Config par projet via `.agentdb/config.json`

---

### B3. Format des entries + git integration

**Fichier type :** `.agentdb/entries/perf-n1-query-invoices.md`

```markdown
---
title: N+1 query pattern on invoices
domain: performance
classification: reusable
date: 2026-03-15
author: gerard
tags: [n+1, activerecord, eager-loading]
---

## Contexte
Chargement d'invoices avec line_items dans une boucle.

## Problème
N+1 queries : 1 query invoices + N queries line_items.

## Solution
`Invoice.includes(:line_items).where(...)` — eager loading.

## Anti-patterns
- `Invoice.all.each { |i| i.line_items }` — N+1
- `.joins(:line_items)` sans `.includes` — pas de preload

## Règle distillée
Toujours utiliser `.includes()` quand on accède à des associations dans une boucle.
```

**Compatibilité :** Le format est identique à `docs/solutions/`. Ça veut dire :
- Les entries existantes dans docs/solutions/ peuvent être copiées dans .agentdb/entries/
- Le frontmatter YAML est le même que celui du flywheel
- `Agent Explore` sur `.agentdb/entries/` fonctionne comme fallback keyword search

**Git integration :**
- `.agentdb/entries/` = git-tracked (source de vérité)
- `.agentdb/config.json` = git-tracked (config projet, api_key via env var)
- `.agentdb/*.sqlite` ou caches = gitignored

**Success criteria :**
- [ ] Format markdown + frontmatter YAML documenté
- [ ] Compatible avec le format docs/solutions/ existant
- [ ] .gitignore mis à jour

---

### B4. Hooks — sync automatique

**Le hook de sync n'est PAS un script shell indépendant.** La sync est intégrée dans le MCP client `agentdb_store` lui-même (contrat local-first : écrire le fichier local, puis POST vers le VPS).

Le hook shell séparé est supprimé — il était fragile (dépendance python3+yaml, -mmin -5 unreliable, erreurs masquées). À la place :

1. `agentdb_store` (MCP client, Node.js) écrit le fichier markdown localement
2. `agentdb_store` fait le POST HTTP vers le VPS dans le même appel
3. Si le POST échoue : log l'erreur dans `.agentdb/sync-errors.log` (pas silencieux)
4. Un endpoint `POST /reindex` sur le VPS permet de rattraper les entries manquées

**Fallback pour les entries créées manuellement** (ex: copie de docs/solutions/) :
Script `scripts/agentdb-reindex.sh` qui lit tous les .md dans `.agentdb/entries/` et les pousse vers le VPS. Utilise Node.js (pas python3) pour parser le frontmatter YAML — même runtime que le MCP client.

**Success criteria :**
- [ ] agentdb_store écrit local + sync VPS dans le même appel
- [ ] Erreurs de sync loggées dans .agentdb/sync-errors.log (pas silencieuses)
- [ ] scripts/agentdb-reindex.sh fonctionne pour rattrapage
- [ ] Pas de dépendance python3 — tout en Node.js

---

### B5. Skills update — redirection Supermemory → AgentDB

**Fichiers modifiés :**

| Skill | Modification |
|-------|-------------|
| `/lesson` | Remplacer `memory("store ...")` par `agentdb_store(...)` (écrit local + sync VPS). Remplacer `recall(...)` par `agentdb_search(...)` pour la vérification de doublon. |
| `/lesson migrate` | Destination = `.agentdb/entries/` + sync VPS au lieu de Supermemory. Si cross-projet : push aussi dans namespace `global`. |
| `/ce:compound` | Étape Supermemory du flywheel → `agentdb_store` avec classification cross-projet si applicable. |
| `/project-bootstrap` | Remplacer `recall` par `agentdb_search(scope="global")` pour pull les leçons cross-projet. |
| Règle de consultation (CLAUDE.md) | Étape 3 : `agentdb_search` au lieu de `recall`. |
| `/memory-consolidate` | Ajouter vérification de cohérence `.agentdb/entries/` vs LESSONS.md (doublons, entries orphelines). |

**Migration des données existantes :**
- Script `scripts/migrate-supermemory.sh` qui lit docs/solutions/ et crée les entries correspondantes dans `.agentdb/entries/`
- Réindexation VPS via `POST /reindex`
- Supermemory reste disponible en lecture pendant la transition

**Success criteria :**
- [ ] Tous les skills modifiés fonctionnent avec AgentDB
- [ ] Fallback : si VPS down, les skills fonctionnent en mode dégradé (keyword search sur entries/)
- [ ] Script de migration fonctionne

---

### B6. Cross-projet namespace

**Mécanisme :**

```
/lesson → classification "cross-projet"
  → agentdb_store(namespace="project-alpha")   ← projet
  → agentdb_store(namespace="global")           ← cross-projet
```

**Recherche :**

```
agentdb_search("retry pattern", scope="project")   ← défaut
agentdb_search("retry pattern", scope="global")     ← cross-projet
agentdb_search("retry pattern", scope="all")        ← les deux
```

**Le namespace global est partagé entre tous les projets sur le même VPS.** Chaque projet a sa propre collection Qdrant + une collection `global` commune.

**Cohérence :** `agentdb_store` (MCP client) gère le double push (local + VPS). Si la classification change après coup, `agentdb_store` update les deux namespaces. Pas de hook shell séparé.

**Success criteria :**
- [ ] Namespace projet isolé par défaut
- [ ] Namespace global alimenté quand classification = cross-projet
- [ ] Search scope=all retourne des résultats des deux

---

### B7. Deprecation Supermemory

**Plan de transition :**

| Phase | Action |
|-------|--------|
| 1. AgentDB opérationnel | Migrer docs/solutions/ → .agentdb/entries/ |
| 2. Skills redirigés | /lesson, /ce:compound pointent vers AgentDB |
| 3. Période de coexistence (2 semaines) | Les deux systèmes actifs, résultats comparés |
| 4. Suppression Supermemory | Retirer les références MCP, mettre à jour CLAUDE.md |

**Ce qui reste de Supermemory :** Rien. AgentDB remplace 100% des fonctions.

**Rollback :** Si AgentDB échoue, les entries sont dans git (`.agentdb/entries/`). Supermemory peut être réactivé et les entries réimportées.

---

### A10. Plugin Codex — installation template

**Prérequis collègues :** `npm install -g @openai/codex` + `codex login` (ChatGPT plan, même Free).

**Les slash-commands `/plugin ...` ne sont pas invocables depuis un script bash.**
L'installation du plugin est une étape manuelle documentée, pas automatisée par init-project.sh.

**Fichiers :**
- `init-project.sh` : copie `.codex/config.toml.template` → `.codex/config.toml` et affiche les instructions d'installation du plugin
- `.codex/config.toml.template` : config par défaut du projet
- `CLAUDE.md.template` : section "Setup Codex" avec les 3 commandes à exécuter manuellement

**Instructions affichées par init-project.sh :**
```
echo "=== Codex Plugin Setup (manual) ==="
echo "Run these commands in Claude Code:"
echo "  /plugin marketplace add openai/codex-plugin-cc"
echo "  /plugin install codex@openai-codex"
echo "  /codex:setup"
```

**Review gate : désactivé par défaut.** Activable manuellement via `/codex:setup --enable-review-gate`.

**Success criteria :**
- [ ] init-project.sh copie .codex/config.toml et affiche les instructions manuelles d'installation du plugin
- [ ] Config template copiée
- [ ] Review gate désactivé par défaut
- [ ] L'installation du plugin reste manuelle (slash-commands non invocables depuis bash)

---

### A11. SPARC Phase 4 — option Codex rescue

**Fichier modifié :** `.claude/skills/sparc/SKILL.md`

En Phase 4, Claude demande UNE FOIS :

```
"Implémentation par Claude Code ou Codex ?"
  Option A : Claude Code execute (défaut, GSD standard)
  Option B : Codex execute (/codex:rescue "implement based on sparc-arch.md")
```

Si Option B : `/codex:rescue` reçoit les specs des Phases 1-3 comme contexte.

**Success criteria :**
- [ ] Choix proposé une seule fois en Phase 4
- [ ] Option A = défaut
- [ ] Option B passe le contexte SPARC à Codex

---

### A12. SPARC Phase 5 — dual review (Codex adversarial + CE:review)

**Fichier modifié :** `.claude/skills/sparc/SKILL.md`

Phase 5 lance automatiquement les deux reviews :

```
AUTOMATIQUE :
  /codex:adversarial-review       ← cross-model challenge (design, tradeoffs)
  /ce:review                      ← Claude multi-agent (architecture, patterns, qualité)
Claude synthétise les deux → verdict GO / NO-GO
```

Les deux reviews ont des angles différents :
- Codex : "est-ce la bonne approche ? quels sont les risques du design ?"
- CE:review : "le code est-il propre, sûr, maintenable ?"

**Success criteria :**
- [ ] Les deux reviews lancées automatiquement en Phase 5
- [ ] Synthèse unifiée avec verdict
- [ ] Si NO-GO : retour Phase 4 avec findings des deux reviews

---

### A13. Pre-flight — Codex adversarial sur le plan

**Fichier modifié :** `.claude/skills/pre-flight/SKILL.md`

Après les 5 agents Claude + synthèse, pre-flight lance automatiquement :

```
/codex:adversarial-review --background --base main
```

Le review Codex challenge le PLAN (pas le code — il n'y a pas encore de code).
Les findings Codex sont intégrés dans le Pre-Flight Report, section "Cross-Model Challenge".

**Success criteria :**
- [ ] Codex adversarial lancé automatiquement après les 5 agents
- [ ] Section "Cross-Model Challenge" dans le report
- [ ] Si Codex non disponible (pas installé) : skip silencieux, pas de blocage

---

### A14. /prepare-phase — orchestrateur automatisé

**Fichier :** `.claude/skills/prepare-phase/SKILL.md`

Orchestre toute la séquence de préparation en une seule commande :

```
/prepare-phase {N}
```

**Séquence :**

```
1. /gsd:discuss-phase           ← AUTOMATIQUE
2. /gsd:plan-phase              ← AUTOMATIQUE, produit PLAN.md
3. Demande : "Deepen le plan ?" ← UNE SEULE INTERACTION
     [Oui (recommandé) / Skip]
4. /ce:deepen-plan              ← si Oui, AUTOMATIQUE
5. /pre-flight                  ← AUTOMATIQUE (5 agents + Codex adversarial)
6. Retourne le Pre-Flight Report + Verdict
```

**Comportement :**
- Chaque étape attend que la précédente soit terminée avant de continuer
- Si discuss-phase ou plan-phase échoue → arrêt, diagnostic à l'utilisateur
- Si pre-flight retourne NO-GO → informer l'utilisateur, proposer de refaire le plan
- Les skills sous-jacents (GSD, CE, pre-flight) ne sont PAS modifiés — prepare-phase les appelle en séquence

**Ce que prepare-phase ne fait PAS :**
- Modifier les skills GSD ou CE (pas d'écrasement au update)
- Lancer l'exécution (c'est SPARC ou execute-phase qui s'en charge)
- Forcer deepen-plan (l'utilisateur choisit)

**Success criteria :**
- [ ] Skill créé dans .claude/skills/prepare-phase/
- [ ] Séquence complète fonctionne en une commande
- [ ] Deepen-plan skippable (1 interaction)
- [ ] Pre-flight Report retourné à la fin
- [ ] Aucune modification des skills sous-jacents

---

### A16. /todo skill — CRUD encapsulé pour todos/

**Fichier :** `.claude/skills/todo/SKILL.md`

Le système de todos fichier (todos/) n'a aucune validation — Write brut, pas de séquençage d'ID, pas de déplacement de fichiers. Ce skill encapsule toutes les opérations.

**Actions :**

```
/todo create "description"     → lit dernier ID dans pending/ + complete/ + done/
                                 → incrémente, écrit le fichier dans pending/
/todo close {ID}               → déplace pending/{ID}.md → complete/{ID}.md
                                 → met à jour frontmatter (status, date)
/todo done {ID}                → déplace complete/{ID}.md → done/{ID}.md
                                 → après vérification que le todo est bien complete
/todo validate                 → scan les 3 dossiers
                                 → détecte doublons d'ID, gaps, fichiers mal placés
/todo list                     → affiche les pending groupés par phase
                                 → avec count par statut (pending/complete/done)
```

**Comportement du create :**
1. Lire tous les fichiers dans pending/, complete/, done/
2. Extraire les IDs numériques des noms de fichiers
3. Prendre le max + 1
4. Écrire le fichier avec frontmatter standard (id, title, status, phase, created_at)

**Comportement du close :**
1. Vérifier que le fichier existe dans pending/
2. Le déplacer (git mv) vers complete/
3. Mettre à jour le frontmatter : status: complete, completed_at: today

**Intégration SPARC :** SPARC Phase 5 (Completion) appelle `/todo close` sur les todos de la tâche quand le verdict est GO.

**Success criteria :**
- [ ] 5 actions fonctionnelles (create, close, done, validate, list)
- [ ] ID toujours séquentiel, jamais de doublon
- [ ] Déplacement de fichier réel (pas juste changement de frontmatter)
- [ ] validate détecte les anomalies

---

### A17. Règle CARL — interdit Write direct dans todos/

**Fichier :** `.carl/{CARL_DOMAIN}`

Règle :

```
TEMPLATE_RULE_X = Ne jamais écrire directement dans todos/ avec Write ou Edit.
Toujours utiliser /todo create|close|done. Si un subagent doit créer un todo,
il doit passer par le skill /todo.
```

**Pourquoi :** Sans cette règle, Claude (et les subagents) vont continuer à utiliser Write brut pour créer des todos — c'est le chemin de moindre résistance. La règle CARL force le passage par le skill.

**Cohérence avec l'enforcement pre-flight :** Même pattern — CARL comme première ligne de défense, session-gate `/todo validate` comme filet de sécurité.

**Success criteria :**
- [ ] Règle ajoutée dans le bon domaine CARL
- [ ] Numéro séquentiel correct
- [ ] Formulation actionnable

---

### A18. CLAUDE.md.template + init-project.sh (mise à jour finale)

Reprend A9 + ajouts A10-A14.

**CLAUDE.md.template modifications supplémentaires :**

**Section Outils actifs** — version finale :

```markdown
- GSD                    → macro : roadmap, phases, milestones
- SPARC                  → micro-exécuteur par défaut dans une phase GSD (CE:work reste pour hors phase)
- Compound Engineering   → brainstorm, plan, deepen, review, compound
- Codex plugin           → cross-model review + délégation implémentation
- CARL                   → règles dynamiques selon contexte
- Swarm patterns         → conventions multi-agent (voir .claude/rules/swarm-patterns.md)
- AgentDB               → mémoire sémantique self-hosted (remplace Supermemory)
```

**Section Workflows** — version finale :

```markdown
### Parcours phase GSD (SPARC toujours)

/prepare-phase → /sparc "description" → /gsd:verify-work

Note : /sparc est invoque explicitement apres /prepare-phase.
/gsd:execute-phase n'est PAS wrappe — SPARC est un skill template independant.

### Parcours tâche isolée (hors phase GSD)

CE:work pour les tâches structurées hors phase
/gsd:fast "description" pour les quick fixes triviaux
```

**init-project.sh modifications supplémentaires :**
- Afficher les instructions manuelles d'installation du plugin Codex (slash-commands non invocables depuis bash)
- Copier `.codex/config.toml.template`
- Copier `.claude/skills/prepare-phase/`
- Copier `.claude/skills/sparc/`

**Success criteria :**
- [ ] CLAUDE.md.template < 200 lignes (budget Anthropic)
- [ ] Tous les nouveaux skills et fichiers copiés par init-project.sh
- [ ] Références Supermemory remplacées par AgentDB
- [ ] Flow complet documenté
- [ ] 2 parcours (phase GSD avec SPARC, tâche isolée hors phase) clairement distingués

---

## Ordre d'implémentation (révisé après deepen + triage Codex)

Principe : réduire le risque d'implémenter vite quelque chose qu'il faudrait re-défaire.

### Phase 1 — Stabiliser le contrat d'orchestration

Rien n'est implémenté tant que le contrat workflow n'est pas figé.

- Retirer l'idée de wrapper /gsd:execute-phase (finding archi HIGH)
- Fixer le parcours officiel dans workflow-architecture.md :
  - Phase GSD : /prepare-phase puis SPARC via séquencement explicite
  - Hors phase : CE:work
  - Quick fix : /gsd:fast
- Aligner le plan (A3, A14) avec le nouveau contrat

### Phase 2 — AgentDB fiable et sûr (Track B, parallélisable)

AgentDB peut être développé en parallèle de Phase 1/3 (repo séparé pour le serveur VPS).

- B1 : VPS setup (docker-compose, API, config.json gitignored/template only)
- B2 : MCP thin client (local-first + retry queue)
- B3 : Format entries
- B4 : Reindex script + fallback (Agent Explore sur entries/)
- B5 : Skills update (redirection Supermemory → AgentDB)
- B6 : Cross-projet namespace (scope=global enforcement)
- B7 : Deprecation Supermemory

Sécurité v1 : clé par projet + contrôle namespace côté API. JWT/RBAC en v2 si besoin.

### Phase 3 — Skills/rules/hooks template (Track A, séquentiel)

Dépend de Phase 1 (contrat figé). Peut commencer en parallèle de Phase 2.

- A1 : swarm-patterns.md (fondation, < 80 lignes)
- A2 : Pre-flight enrichi (Agent 5 Critic)
- A3 : SPARC skill (invoqué en séquence par /prepare-phase, pas en wrappant GSD)
- A6 : ADR auto-tracking (quick win)
- A7 : DDD léger contexts.md (lazy-load, pas auto-injecté)
- A10 : Plugin Codex install (config + instructions manuelles)
- A11 : SPARC Phase 4 option Codex
- A12 : SPARC Phase 5 dual review
- A13 : Pre-flight Codex adversarial (non-bloquant, addendum)
- A4 : CARL rule enforcement pre-flight
- A5 : Session-gate Check 18 (pre-flight enforcement)
- A14 : /prepare-phase (orchestrateur séquentiel)
- A16 : /todo skill CRUD
- A17 : CARL rule todos (advisory v1, hook strict optionnel)
- A8 : Hook PreToolUse Agent (log tronqué 60 chars, jq pas python3)

### Phase 4 — UX opératoire

Dépend de Phase 3 (skills fonctionnels).

- A14 enrichi : `--from` flag sur /prepare-phase
- A5 enrichi : trace d'enforcement dans session-gate report
- A16 enrichi : prévention doublons /todo (check similarité titre)
- Doc : annotations "(if Codex installed)" dans workflow-architecture.md
- Doc : "Getting Started" progressive disclosure dans workflow-architecture.md
- Doc : CE:work hors phase documenté explicitement
- A8 enrichi : Session-gate Check 19 (agent spawn audit)

### Phase 5 — Optimisations sous preuve (DEFER)

Ne pas implémenter avant validation en usage réel.

- Agent 5 en parallèle avec Agents 2-4 (redéfinir le rôle d'abord)
- Changement modèle embedding (bge-small vs nomic — benchmarker d'abord)
- Réduction budget lignes swarm-patterns.md (60 vs 80)
- Redéfinition /gsd:quick (sémantique externe, ne pas toucher)

### Phase finale — Documentation et init

- A18 : CLAUDE.md.template + init-project.sh (attend Phase 3 + B5)
- init-project.sh --upgrade (spec à définir pendant implémentation)

### Dépendances

```
Phase 1 (contrat) ← bloque Phase 3 (skills)
Phase 2 (AgentDB) ← parallèle, bloque A18 via B5
Phase 3 (skills)  ← bloque Phase 4 (UX)
Phase 4 (UX)      ← bloque Phase finale
Phase 5 (optim)   ← indépendante, sous preuve
```

---

## Risk Analysis

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|
| Claude ignore swarm-patterns.md | Élevée | Moyen | Défense en profondeur : règle + CARL + hook + intégré dans SPARC |
| Pre-flight Agent 5 allonge le temps de pre-flight | Moyenne | Faible | Agent 5 est séquentiel mais rapide (~30s). Skip si plan trivial |
| SPARC trop lourd pour tâches moyennes | Moyenne | Moyen | Phase skip explicite + routing vers /gsd:quick pour tâches simples |
| VPS AgentDB down | Faible | Moyen | Fallback keyword search sur entries/ (git-tracked) |
| Modèle embedding pas assez bon | Faible | Élevé | Choix d'un modèle top-tier (nomic-embed-text-v1.5). Remplaçable sans changer l'API |
| Collègues n'adoptent pas SPARC | Moyenne | Faible | SPARC est optionnel. Le vrai gain est dans pre-flight (forcé) et AgentDB (transparent) |
| Migration Supermemory perd des données | Faible | Élevé | Coexistence 2 semaines + entries git-tracked + rollback possible |
| Hook PreToolUse ralentit le workflow | Faible | Faible | Exit 0 en < 1s, log seulement |
| Codex non installé chez un collègue | Moyenne | Moyen | Skip silencieux si Codex absent — pre-flight et SPARC fonctionnent sans (pas de blocage) |
| Review gate Codex drain usage limits | Moyenne | Élevé | Désactivé par défaut, activation manuelle explicite |
| /prepare-phase trop long | Faible | Moyen | Chaque étape peut être lancée individuellement si besoin |

---

## Acceptance Criteria globales

### Track A

- [ ] swarm-patterns.md existe et < 80 lignes
- [ ] Pre-flight a 5 agents, Agent 5 = critic
- [ ] Pre-flight lance Codex adversarial automatiquement (skip si Codex absent)
- [ ] SPARC skill fonctionne end-to-end (5 phases)
- [ ] SPARC Phase 3 utilise dual-agent (architect + critic)
- [ ] SPARC Phase 4 propose choix Claude/Codex
- [ ] SPARC Phase 5 lance Codex adversarial + CE:review automatiquement
- [ ] CARL rule empêche execute sans pre-flight
- [ ] Session-gate Check 18 détecte pre-flight manquant
- [ ] execution-quality.md a la section ADR auto-tracking
- [ ] docs/architecture/contexts.md.template existe
- [ ] Hook PreToolUse Agent logge les spawns
- [ ] Plugin Codex : config copiée par init-project.sh, instructions manuelles affichées
- [ ] /prepare-phase orchestre discuss→plan→deepen→pre-flight
- [ ] /todo skill fonctionnel (create, close, done, validate, list)
- [ ] CARL rule interdit Write direct dans todos/
- [ ] CLAUDE.md.template à jour, < 200 lignes

### Track B

- [ ] VPS Qdrant + embedding + API fonctionnels
- [ ] MCP thin client avec 5 outils
- [ ] `agentdb_search` retourne des résultats pertinents (score > 0.7 sur queries connues)
- [ ] `agentdb_debug` montre les scores bruts
- [ ] agentdb_store sync local+VPS fonctionne (pas de hook séparé)
- [ ] /lesson, /ce:compound, /project-bootstrap redirigés vers AgentDB
- [ ] Cross-projet namespace fonctionne
- [ ] Migration docs/solutions/ → entries/ complète
- [ ] Supermemory déprécié après période de coexistence

---

## Resource Estimates

| Track | Effort estimé | Prérequis |
|-------|--------------|-----------|
| A1-A2 | 1 session | Aucun |
| A3, A11, A12 | 1 session | A1 + A2 + A10 |
| A4-A8, A10, A13 | 1 session | A1-A3 |
| A14 | 0.5 session | A2 + A13 |
| A16-A17 | 0.5 session | Indépendant |
| A18 | 0.5 session | Tout Track A + B5 |
| B1 | 1 session | Accès VPS + Docker |
| B2-B3 | 1 session | B1 |
| B4-B6 | 1 session | B2 |
| B7 | 0.5 session | B5 + 2 semaines coexistence |

**Total : ~9 sessions, 2 tracks parallélisables**

---

## Architecture Reference

Voir [docs/architecture/workflow-architecture.md](../architecture/workflow-architecture.md) pour :
- Layers du système (macro/micro/nano)
- Flow complet détaillé avec diagrammes
- Inventaire fichiers du template
- Décisions architecturales
- Glossaire

---

## Cross-cutting concerns (review Codex 2026-03-31)

Les points suivants s'appliquent transversalement aux livrables. À adresser pendant l'implémentation, pas comme livrables séparés.

### Compatibility / rollout strategy (HIGH)

Le plan décrit le template neuf. Pour les projets existants déjà scaffoldés :

- `init-project.sh` doit supporter un mode `--upgrade` qui ajoute les nouveaux fichiers sans écraser les fichiers projet-spécifiques (CLAUDE.md, MEMORY.md, LESSONS.md, DECISIONS.md)
- `/template-sync` existant couvre déjà partiellement ce besoin — vérifier qu'il détecte les nouveaux skills/rules/hooks ajoutés par ce plan
- Documenter dans le README les étapes de migration manuelle (surtout Supermemory → AgentDB)

### Validation matrix (HIGH)

Pour chaque gros livrable, définir pendant l'implémentation :

| Livrable | Test manuel | Test mécanique | Scénario d'échec |
|----------|-----------|----------------|-------------------|
| SPARC | Lancer `/sparc` sur une tâche test, vérifier les 5 phases | Session-gate Check 18 (pre-flight avant execute) | Phase 3 architect retourne < 3 lignes → SPARC arrête |
| Pre-flight v2 | Lancer `/pre-flight` et vérifier Agent 5 Critic dans le report | Check 18 (PREFLIGHT.md existe) | Codex non installé → skip silencieux, pas de blocage |
| /todo | Créer, close, done un todo, vérifier les IDs | `/todo validate` détecte doublons | Write direct dans todos/ → CARL bloque |
| AgentDB | `agentdb_store` + `agentdb_search` sur un terme connu | `agentdb_debug` retourne scores > 0.7 | VPS down → fichier local écrit, search retourne fallback keyword |

### Failure-mode design AgentDB (HIGH)

| Scénario | Comportement attendu | Action utilisateur |
|----------|---------------------|-------------------|
| VPS lent (> 5s) | `agentdb_store` écrit local immédiatement, sync VPS en arrière-plan timeout 10s | Aucune — transparent |
| VPS indisponible | `agentdb_store` écrit local, log erreur dans `.agentdb/sync-errors.log` | `scripts/agentdb-reindex.sh` quand VPS revient |
| Embeddings KO | Recherche retourne 0 résultat avec score 0 | `agentdb_debug` montre le problème, fallback Agent Explore sur entries/ |
| Namespace corrompu | `POST /reindex` rebuild depuis les fichiers .agentdb/entries/ | Lancer `scripts/agentdb-reindex.sh` |
| Résultats vides pour query connue | `agentdb_debug` montre les scores bruts | Reformuler la query, baisser min_score, ou vérifier que l'entry existe |

### Security model AgentDB (MEDIUM)

À définir pendant B1 (VPS setup) :

- API key par projet (pas globale) — stockée dans `.agentdb/config.json` via env var `$AGENTDB_API_KEY`
- Namespace isolation : un projet ne peut pas query le namespace d'un autre (sauf `global`)
- Namespace `global` : write nécessite classification "cross-projet" explicite
- Pas de données sensibles dans les entries — même politique que docs/solutions/
- Journalisation : le VPS logge chaque request (timestamp, namespace, action, entry_id)
- Rétention : pas de purge automatique. Suppression manuelle via `agentdb_delete` ou cleanup des entries/ git-tracked
- API key rotation : changer la clé dans l'env var + restart du MCP client

### Observability (MEDIUM)

| Système | Log/métrique | Où | Healthy signal |
|---------|-------------|-----|----------------|
| Pre-flight | Durée totale + nombre de findings par agent | Pre-Flight Report | < 2min, < 10 findings HIGH |
| SPARC | Phase courante + durée par phase | `.claude/workspace/sparc-*.md` | Chaque phase < 1min (sauf Phase 4) |
| agentdb_store | Succès/échec sync VPS | `.agentdb/sync-errors.log` | 0 erreurs |
| agentdb_search | Score moyen des résultats | `agentdb_debug` output | Scores > 0.6 pour queries connues |
| Agent spawns | Count par session | `.claude/workspace/agent-log.txt` | < 15 par session |
| Codex reviews | Durée + findings count | Codex output dans le report | < 3min |

### Cost / latency budget (MEDIUM)

| Opération | Budget acceptable | Si dépassé |
|-----------|------------------|------------|
| Pre-flight complet (5 agents + Codex) | < 3min | Codex en background, ne bloque pas |
| SPARC Phase 3 (dual-agent) | < 1min | Les deux agents en parallèle |
| SPARC Phase 5 (dual review) | < 2min | Codex + CE:review en parallèle |
| agentdb_store (local + sync) | < 2s pour le local, sync async | Sync timeout 10s, log erreur |
| agentdb_search | < 3s | Fallback keyword si timeout |
| Embedding (VPS) | < 1s par entry | Batch si > 10 entries |

### Idempotence / replay (MEDIUM)

| Opération | Idempotent ? | Comportement si relancé |
|-----------|-------------|------------------------|
| `/todo create "X"` | Non — crée un doublon | `/todo validate` détecte, user corrige manuellement |
| `agentdb_store` même entry | Oui — upsert par ID fichier | Update l'embedding et les métadonnées |
| `POST /reindex` | Oui — rebuild complet | Safe à relancer |
| `/codex:adversarial-review` | Oui — review read-only | Même résultat (ou différent si code a changé) |
| SPARC Phase 1-3 | Non — produit de nouveaux fichiers | Écraser les fichiers workspace existants |
| `/pre-flight` | Oui — écrase le rapport existant | Nouveau PREFLIGHT.md remplace l'ancien |

---

## Enhancement Summary (ce:deepen-plan 2026-03-31)

**Deepened on:** 2026-03-31
**Agents used:** architecture-strategist, security-sentinel, performance-oracle, spec-flow-analyzer
**Agents failed (context overflow):** 4 Explore agents (SPARC, AgentDB, Codex, swarm research)
**Triage:** Codex cross-model review applied — findings classified as KEEP / REFORMULATE / DEFER

### Architecture Review Insights

**HIGH — SPARC wrapping /gsd:execute-phase creates fragile coupling.** `KEEP`
GSD is an external plugin subject to updates. Wrapping its entrypoint breaks silently on GSD update.
**Action:** SPARC should be invoked by /prepare-phase or a sequencing skill that calls GSD then SPARC, never by patching GSD's execute-phase entrypoint. Update A3 and architecture doc accordingly.

**HIGH — AgentDB local-first sync has silent data divergence window.** `KEEP`
If VPS is down, entries are stored locally but never retried automatically. A colleague searching immediately won't find them.
**Action:** Add automatic retry queue in the MCP client (file-based pending sync). On next `agentdb_store` or session start, retry pending entries. Update B2.

**MEDIUM — Codex at 2 gates doubles dependency exposure.** `KEEP`
Pre-flight + SPARC Phase 5 both call Codex adversarial. If Codex rate-limits, both gates degrade.
**Action:** Pre-flight Codex = truly async/background (append as addendum, never block verdict). SPARC Phase 5 Codex = synchronous. Update A12/A13.

**MEDIUM — 5-layer enforcement needs debug trace.** `KEEP`
When session-gate catches a violation, no mechanism surfaces which layer should have blocked it.
**Action:** Add "enforcement trace" field in session-gate report. Update A5.

**LOW — /todo concurrent ID collision.** `KEEP`
Two sessions could create duplicate IDs.
**Action:** Use timestamp-based ID fallback (e.g., `YYYYMMDD-HHMMSS-{seq}`). Update A16.

**LOW — No middle ground between SPARC-always and /gsd:fast.** `DEFER`
/gsd:quick is une commande externe avec une semantique deja definie — ne pas la redefinir.
Differe jusqu'a validation en usage reel que le manque de middle-ground est un vrai probleme.

### Security Review Insights

**HIGH — .agentdb/config.json must NOT be git-tracked.** `KEEP`
If a colleague hardcodes the API key, it gets committed.
**Action:** Gitignore `.agentdb/config.json`. Ship only `.agentdb/config.json.template`. MCP client reads `AGENTDB_API_KEY` from `process.env` directly. Update B2/B3.

**HIGH — Single shared API key with no RBAC.** `REFORMULATE`
A leaked key gives full read/write/delete access to the namespace + global.
**v1:** Cle non commitee + cle par projet + controle namespace cote API. Suffisant pour un template partage en equipe.
**v2 (si besoin reel):** JWT/RBAC par collegue avec scopes namespace. `POST /reindex` et `DELETE` requierent scope "admin".

**HIGH — Namespace isolation is application-level only.** `KEEP`
Qdrant has no built-in access control. A crafted HTTP request bypasses the MCP client.
**Action:** Validate namespace claim from API key before every Qdrant operation. Consider separate Qdrant collections per project. Update B1.

**MEDIUM — pre-agent.sh logs full agent description (may contain sensitive data).** `KEEP`
**Action:** Log only `subagent_type` + first 60 chars of description. Set file permissions to 600. Update A8.

**MEDIUM — Codex sends plan/code to OpenAI — undocumented data flow.** `KEEP`
**Action:** Document what data is transmitted. Add per-project Codex disable toggle in `.codex/config.toml`. Verify OpenAI's data retention policy. Update A10.

**MEDIUM — CARL rule for todos/ is advisory only.** `REFORMULATE`
Subagents don't inherit CARL context.
**v1:** CARL rule (advisory) — suffisant pour la majorite des cas.
**Option stricte (non defaut):** PreToolUse hook on Write matcher qui bloque les ecritures dans `todos/`. Activable manuellement si le CARL ne suffit pas.

**MEDIUM — Global namespace writable by any project with valid key.** `KEEP`
**Action:** VPS API enforces `scope=global` parameter + valid project-namespace key for global writes. Update B6.

**LOW — Use jq instead of python3 for JSON parsing in hooks.** `KEEP`
Simpler, faster, no import overhead.

### Performance Review Insights

**Latency estimates:**
- /prepare-phase total: **8-15 minutes** wall-clock
- Pre-flight alone: **2.5-4 minutes** (Agent 5 sequential = bottleneck)
- AgentDB embedding (CPU VPS): **200-800ms** per call
- Full lifecycle (prepare + SPARC + closure): **~25-30K tokens**

**Top optimizations (prioritized by impact):**

1. **Parallelize Agent 5 with Agents 2-4.** `DEFER`
Casse le design ou Agent 5 challenge specifiquement les findings de l'Agent 1.
A ne pas prendre sans redefinir le role du critic. Differe.

2. **Use bge-small-en-v1.5 (33M) instead of nomic-embed-text-v1.5 (137M).** `DEFER`
Le gain de latence est plausible mais "quality negligible" n'est pas demontre.
A valider par benchmark reel sur le VPS avant de changer. Differe.

3. **Codex adversarial truly non-blocking in pre-flight.** `KEEP`
Append as addendum, don't block verdict. Aligns with architecture review finding. Update A13.

4. **Cap swarm-patterns.md at 60 lines, not 80.** `DEFER`
Optimisation prematuree. A revalider si le context flooding devient un vrai probleme.

5. **Lazy-load contexts.md only in pre-flight/SPARC Phase 3.** `KEEP`
Do not auto-inject via rules. Pass explicitly to Agent 5 and SPARC architect/critic. Update A7.

### Spec Completeness Review Insights

**Missing error paths:**

1. `/prepare-phase` — no way to redo just discuss-phase without restarting the full sequence. `KEEP`
**Action:** Add a `--from` flag: `/prepare-phase 3 --from plan` to resume from a specific step. Update A14.

2. SPARC Phase 3 — no tiebreaker when architect and critic contradict without clear winner. `KEEP`
**Action:** Claude principal breaks the tie with a documented rationale. Add to SPARC skill. Update A3.

3. SPARC Phase 5 — no max retry count for NO-GO loop. `REFORMULATE`
Pas un hard cap absolu. Apres 2 NO-GO consecutifs, demander une decision explicite a l'utilisateur (pas auto-loop). Update A3.

4. `agentdb_search` timeout fallback — "keyword search on entries/" is mentioned but no mechanism implements it. `KEEP`
**Action:** Implement fallback as Agent Explore on `.agentdb/entries/` with grep. Update B2.

**Edge cases unspecified:**

5. Empty project (phase 1, no prior context) — `/prepare-phase` behavior undefined. `KEEP`
**Action:** If no PLAN.md exists and no phases defined, /prepare-phase starts discuss from scratch. Document. Update A14.

6. Codex not installed — "skip silently" contradicts architecture flow diagram showing Codex as required. `KEEP`
**Action:** Add explicit "(if Codex installed)" annotation in all architecture flow diagrams. Update workflow-architecture.md.

7. `/todo create` is non-idempotent with no guard against duplicates. `KEEP`
**Action:** `/todo create` checks title similarity against pending/ before creating. Warn if >80% match. Update A16.

**Onboarding gaps:**

8. No progressive disclosure — new team member must understand GSD+CE+CARL+SPARC+AgentDB+Codex. `KEEP`
**Action:** Add a "Getting Started" section to workflow-architecture.md: "Day 1: use /prepare-phase + /gsd:execute-phase. Everything else is automatic." Update architecture doc.

9. CE:work has no slash command — user must type prose. Undocumented. `KEEP`
**Action:** Document in architecture Section 4: "Hors phase: describe the task in prose, Claude uses CE:work automatically."

10. `init-project.sh --upgrade` mentioned but has no spec. `DEFER`
**Action:** Define during implementation of A18. Not blocking for the plan.

---

## Sources

- [ruvnet/ruflo](https://github.com/ruvnet/ruflo) — CLAUDE.md, SPARC skill, settings.json, agent YAML, swarm commands
- [openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc) — Plugin Codex pour Claude Code (review, adversarial, rescue)
- Session d'analyse 2026-03-31 — comparaison ruflo vs project-template-v2, analyse Codex plugin
- Pre-flight existant : `.claude/skills/pre-flight/SKILL.md`
- Execution quality existant : `.claude/rules/execution-quality.md`
- Session-gate existant : `.claude/skills/session-gate/SKILL.md`
- CLAUDE.md.template existant
