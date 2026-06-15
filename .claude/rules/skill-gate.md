# Skill Gate

> Source canonique du skill gate pour {{PROJECT}}.
> Ce fichier définit quels skills doivent être chargés avant toute implémentation dans un domaine protégé, ainsi que le marker `.skill-locks/{domain}` attendu par le hook.
> `CLAUDE.md` doit seulement pointer vers ce fichier, pas recopier son contenu.

## Règle générale

Avant d'écrire, éditer ou configurer dans un domaine protégé :

1. Identifier le domaine de la tâche
2. Charger le skill requis
3. Créer le marker `.skill-locks/{domain}`
4. Procéder seulement après le marker

Les markers sont session-scoped et gitignored. Ils doivent être recréés à chaque session.

## Domain Routing

> **Source unique : `.claude/gate.config.json`.** Le tableau ci-dessous est **généré** depuis ce fichier —
> le même que sourcent `pre-tool-use.sh` / `pre-mcp-gate.sh`. Régénérer avec
> `scripts/forge/render-skill-gate.sh`. **Ne pas éditer à la main entre les marqueurs.** Pour changer un
> domaine, éditer `gate.config.json` puis re-render : ceci supprime la dérive doc↔hook↔settings (AC-2-5,
> mirror collapsé en une source).

<!-- BEGIN GENERATED: domain-routing (source: .claude/gate.config.json — regenerate via scripts/forge/render-skill-gate.sh; do NOT hand-edit between markers) -->
| Domaine | Triggers (fichiers / commandes) | Skills requis | Marker (unlock) |
|---|---|---|---|
<!-- END GENERATED: domain-routing -->

## Règles de sélection

- Si plusieurs lignes {{CLOUD_PROVIDER}} s'appliquent, choisir le skill le plus spécifique au sujet
- Si la tâche touche du {{SCRIPTING_LANG}} {{PROJECT}}, toujours ajouter `{{project}}-{{scripting_lang}}-script-writer`
- Si la tâche touche {{WORKFLOW_ENGINE}}, choisir exactement un des trois skills {{WORKFLOW_ENGINE}} selon la nature du travail
- Si la tâche mélange plusieurs domaines, charger le minimum nécessaire pour couvrir le scope réel
- Ne jamais charger un skill "au cas où"

## Path-scoped rules — déclencheurs soft

Les rules suivantes sont path-scopées via `paths:` frontmatter et ne se chargent que quand Claude ouvre un fichier matching. Si la tâche implique ces triggers, lire le rule proactivement avant d'agir.

| Trigger | Rule à lire | Action attendue |
|---|---|---|
| Nouveau package Python/Node, nouveau MCP server, nouveau skill externe cloné, nouveau git submodule | `.claude/rules/supply-chain-audit.md` | Invoquer `/supply-chain-audit` avant install |
| Touche `.mcp.json`, `.claude/integrations.md`, un `SKILL.md`, `services-and-access.md`, `tool-routing.md` | `.claude/rules/governance.md` | Co-update canonical files dans le même commit |
| Déplace un dossier de phase (`planned/active/complete`), édite `ROADMAP.md`, `state.yml`, `{{rag_backend}}-registry.json` | `.claude/rules/phase-lifecycle.md` | Respecter le 4-way co-update (git mv + registry + frontmatter + ROADMAP) |
| Triage CVE, édition `dependabot.yml`, `osv-scan.yml`, `patch-management-standard.md` | `.claude/rules/dependency-surveillance.md` | Suivre le flow CVE + SLA par sévérité |
| Prépare un handoff cross-vendor Codex/Gemini, édite un task brief, ou consulte `memory/agents-feedback.md` | `.claude/rules/router-rules.md` | Charger le protocole de handoff avant de déléguer |
| Orchestre des subagents ou une équipe d'agents (prepare-phase, SPARC, review multi-agent) | `.claude/rules/swarm-patterns.md` | Charger les conventions de topologie et anti-drift avant le spawn |
| Crée, ferme, déplace ou audite des todos dans `.planning/todos/` | `.claude/rules/todo-discipline.md` | Utiliser le skill `/todo` plutôt qu'un edit manuel |
| Touche un artefact de phase (`*PLAN*`, `*CONTEXT*`, `*SUMMARY*`, `*VERIFICATION*`, `*RESEARCH*`, `ROADMAP.md`, `STATE.md`) AVANT de proposer un substep GSD (`/gsd:plan-phase`, `/gsd:execute-phase`, `/gsd:discuss-phase`) | `.claude/rules/phase-workflow-orchestrator-default.md` | Identifier l'orchestrateur canonique (`/prepare-phase`, closure protocol) et continuer son state machine ; substituer un substep uniquement avec justification explicite |

Ces rules ne bloquent pas mécaniquement (hooks couvrent les domaines {{cloud_provider}}/{{WORKFLOW_ENGINE}}/{{crm_platform}} seulement). C'est de la guidance soft — la discipline est de les lire quand le trigger s'applique.

## Correspondance avec le hook

Deux hooks **sourcent `.claude/gate.config.json`** (aucun domaine codé en dur) et vérifient les markers :

- `pre-tool-use.sh` — bloque Write/Edit/MultiEdit/Bash sur fichiers de domaine protégé (`protected_domains`)
  + applique le gate SCAG (`dep_ecosystems`, toujours actif, indépendant de `protected_domains`)
- `pre-mcp-gate.sh` — bloque les mutations MCP prod listées dans `gated_mcp` :

<!-- BEGIN GENERATED: mcp-gating (source: .claude/gate.config.json — regenerate via scripts/forge/render-skill-gate.sh; do NOT hand-edit between markers) -->
| Serveur MCP (préfixe) | Domaine (marker) | Mutation prod bloquée sans lock |
|---|---|---|
<!-- END GENERATED: mcp-gating -->

Markers vérifiés : dérivés des `marker` de `gate.config.json` ({{PROJECT}} : `{{cloud_provider}}`, `{{WORKFLOW_ENGINE}}`, `{{crm_platform}}`).

Les lectures MCP prod et tous les appels MCP dev ne sont pas bloqués.

**Single-source (AC-2-5).** Pour ajouter/modifier un domaine ou un MCP gated : éditer **uniquement**
`.claude/gate.config.json`, puis `scripts/forge/render-skill-gate.sh` pour re-générer les tables ci-dessus.
Les hooks lisent le même fichier — **ne plus éditer les regex de domaine dans les `.sh`**. `settings.json`
garde des matchers génériques (`Write|Edit|MultiEdit|Bash` ; préfixes MCP). Fail-open observable si
`gate.config.json` est absent/invalide (warning stdout+stderr + `~/.claude/gate-failopen.log`).

## Règle de maintenance

Les domaines / skills / markers / MCP gated vivent dans `.claude/gate.config.json` (**source unique**).
Après toute modification de ce fichier, exécuter `scripts/forge/render-skill-gate.sh` pour re-générer les
tables et committer les deux ensemble (le pre-commit / CI peut lancer `render-skill-gate.sh --check` pour
bloquer une dérive). Mettre à jour la **prose** de ce fichier (hors régions générées) dans le même commit si :

- un nouveau domaine protégé est ajouté (→ d'abord `gate.config.json`, puis re-render)
- une variante de skill de **sélection** change (table « Skill variants », hors région générée)
- la logique de contrôle d'un hook change (fail-open, ordre des gates, SCAG, mutation verbs)

## Ce qui ne va pas ici

Ne pas mettre dans ce fichier :

- inventaire des MCP
- détails d'accès serveurs
- stack du projet
- workflows détaillés
- règles de routing modèles / executors

Ces informations vivent ailleurs :

- intégrations actives : `.claude/integrations.md`
- accès / services / endpoints : `docs/codebase/services-and-access.md`
- caps / pagination / anti-patterns MCP : `.claude/rules/tool-routing.md`
- routing modèles / executors : `.claude/rules/router-rules.md`
