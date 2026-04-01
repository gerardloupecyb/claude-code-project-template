---
date: 2026-03-31
topic: ecc-integration
source: https://github.com/affaan-m/everything-claude-code
---

# ECC Integration — Améliorations du project-template

## Problem Frame

Le project-template-v2 est solide sur l'orchestration (GSD, SPARC, prepare-phase) et la mémoire
(CARL, AgentDB, LESSONS). Mais il manque de visibilité tooling (pas d'audit context/coût), de
guardrails automatiques (aucun hook PostToolUse), et son flywheel LESSONS→CARL est entièrement
manuel. Le repo `everything-claude-code` contient des patterns battle-tested qui comblent
exactement ces gaps — sans changer l'architecture ni ajouter de dépendances npm.

## Candidates retenues (5 items, 2 tiers actifs)

> R2 (`/model-route`) supprimé : `swarm-patterns.md` est déjà chargé automatiquement à chaque session — un skill invocable n'apporte pas de valeur additionnelle.

---

### Tier 1 — No-brainer : zéro dépendance npm/pip, valeur immédiate

**R3. Bash audit log (PostToolUse hook)**
- Loggue toutes les commandes Bash dans `~/.claude/bash-commands.log` avec secrets redactés
- Pattern ECC : `jq` pipeline avec redaction de tokens, API keys, GitHub PATs
- Prérequis : `jq` (dépendance système, pré-installé sur macOS/Linux — pas npm/pip)
- Permissions `chmod 600` sur le fichier log (données sensibles potentielles)
- Opt-out : variable `CLAUDE_BASH_AUDIT=0` désactive le log sans modifier settings.json
- Note : log local à la machine, jamais commité dans le projet
- Utile pour déboguer les hooks et auditer les sessions
- *Implémentation : shell inline dans settings.json*

---

### Tier 2 — Haute valeur, adaptation nécessaire

**R4. Deep-context capture intégré dans `/prepare-phase`**
- Principe ECC : "si tu aurais besoin de chercher dans le codebase pendant l'implémentation,
  capture maintenant"
- Ajouter une phase "context capture" dans le flow de `prepare-phase` : avant la phase discuss,
  scanner le codebase pour extraire patterns existants, conventions, exemples similaires,
  gotchas — tout dans un fichier plan standalone
- Flow mis à jour : `context-capture → discuss → plan → [deepen?] → pre-flight`
- Décision : modifier `/prepare-phase` existant plutôt que créer `/prp-plan` standalone
- *Implémentation : modification du skill prepare-phase existant*

**R5. `/rules-distill` command**
- Scanne `LESSONS.md` + skills installés → identifie patterns cross-cutting → propose règles CARL
- Automatise le step manual "promouvoir une leçon vers CARL" du flywheel
- Extension naturelle du flywheel `flywheel-workflow.md` déjà en place
- *Implémentation : skill Markdown, s'appuie sur CARL manager existant*

**R6. Agent definition files (`.claude/agents/`)**
- Fichiers `.md` avec frontmatter YAML (`name`, `description`, `tools`, `model`)
- Rend les rôles de `swarm-patterns.md` invocables nommément via `Agent` tool
- Candidats : `architect.md`, `code-reviewer.md`, `tdd-guide.md`, `security-reviewer.md`
- Adaptés au template (retirer exemples Next.js/React, garder générique)
- *Implémentation : 4 fichiers, ~40 lignes chacun*

**R10. `/security-audit` command (AgentShield)**

- Source : [affaan-m/agentshield](https://github.com/affaan-m/agentshield)
- Skill Markdown qui invoque `npx ecc-agentshield scan` sur le répertoire `.claude/` du projet
- Détecte 102 classes de problèmes : secrets hardcodés, permissions trop larges, hook injection,
  supply chain MCP (`npx -y` sans pin), prompt injection dans les agents
- Optionnel : `--fix` pour auto-corriger les issues simples (refs env vars)
- Différent de R1 : pas un hook automatique, un audit on-demand avant merge/ship
- *Implémentation : skill Markdown ~20 lignes + `npx` (acceptable pour un outil d'audit)*

---

### Tier 3 — Valeur forte, décision architecturale requise

**R7. Instinct/Evolve system (remplacement de `/lesson`)**
- Système de continuous learning : observations auto-capturées via hooks → instincts → évolution
  en skills/commands/agents
- ECC version nécessite Python CLI (`instinct-cli.py`) — trop lourd pour le template
- Décision à prendre : (a) adapter en Markdown-native sans Python, (b) conserver `/lesson` et
  s'inspirer du concept sans implémenter le CLI, (c) Track C complet avec CLI
- *Bloque jusqu'à décision d'architecture*

**R8. Stop hooks (qualité automatique)**
- PostToolUse async : quality gate après chaque Edit/Write (lint/typecheck)
- Stop : format+typecheck batch, console.log checker, session evaluation
- ECC version utilise Node.js — adapter en shell pur pour le template (ou conditionnel si Node)
- *Complexité : intégration dans `session-gate` checks ou hooks séparés ?*

**R9. `/context-budget` command**
- Analyse consommation context window : agents, rules, MCPs, skills
- ECC version = script Python avec inventory complet
- Version template = audit Markdown-driven des fichiers `.claude/` avec estimations token
- Complète `tool-routing.md` avec de la visibilité chiffrée
- *Implémentation : skill Markdown + lecture des fichiers .claude/, pas de script*

---

## Success Criteria

- Tier 1 (R3) peut être livré en < 1h, zéro dépendance npm/yarn/pip — R3 requiert `jq` (dépendance système, pré-installé sur macOS/Linux)
- Tier 2 (R4-R6, R10) est compatible avec le workflow GSD/CARL existant sans réécriture ; R4-R6 shell-only, R10 via `npx` (audit on-demand acceptable)
- R3-R6 ne nécessitent aucune dépendance npm/yarn/pip — shell pur ou Markdown (R3 : `jq` système accepté)
- R10 est une **exception explicite** : `npx` requis uniquement pour l'outil d'audit on-demand (pas une dépendance de livraison continue)
- `init-project.sh` installe automatiquement les nouveaux items si inclus
- Les templates générés par `init-project.sh` bénéficient des nouveaux skills sans config manuelle
- **Chaque item livré est testé manuellement** via un projet test généré par `init-project.sh`
  avant d'être mergé sur master (voir Testing Requirements ci-dessous)

## Testing Requirements

Chaque skill/hook/commande livré doit être validé sur un projet test réel, pas seulement lu.
Protocole de test minimal par tier.

> Principe général : tester dans un projet `init`-isé frais, pas dans project-template-v2 lui-même.

### Tier 1 — Hook (R3)

- R3 : exécuter une commande Bash quelconque → vérifier que `~/.claude/bash-commands.log` est mis
  à jour avec la commande redactée

### Tier 2 — prepare-phase context capture (R4)

- Générer un projet test via `init-project.sh`
- Lancer `/prepare-phase "ajouter une feature X"` sur ce projet
- Vérifier qu'un fichier plan contextuel est généré avec les patterns du repo
- Vérifier que le flow complet (context-capture → discuss → plan → pre-flight) passe sans erreur
- **Tester aussi sur `project-template-v2` lui-même** (repo non-vide) : vérifier que le context-capture produit un résultat cohérent sur un codebase existant avec skills, rules et hooks

### Tier 2 — /rules-distill (R5)

- Ajouter 3 entrées dans `LESSONS.md` avec patterns distincts
- Invoquer `/rules-distill` → vérifier proposition de règle CARL cohérente
- Vérifier que l'output est compatible avec `/carl:tasks:add-rule`

### Tier 2 — Agent files (R6)

- Créer `.claude/agents/architect.md` dans un projet init-isé frais
- Invoquer via `Agent` tool avec `subagent_type: architect` → vérifier que le comportement correspond au fichier de définition
- Confirme que le support project-level fonctionne (global confirmé, project-level à valider)

### Tier 2 — /security-audit (R10)

- Invoquer `/security-audit` dans un projet avec `settings.json` → vérifier que agentshield scan tourne et affiche un grade
- Invoquer `/security-audit` sans `npx` disponible → vérifier message d'erreur actionnable (pas de crash silencieux)

## Scope Boundaries

- Hors scope : rules language-specific (rust, go, kotlin, java, cpp)
- Hors scope : agents spécialisés non-génériques (GAN, Flutter, healthcare)
- Hors scope : intégrations Node.js nécessitant `package.json` dans les projets cibles
- Hors scope : `/prp-prd` (redondant avec `ce:brainstorm` + le PRD de GSD)
- R7 (Instinct/Evolve) est hors scope Tier 2 — décision Track C séparée requise

## Key Decisions

- **PRP vs GSD** : pas de remplacement — complémentarité. PRP-plan s'insère dans GSD comme
  outil de deep-context capture, pas comme workflow alternatif
- **Agents folder** : les fichiers agents/ sont additifs à swarm-patterns.md, pas de remplacement
- **Shell-only** : R3-R6 en bash pur, sans Node/Python ; exception R10 (`npx` pour audit on-demand uniquement) ; R3 accepte `jq` comme dépendance système (pré-installé, pas une dep projet)
- **R2 supprimé** : `swarm-patterns.md` déjà chargé automatiquement — skill `/model-route` redondant
- **R7 séparé** : le système Instinct/Evolve mérite un brainstorm dédié (Track C potentiel)

## Dependencies / Assumptions

- `init-project.sh` est le vecteur de distribution — tous les nouveaux items passent par lui
- Les projets cibles ont `npx` disponible pour R10 (outil d'audit) — documenté dans le skill
- R6 (agents/) : support `.claude/agents/*.md` confirmé dans Claude Code 2.1.76 (`~/.claude/agents/` existe avec 56 agents) ; le test validera le support project-level

## Outstanding Questions

### Resolve Before Planning

*Toutes les questions résolues — planning débloqué.*

- [R1] **Résolu** : R1 (block-no-verify) supprimé du scope — comportement jamais observé en pratique
- [R4] **Résolu** : intégrer la deep-context capture dans `/prepare-phase` existant (pas de commande standalone)

### Deferred to Planning

- [Affects R3][Technical] Identifier le format exact du JSON PostToolUse pour le Bash audit log
  (vérifier la structure tool_input dans les hooks du template existant)
- ~~\[Affects R6\]\[Needs research\] Vérifier que la Claude Code CLI supporte `.claude/agents/*.md`
  avec frontmatter YAML~~ **Résolu** : `~/.claude/agents/` contient 56 agents dans Claude Code 2.1.76 — support global confirmé. Support project-level (`.claude/agents/`) à valider lors du test R6.
- [Affects R8][Technical] Définir si les Stop hooks remplacent ou complètent `session-gate`
- [Affects R9][Technical] Estimer les tokens des composants template pour valider l'utilité
  d'un context-budget réel vs heuristique

## Next Steps

→ Questions résolues. Plan disponible : `docs/plans/2026-03-31-002-feat-ecc-integration-tier1-tier2-plan.md`
