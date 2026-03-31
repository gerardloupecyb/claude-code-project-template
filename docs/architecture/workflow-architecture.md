---
title: "Workflow Architecture — project-template-v2"
type: architecture
status: target
date: 2026-03-31
source_plan: docs/plans/2026-03-31-feat-ruflo-concepts-integration-plan.md
---

# Workflow Architecture — project-template-v2

> Architecture CIBLE apres implementation du plan 2026-03-31.
> Ce document decrit l'etat APRES implementation. Tous les elements (NEW) n'existent
> pas encore. Consulter les fichiers reels du template pour l'etat actuel.
> Mis a jour quand l'architecture change. Derniere mise a jour : 2026-03-31

---

## 0. Etat actuel — reference vers les fichiers reels

Avant implementation du plan, le template contient :

| Composant | Fichier reel | Etat |
|-----------|-------------|------|
| Pre-flight | .claude/skills/pre-flight/SKILL.md | 4 agents (pas 5) |
| Session-gate | .claude/skills/session-gate/SKILL.md | 16 checks (pas 18) |
| Execution quality | .claude/rules/execution-quality.md | 3 sections, 42 lignes |
| Tool routing | .claude/rules/tool-routing.md | Actif |
| Hooks | .claude/hooks/session-start.sh, pre-compact.sh | 2 hooks |
| Settings | .claude/settings.json | PreCompact + SessionStart hooks |
| Memoire | Supermemory MCP (pas AgentDB) | Actif |
| Todos | todos/ (racine, Write brut, pas de skill) | Pas de CRUD encapsule |
| SPARC | N'existe pas | — |
| Codex plugin | Non installe | — |
| AgentDB | N'existe pas | — |
| Swarm patterns | N'existe pas | — |
| /prepare-phase | N'existe pas | — |
| /todo | N'existe pas | — |

---

## 1. Layers du systeme

Le template organise le travail en 3 layers distincts :

```
Layer                Scope               Outil principal        Granularite
---------------------------------------------------------------------------
MACRO  (projet)      Roadmap, phases     GSD                    Semaines/jours
MICRO  (tache)       Execution d'une     SPARC (dans GSD)       Heures
                     tache dans une      CE:work (hors GSD)
                     phase
NANO   (action)      Quick fix explicite /gsd:fast              Minutes
```

### Macro — GSD

Gere le cycle de vie du projet : milestones, phases, requirements, state tracking.
Produit : roadmap, PLAN.md, STATE.md, VERIFICATION.md.

### Micro — SPARC / CE:work

**Dans une phase GSD → SPARC toujours.** Pas de decision de complexite — SPARC est
le micro-executeur par defaut pour toute tache dans une phase. Si la tache est simple,
les phases SPARC sont rapides (Phase 2 Pseudo et Phase 3 Arch seront legeres).

**Hors phase GSD → CE:work.** Pour les taches isolees qui ne vivent pas dans une phase.

### Nano — /gsd:fast

Choix explicite de l'utilisateur pour les quick fixes triviaux.
Pas de SPARC, pas de pre-flight. L'utilisateur decide consciemment de shortcuter.

---

## 2. Outils et leurs responsabilites

```
Outil                  Responsabilite                         Owner
--------------------------------------------------------------------------------
GSD                    Roadmap, phases, milestones, state     Externe (plugin)
SPARC (NEW)            Micro-execution structuree (5 phases)  Template (skill)
Compound Engineering   Brainstorm, plan, review, compound     Externe (plugin)
CARL                   Regles dynamiques par contexte         Template + global
AgentDB (NEW)          Memoire semantique self-hosted         Template (MCP)
Codex plugin (NEW)     Cross-model review + delegation        Externe (plugin)
Pre-flight             Validation plan multi-agent (4 agents, 5 apres A2 NEW)  Template (skill)
Session-gate           Validation mecanique de session        Template (skill)
Execution quality      Regles qualite auto-injectees          Template (rules)
Swarm patterns         Conventions orchestration agents       Template (rules)
Todo (NEW)             CRUD encapsule todos/        Template (skill)
```

### Qui appelle qui

```
GSD:discuss-phase     → produit contexte discussion
GSD:plan-phase        → produit PLAN.md
CE:deepen-plan        → enrichit PLAN.md avec recherche parallele
Pre-flight            → valide PLAN.md (5 agents Claude + Codex adversarial)
SPARC                 → execute une tache complexe dans la phase
  Phase 1-3           → agents Claude (spec, pseudo, arch)
  Phase 4             → Claude execute OU Codex rescue
  Phase 5             → Codex adversarial review + CE:review
GSD:verify-work       → UAT contre acceptance criteria
/lesson               → capture lecon → AgentDB
```

---

## 3. Flow complet d'une phase — du debut a la fin

### 3.1 Preparation (automatisee via /prepare-phase)

```
toi : /prepare-phase {N}
        |
        v  AUTOMATIQUE
  /gsd:discuss-phase          Brainstorm, contexte, questions
        |
        v  AUTOMATIQUE
  /gsd:plan-phase             Cree PLAN.md dans .planning/
        |
        v  DEMANDE UNE FOIS
  "Deepen le plan ?"
  [Oui (recommande) / Skip]
        |
   Oui -+- Skip -+
        |         |
  /ce:deepen-plan |           Enrichissement parallele du plan
        |         |
        <---------+
        |
        v  AUTOMATIQUE
  /pre-flight                 Validation multi-agent du plan
        |
        v
  Pre-Flight Report
  Verdict : GO / CONDITIONAL GO / NO-GO
```

**Interventions humaines dans cette sequence : 1** (skip deepen ou pas).

Si CONDITIONAL GO : Claude presente les findings, tu choisis proceed ou fix.
Si NO-GO : retour au plan.

### 3.2 Pre-flight — detail interne

```
/pre-flight lance :

  PARALLELE (4 agents Claude) :
    Agent 1 : Architecture Strategist
    Agent 2 : Security Sentinel
    Agent 3 : Performance Oracle
    Agent 4 : Spec Flow Analyzer
        |
        v  outputs collectes
  SEQUENTIEL :
    Agent 5 : Architecture Critic
      → recoit findings Agent 1 + plan original
      → challenge design, alternatives, over-engineering
      → verifie bounded contexts (docs/architecture/contexts.md)
        |
        v  synthese Claude
  AUTOMATIQUE :
    /codex:adversarial-review --background --base main
      → Codex challenge le PLAN (cross-model, design focus)
        |
        v
  Claude synthetise tout → Pre-Flight Report + Verdict
```

### 3.3 Execution

```
Dans une phase GSD (defaut) :
  toi : /gsd:execute-phase {N}
  → le template wrappe execute-phase pour invoquer SPARC automatiquement
  → Claude affiche "Execution via SPARC (5 phases)" — l'utilisateur voit le flow
  → l'utilisateur apprend que /sparc existe et peut l'appeler directement ensuite

Appel direct SPARC (l'utilisateur connait le skill) :
  toi : /sparc "description de la tache"
  → meme skill, meme comportement, contexte demande a l'utilisateur

Hors phase GSD (tache isolee) :
  toi : utilise CE:work

Quick fix explicite (l'utilisateur shortcute consciemment) :
  toi : /gsd:fast "description"
```

SPARC a deux points d'entree :

| Declencheur | Quand | Contexte |
|-------------|-------|----------|
| Automatique | /gsd:execute-phase invoque SPARC en interne | PLAN.md + AC passes par execute-phase |
| Manuel | /sparc "description" directement | SPARC demande le contexte a l'utilisateur |

### 3.4 SPARC — detail des 5 phases

```
/sparc "implement OAuth2 login with retry pattern"

  Phase 1 — SPECIFICATION (automatique)
    Agent spec-writer (Sonnet)
      → lit PLAN.md + AC de la phase GSD
      → produit .claude/workspace/sparc-spec.md
    toi : confirme ou ajuste

  Phase 2 — PSEUDOCODE (automatique)
    Agent logic-planner (Sonnet)
      → lit sparc-spec.md
      → produit sparc-pseudo.md + TDD anchors
    toi : confirme ou ajuste

  Phase 3 — ARCHITECTURE (automatique, dual-agent)
    PARALLELE :
      Agent architect (Opus) → propose design optimal
      Agent critic (Opus)    → challenge, alternatives, simplifications
    Si docs/architecture/contexts.md existe → les deux le recoivent
    Claude synthetise → sparc-arch.md
    toi : confirme le design retenu

  Phase 4 — REFINEMENT (choix une fois)
    Claude : "Implementation par Claude Code ou Codex ?"
      Option A : Claude execute (GSD standard)
        → execution-quality.md s'applique
        → TDD d'abord (anchors Phase 2)
        → commits par unite logique
      Option B : Codex execute
        → /codex:rescue "implement based on sparc-arch.md"
        → Codex implemente dans le meme repo

  Phase 5 — COMPLETION (automatique, dual review)
    AUTOMATIQUE :
      /codex:adversarial-review           ← cross-model challenge
        → code conforme a sparc-spec.md ?
        → edge cases, securite, over-engineering
      /ce:review                          ← Claude multi-agent review
        → architecture, patterns, qualite
    Claude synthetise les deux reviews
      → verdict GO / NO-GO
      → si NO-GO : retour Phase 4 avec findings
      → si GO : tache complete
    toi : valide le verdict final
```

### 3.5 Closure

```
/gsd:verify-work              UAT contre acceptance criteria
/lesson                       Capture lecon si non-trivial
                                → agentdb_store automatique
                                → si cross-projet : namespace global aussi
/session-gate end             Verification mecanique (dont Check 18 pre-flight (NEW))
```

---

## 4. Interactions humaines — resume

### Phase GSD (SPARC par defaut)

| Etape | Toi | Automatise |
|-------|-----|-----------|
| Preparation | `/prepare-phase` | discuss + plan + deepen? + pre-flight |
| SPARC Phase 1 | Confirme spec | Agent spec-writer |
| SPARC Phase 2 | Confirme pseudo | Agent logic-planner |
| SPARC Phase 3 | Confirme design | Dual-agent architect + critic |
| SPARC Phase 4 | Choix Claude/Codex (1 fois) | Implementation + tests |
| SPARC Phase 5 | Valide verdict | Codex adversarial + ce:review |
| Closure | `/gsd:verify-work` | AgentDB sync, session-gate |

**Total : 2 commandes (`/prepare-phase` + `/gsd:execute-phase`) + 5 confirmations SPARC.**

Note : `/gsd:execute-phase` wrappe SPARC automatiquement. Il n'y a pas de parcours
"phase GSD sans SPARC". L'utilisateur peut aussi appeler `/sparc` directement.

### Tache isolee hors phase (CE:work)

```
toi : CE:work (pas de phase GSD, pas de SPARC)
```

### Quick fix explicite

```
toi : /gsd:fast "description"
```

L'utilisateur shortcute consciemment. Pas de pre-flight, pas de SPARC.

---

## 5. Enforcement — defense en profondeur

Le template a observe que Claude viole les regles, meme CARL. Strategie multi-couche :

```
Couche           Mecanisme                       Quand              Force
---------------------------------------------------------------------------
1. Rules         .claude/rules/swarm-patterns.md  Auto-charge        Faible
                 .claude/rules/execution-quality.md
2. CARL (NEW)    Regle pre-flight obligatoire     Injecte au prompt  Moyen
                 Regle Write interdit dans todos/
3. Skill (NEW)   /prepare-phase orchestre tout     Sequencement       Fort
                 /todo encapsule CRUD todos/
4. Hook          pre-agent.sh logge les spawns    PreToolUse         Audit
5. Session-gate  Check 18 detecte pre-flight (NEW) END                Mecanique
                 manquant retroactivement
```

Si Claude skip pre-flight :
- CARL devrait l'empecher (couche 2)
- Si ca passe quand meme, session-gate le detecte a la fin (couche 5)
- Le log des agents spawnes montre l'anomalie (couche 4)

---

## 6. Memoire — architecture AgentDB

### Layers de memoire

```
Layer            Fichier/Systeme           Portee          Duree de vie
---------------------------------------------------------------------------
Cache chaud      LESSONS.md                Session         Cap 50 entries
Decisions        DECISIONS.md              Projet          Tant qu'actives
State            STATE.md                  Phase GSD       Automatique
Session          memory/MEMORY.md          Session         Debut/fin session
Semantique       AgentDB (VPS)             Projet + global Permanent
Patterns         docs/solutions/           Projet          Permanent (git)
Regles           .carl/{domain}            Projet + global Permanent
DDD              docs/architecture/        Projet          Permanent (git)
                 contexts.md
```

### AgentDB — remplace Supermemory

```
Architecture :

  VPS :
    Qdrant (vector DB)  ←  collections par namespace
    Embedding service   ←  nomic-embed-text-v1.5
    REST API            ←  store, search, list, delete, reindex, debug

  Local (chaque collegue) :
    .claude/mcp/agentdb/    ← MCP thin client (HTTP)
    .agentdb/entries/       ← markdown git-tracked (source de verite)
    .agentdb/config.json    ← VPS URL + namespace

  Flow (local-first) :
    /lesson → agentdb_store → ecrit .agentdb/entries/nouveau.md → POST VPS embed + index
    agentdb_search("query") → MCP client → VPS → resultats ranked + scores
    Si VPS down : fichier local ecrit quand meme, sync rattrapage via /reindex

  Namespaces :
    project-alpha/          ← entries du projet
    project-beta/           ← entries d'un autre projet
    global/                 ← entries cross-projet (classification "cross-projet")

  Scopes de recherche :
    scope="project"         ← defaut, namespace du projet courant
    scope="global"          ← lecons cross-projet seulement
    scope="all"             ← les deux

  Fallback si VPS down :
    Agent Explore sur .agentdb/entries/ (keyword search, pas semantique)
```

### Consultation automatique (regle dans CLAUDE.md)

Avant chaque planification :
1. LESSONS.md deja charge (session start)
2. Lire DECISIONS.md
3. `agentdb_search` avec mots-cles du domaine
4. Si besoin : Agent Explore sur docs/solutions/ + .agentdb/entries/
5. Integrer dans le plan

---

## 7. Codex plugin — integration

### Commandes disponibles

```
/codex:review                 Review read-only du code actuel
/codex:adversarial-review     Challenge design + tradeoffs (cross-model)
/codex:rescue                 Delegue une tache a Codex
/codex:status                 Etat des jobs Codex
/codex:result                 Resultat d'un job termine
/codex:cancel                 Annule un job
```

### Ou Codex intervient dans le flow

```
Moment                   Commande                    Mode
---------------------------------------------------------------------------
Pre-flight               /codex:adversarial-review    Auto (plan challenge)
SPARC Phase 4            /codex:rescue                Manuel (choix user)
SPARC Phase 5            /codex:adversarial-review    Auto (code challenge)
Review gate (optionnel)  Stop hook                    Desactive par defaut
```

### Prerequis collegues

```
npm install -g @openai/codex
codex login                   ← ChatGPT plan (meme Free) suffit
/codex:setup                  ← verifie que tout est pret
```

---

## 8. Fichiers du template — inventaire complet

### Skills (.claude/skills/)

```
session-gate/SKILL.md         Validation mecanique session (17 checks, +18 pre-flight (NEW) +19 agent audit (NEW))
pre-flight/SKILL.md           Validation plan multi-agent (5 agents + Codex)
sparc/SKILL.md                Micro-execution 5 phases (NEW)
prepare-phase/SKILL.md        Orchestrateur discuss→plan→deepen→pre-flight (NEW)
todo/SKILL.md                 CRUD encapsule pour todos/ (NEW)
context-manager/SKILL.md      Gestion contexte et memoire
context-checkpoint/SKILL.md   Sauvegarde avant coupure
lesson/SKILL.md               Capture lecon → LESSONS.md + AgentDB
project-bootstrap/SKILL.md    Bootstrap projet avec lecons cross-projet
project-sync/SKILL.md         Sync etat avec outils externes
memory-consolidate/SKILL.md   Coherence cross-fichiers memoire
code-xray/SKILL.md            Exploration codebase token-efficient
template-sync/SKILL.md        Sync avec template source
```

### Rules (.claude/rules/)

```
swarm-patterns.md             Agent roles + topologie + model routing + limites (NEW)
execution-quality.md          Test check + monitoring + commit heuristics + ADR tracking
tool-routing.md               Prevention context flooding
flywheel-workflow.md          Post /ce:compound workflow
```

### Hooks (.claude/hooks/)

```
session-start.sh              Injection MEMORY.md + LESSONS.md
pre-compact.sh                Sauvegarde avant compaction
pre-agent.sh                  Log agent spawns (NEW)
```

### Fichiers memoire et etat

```
memory/MEMORY.md              Contexte session (debut/fin)
LESSONS.md                    Cache chaud lecons (cap 50)
DECISIONS.md                  Registre ADR-light
STATE.md                      Position GSD (automatique)
.agentdb/entries/             Entries semantiques git-tracked (NEW)
.agentdb/config.json          Config AgentDB (NEW)
docs/solutions/               Patterns detailles (flywheel)
docs/architecture/contexts.md Bounded contexts DDD (NEW)
```

### Config

```
.claude/settings.json         Hooks, permissions
.carl/{domain}                Regles CARL projet
CLAUDE.md                     Instructions projet (genere depuis template)
```

---

## 9. Decisions architecturales

| Decision | Alternative rejetee | Raison |
|----------|-------------------|--------|
| Zero dependance ruflo | Integrer claude-flow MCP, ruv-swarm | Trop lourd, risque breaking changes, setup collegues |
| SPARC micro-executeur par defaut en phase GSD (CE:work reste hors phase) | SPARC remplace CE:work partout | CE:work reste pertinent pour les taches isolees hors phase |
| Agent roles dans swarm-patterns.md | Repertoire agents/ YAML separe | Duplication, stale entre 2 sources |
| Dual-agent design dans pre-flight | Skill /dual-agent separe | Commande de plus a memoriser, redondant |
| Dual review (Codex + CE) en Phase 5 | Un seul des deux | Cross-model + multi-agent = couverture maximale |
| /prepare-phase orchestre tout | Enrichir /gsd:plan-phase | gsd:plan-phase est externe, ecrase au gsd:update |
| AgentDB self-hosted sur VPS | Supermemory ameliore | Boite noire non debuggable, pas de controle |
| AgentDB self-hosted sur VPS | SQLite local chaque machine | Collegues voient la meme chose, meilleur modele embedding |
| Enforcement CARL + session-gate | Regle seule | Claude viole les regles — defense en profondeur |
| DDD leger (1 fichier + regles) | DDD tracking complet | Overkill pour un template, la plupart des projets ont des domaines mais pas du DDD formel |
| Review gate Codex desactive par defaut | Active par defaut | Drain usage limits, boucle longue |
| Deepen-plan skippable | Toujours force | Parfois le plan est deja assez riche, forcer = friction |

---

## 10. Scope boundaries — ce que l'automatisation ne fait JAMAIS sans confirmation

### /prepare-phase

- Lance discuss, plan, deepen, pre-flight automatiquement
- Demande confirmation UNE FOIS pour deepen (skip ou pas)
- NE lance JAMAIS l'execution (/gsd:execute-phase ou /sparc)
- NE modifie JAMAIS un PLAN.md existant sans demander
- NE push JAMAIS vers git

### SPARC

- Chaque phase (1-5) attend la confirmation utilisateur avant de passer a la suivante
- Phase 4 demande le choix Claude/Codex UNE FOIS
- NE commit JAMAIS sans que l'utilisateur ait vu le verdict Phase 5
- NE lance JAMAIS /codex:rescue sans confirmation explicite (Phase 4 Option B)
- NE skip JAMAIS Phase 1 (Spec) — meme pour une tache "simple"

### Pre-flight

- Read-only : ne modifie JAMAIS les fichiers plan
- NE bloque JAMAIS l'execution (advisory — l'utilisateur decide)
- Codex adversarial : skip silencieux si Codex non installe (pas de blocage)

### /todo

- NE supprime JAMAIS un todo (close = deplacer, pas supprimer)
- NE modifie JAMAIS un todo ferme (done/ est immutable)

### AgentDB

- `agentdb_store` ecrit TOUJOURS localement avant de sync (local-first)
- NE pousse JAMAIS vers le namespace global sans classification "cross-projet" explicite
- NE supprime JAMAIS une entry locale lors d'un reindex

---

## 11. Exemples concrets — parcours utilisateur

### Exemple 1 — Feature standard dans une phase GSD

Contexte : Phase 3 du projet, tache "ajouter export CSV des rapports".

```
toi : /prepare-phase 3

  Claude :
    "discuss-phase : quels rapports ? quel format ? quels filtres ?"
    → discussion interactive (2-3 echanges)
    → PLAN.md cree dans .planning/
    "Deepen le plan ? [Oui (recommande) / Skip]"
  toi : Oui
    → 5 agents recherche enrichissent le plan
    → pre-flight lance (5 agents Claude + Codex adversarial)
    → Pre-Flight Report : GO

toi : /gsd:execute-phase 3

  Claude :
    "Phase 3 — Execution via SPARC (5 phases)
     Tache : implement CSV export for reports

     Phase 1/5 — Specification"
    → agent spec-writer produit les requirements
  toi : ok

    "Phase 2/5 — Pseudocode"
    → agent logic-planner produit la logique + TDD anchors
  toi : ok

    "Phase 3/5 — Architecture"
    → agent architect propose le design
    → agent critic challenge en parallele
    → Claude synthetise
  toi : ok, je prends le design A

    "Phase 4/5 — Refinement
     Implementation par Claude Code ou Codex ?"
  toi : Claude Code
    → implementation + tests

    "Phase 5/5 — Completion"
    → /codex:adversarial-review (automatique)
    → /ce:review (automatique)
    → "Verdict : GO — 0 issues majeures"
  toi : ok

toi : /gsd:verify-work
  → UAT passe
toi : /lesson "export CSV utilise streaming pour les gros fichiers"
  → lecon capturee → AgentDB sync
```

**Total : ~8 interactions humaines pour une feature complete.**

### Exemple 2 — Tache isolee hors phase (CE:work)

Contexte : un collegue demande un refactor rapide hors du roadmap GSD.

```
toi : "refactore le module de notifications pour utiliser un event bus"

  Claude utilise CE:work :
    → decompose en sous-taches
    → implemente
    → commit

  Pas de SPARC, pas de pre-flight, pas de /prepare-phase.
  CE:work gere le micro-execution librement.
```

### Exemple 3 — Quick fix trivial

Contexte : un bug en prod, fix evident.

```
toi : /gsd:fast "fix typo in email template subject line"

  Claude :
    → corrige le typo
    → commit atomique
    → done

  Pas de SPARC, pas de pre-flight, pas d'agents.
  1 commande, 1 commit.
```

---

## 12. Glossaire

| Terme | Definition |
|-------|-----------|
| **GSD** | Get Shit Done — workflow macro de gestion de projet (plugin externe) |
| **SPARC** | Specification, Pseudocode, Architecture, Refinement, Completion — micro-execution |
| **CE** | Compound Engineering — plugin brainstorm, plan, review, compound |
| **CARL** | Context-Aware Rules Language — regles dynamiques injectees au prompt |
| **AgentDB** | Memoire semantique self-hosted (Qdrant + embeddings sur VPS) |
| **Pre-flight** | Validation multi-agent d'un plan avant execution |
| **Session-gate** | Verification mecanique de l'etat session (MEMORY.md) |
| **Dual-agent** | Pattern : 2 agents avec roles opposes (architect+critic, reviewer+critic) |
| **Codex adversarial** | Review cross-model par OpenAI Codex qui challenge design et code |
| **Swarm patterns** | Conventions d'orchestration multi-agent (topologie, anti-drift, limites) |
| **Namespace** | Scope d'isolation dans AgentDB (par projet ou global) |
| **Bounded context** | Domaine avec frontiere definie (DDD leger) |
| **Flywheel** | Cycle documentation : decouverte → docs/solutions/ → CARL → AgentDB |
