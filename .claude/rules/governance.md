---
paths:
  - ".mcp.json"
  - ".claude/settings.json"
  - ".claude/settings.local.json"
  - ".claude/integrations.md"
  - ".claude/skills/**/SKILL.md"
  - "docs/codebase/services-and-access.md"
  - ".claude/rules/tool-routing.md"
---

# Gouvernance Intégrations, Services Et Skills

> Source canonique des règles de gouvernance.
> Path-scoped : ne se charge que quand Claude touche un fichier d'intégration, MCP, skill ou services.
> AGENTS.md pointe ici — ne pas dupliquer le contenu.

## Fichiers canoniques

- `CLAUDE.md` = bootstrap court (max 50 lignes, enforced par pre-commit); ne jamais y lister les MCP, skills, serveurs ou détails d'accès
- `.claude/integrations.md` = inventaire canonique des intégrations actives du projet
- `docs/codebase/services-and-access.md` = source canonique des détails d'accès et d'exploitation
- Le choix du MCP pour une tâche donnée appartient au `SKILL.md` du domaine concerné
- `.claude/rules/tool-routing.md` = caps, pagination, filtres obligatoires et anti-patterns MCP
- `memory/agents-feedback.md` = log canonique des feedbacks sur le comportement des agents (Codex CLI, Gemini CLI, subagents intra-Anthropic, teams multi-agents). À lire AVANT tout task-brief ou spawn de subagent. À mettre à jour APRÈS chaque handoff où une déviation est observée.

## Séparation des responsabilités

- `integrations.md` dit **quoi existe**
- `services-and-access.md` dit **où et comment y accéder**
- `SKILL.md` dit **quel MCP utiliser**
- `tool-routing.md` dit **comment l'utiliser proprement**

## Mise à jour obligatoire dans le même commit

Tout changement sur un serveur, un MCP, une intégration externe ou un point d'accès doit mettre à jour les fichiers canoniques dans le même commit.

- **Nouveau serveur / serveur retiré / renommé**
  - mettre à jour `.claude/integrations.md`
  - mettre à jour `docs/codebase/services-and-access.md`

- **Nouveau MCP / MCP retiré / renommé**
  - mettre à jour `.claude/integrations.md`
  - mettre à jour `.claude/rules/tool-routing.md` si caps, filtres, pagination ou anti-patterns changent
  - mettre à jour le `SKILL.md` du domaine si le MCP préféré, le fallback ou l'ordre de sélection change

- **Nouveaux endpoints, URLs, hostnames, IPs, ports, accès SSH, services systemd, chemins, emplacements de secrets**
  - mettre à jour `docs/codebase/services-and-access.md`

- **Nouveau skill / skill retiré / skill renommé / skill modifié (workflow, triggers, MCP deps)**
  - mettre à jour `docs/solutions/agents/skills-inventory.md` (inventaire détaillé)
  - mettre à jour `docs/architecture/forge/component-registry.md` (registre FORGE)
  - mettre à jour `docs/solutions/agents/skill-lifecycle.md` si le nombre de groupes ou le cycle de vie change
  - si skill domain-architect : mettre à jour `.claude/rules/skill-gate.md`
  - si skill domaine couvert par un standard `docs/standards/{domain}-*.md` : vérifier qu'une section pointeur (`## Production Hardening Standard` ou équivalent) référence le standard ; l'ajouter sinon

- **Nouveau standard / standard modifié** (`docs/standards/*.md`)
  - mettre à jour `docs/GOVERNANCE.md` § Standards dans le même commit (cf. `governance-index-discipline.md`)
  - **auditer `LESSONS.md` + `docs/solutions/{domain}/*.md`** pour les entrées du domaine non encore codifiées dans le standard ; les incorporer ou justifier l'omission dans le commit message. Sans cet audit, le standard rate les leçons déjà payées par le projet.
  - **identifier les skills du domaine** (`.claude/skills/{domain}*-*/SKILL.md`) et y ajouter un pointeur cross-référence (section `## Production Hardening Standard` ou équivalent) dans le même commit. Sans ce cross-link, le standard existe mais est invisible au moment où on en a besoin — symétrique du pattern « close-phase n'appelait pas architecture-kit ».
  - si le standard touche des patterns de code spécifiques : ajouter aussi un pointeur dans `docs/codebase/coding-patterns.md` (ou autre L2 référencé)

- **Nouveau hook / hook retiré / hook modifié (trigger, bloquant, rôle)**
  - mettre à jour `docs/architecture/forge/component-registry.md` (registre FORGE)
  - mettre à jour `docs/architecture/forge/security-architecture.md` (hooks detail table)
  - mettre à jour `.claude/rules/governance.md` enforcement table (ce fichier)

- **Nouveau composant infra / composant retiré / upgrade appliqué / patch CVE appliqué**
  - mettre à jour `config/infra-components.json` (version, upgrade_command, risk)
  - mettre à jour `docs/codebase/infra-inventory.md` (sections 1-2 + patch history section 5 + backlog section 6)
  - si l'upgrade affecte un skill : lancer `/skill-refresh {platform}` et documenter dans le commit
  - si risque MEDIUM+ : documenter l'analyse de risque (output de `analyze-upgrade-risk.sh`) dans le commit message

- **Nouveau pattern d'auth / modification du decision tree** (nouveau flow MI/SP/OAuth2, nouvelle convention de credential, nouveau scope GDAP)
  - mettre à jour `docs/codebase/auth-models-and-decision-tree.md`
  - si un nouveau secret/credential KV est introduit : mettre à jour `docs/codebase/services-and-access.md` § Key Vault
  - si le pattern impacte la sécurité L1 transverse : mettre à jour `docs/codebase/architecture-security.md`

- **Nouveau pattern de code récurrent** ({{SCRIPTING_LANG}} template, {{WORKFLOW_ENGINE}} expression, retry, batch, error handling, etc.)
  - mettre à jour `docs/codebase/coding-patterns.md` section appropriée (L2)
  - si le pattern relève d'un standard existant : ajouter un pointeur depuis ce standard
  - si transverse multi-domaine : envisager `docs/standards/` (nouveau standard → déclenche le bullet ci-dessous)

- **Mutation dans `docs/references/`** (catalogues domaine, frameworks externes, plateformes, vendor, security-review, schémas)
  - catalogue domaine (Lago plan, Stripe produit, QBO GL, Lago env) → mettre à jour le fichier de catalogue concerné dans `docs/references/` (`lago-billing-catalog.md`, `stripe-product-catalog.md`, `qbo-gl-mapping.md`, `lago-env-vars.md`)
  - amendement légal ou nouvelle version framework ({{COMPLIANCE_FRAMEWORK_PRIMARY}}, {{COMPLIANCE_FRAMEWORK_FEDERAL}}, {{COMPLIANCE_FRAMEWORK_HEALTH}}, CWE, ISO, NIST, AIDA, EU AI Act) → `docs/references/frameworks/{file}.md` + `frameworks-crosswalk.md` si la matrice change
  - capacité plateforme nouvelle / dépréciée / pattern de prod confirmé ({{cloud_provider}}-{{identity_platform}}, {{crm_platform}}, {{WORKFLOW_ENGINE}}) → `docs/references/platforms/{platform}.md`
  - rubrique reviewer tunée ou nouveau pattern FP capturé → `docs/references/security-review/{file}.md`
  - nouveau {{SCRIPTING_LANG}} primitive dangereux découvert (security-sentinel, audit ad-hoc) → `docs/references/{{scripting_lang}}-dangerous-functions.md`
  - changement SKU / prix / contrat vendeur → `docs/references/vendor-licensing/{vendor}.md` + `INDEX.md` si nouveau vendor
  - évolution schéma client → `docs/references/client-data-dictionary.md`
  - modification MSA / SOW template → `docs/references/msa-sow-clause-registry.md`
  - **registration mandatory** — tout nouveau fichier canonique ajouté à `docs/references/` doit être enregistré dans `docs/references/source-of-truth-map.md` dans le MÊME commit (sans ça, le fichier devient orphelin invisible aux rules). Si une nouvelle catégorie émerge, ajouter aussi un bullet ici.

- **Incident résolu / pattern de fix découvert** (non-trivial — bug structurel, edge case durci, anti-pattern identifié)
  - capturer via `/lesson` dans `LESSONS.md` (cap 50 — rotation vers `docs/solutions/{domain}/lessons-migrated.md` quand cap atteint)
  - si la leçon est transverse code : également updater `docs/codebase/coding-patterns.md`
  - si la leçon est domaine-spécifique avec standard existant : updater le standard (cf. bullet « Nouveau standard / standard modifié »)

- **Handoff cross-vendor (Codex / Gemini) ou spawn de subagent/team avec déviation observée**
  - lire `memory/agents-feedback.md` § {transport ou agent type} AVANT d'écrire le task-brief ou de spawner le subagent (appliquer les mitigations connues upfront)
  - si la déviation est nouvelle (false positive, scope creep, AC ambiguïté, output format surprise, context loss) : ajouter une entrée à `memory/agents-feedback.md` en utilisant le template en bas du fichier
  - si le protocole de handoff lui-même change (`.claude/rules/router-rules.md` ou `.claude/rules/swarm-patterns.md`) : co-update `memory/agents-feedback.md` dans le même commit pour que les références restent cohérentes

- **Ideation → brainstorm → phase transitions (upstream-of-GSD lifecycle)**
  - transition ideation → brainstorm : `git mv docs/ideation/{file}.md docs/ideation/brainstormed/`, set `status: brainstormed` + `promoted_to:`, créer le brainstorm avec `origin:` backlink
  - transition brainstorm → phase : `git mv docs/brainstorms/{file}.md docs/brainstorms/linked/`, set `status: linked` + `linked_phase:`, référencer le brainstorm dans le CONTEXT.md de la phase (`origin:`)
  - archival post-phase : `git mv docs/brainstorms/linked/{file}.md docs/brainstorms/archived/`, set `status: archived` + `archived_on:`
  - rejection : `git mv docs/brainstorms/{file}.md docs/brainstorms/rejected/`, set `status: rejected` + `rejected_reason:`
  - idéation stale (> 30 jours, jamais promue) : `git mv docs/ideation/{file}.md docs/ideation/archived/`, set `status: archived` + `archived_on:`
  - toujours `git mv`, jamais copy+delete — source canonique des transitions : `.claude/rules/workflow-guide.md` § Upstream of GSD

## Check de clôture avant commit

Avant tout commit touchant infra, MCP, Docker, VPS, SSH, Key Vault, {{WORKFLOW_ENGINE}}, {{CRM_PLATFORM}} ou outils externes, vérifier explicitement :

- `.claude/integrations.md` à jour si l'inventaire a changé
- `docs/codebase/services-and-access.md` à jour si l'accès ou l'exploitation a changé
- `.claude/rules/tool-routing.md` à jour si les caps ou patterns MCP ont changé
- le `SKILL.md` du domaine à jour si le choix du MCP a changé

## Convention d'artefacts skill

Un dossier de skill (`.claude/skills/{name}/`) ne contient que `SKILL.md`.

Les artefacts produits par un skill (configs, logs, rapports, données) vont dans les répertoires canoniques du projet :

| Type d'artefact | Répertoire canonique |
|-----------------|---------------------|
| Configuration versionnée | `config/` |
| Logs opérationnels append-only | `logs/` |
| Rapports markdown générés | `docs/reports/` |
| Données de session éphémères | `.planning/` |

Ne jamais créer de fichiers de données, logs, ou configs à l'intérieur de `.claude/skills/{name}/`.

## Gouvernance des skills et MCP

Tout `SKILL.md` orienté domaine qui recommande, choisit ou implique un MCP doit inclure une section `## MCP Routing` décrivant :

- le MCP préféré
- les fallbacks
- les règles de sélection
- les contraintes de scope
- la référence à `.claude/rules/tool-routing.md`

Les skills purement méthodologiques, mémoire, review ou orchestration sans dépendance MCP sont exemptés.

## Enforcement

| Règle | Mécanisme | Niveau |
|-------|-----------|--------|
| Skill gate sur Write/Edit/MultiEdit/Bash | `pre-tool-use.sh` via settings.json PreToolUse | Hard — bloque l'outil |
| MCP prod mutations ({{WORKFLOW_ENGINE}}-mcp, prod-{{crm_platform}}-mcp, prod-{{crm_platform}}-care-mcp) | `pre-mcp-gate.sh` via settings.json PreToolUse | Hard — bloque les mutations |
| ConfigChange — audit + block risky settings.json mutations | `config-change-audit.sh` via settings.json ConfigChange (`project_settings\|local_settings`) | Hard — bloque wildcard allow, curl/wget/sudo, suppression de deny critiques ou de hooks obligatoires |
| SCAG — audit supply chain avant install dep externe | `/supply-chain-audit` skill + `.claude/rules/supply-chain-audit.md` | Hard — bloque l'install |
| SCAG install gate — hook pre-tool-use sur verbes install | `pre-tool-use.sh` SCAG block + token `.skill-locks/scag-approved` | Hard — bloque Bash install |
| DSW — surveillance CVE continue | Dependabot + OSV-Scanner cron + `.claude/rules/dependency-surveillance.md` | Hard — PR auto + alerting |
| Patch SLA par sévérité | `docs/standards/patch-management-standard.md` | Hard — Critical 24h, High 7j |
| Slopsquatting exceptions allowlist (`.claude/allowlists/slopsquatting-exceptions.json`) | PR review — entry additions require `rationale:` + `added:` fields + 2 FP incidents OR 1 DEC per Phase 24.7 D-02 | Guidance — enforced at `/supply-chain-audit` + human review |
| Security config seeds (`config/security/*.json` — cwe-cve-seed, slopsquatting-seed) | PR review — entry/schema changes follow the `_notes` procedure embedded in each seed; quarterly review cadence per Phase 24.7 D-03 | Guidance — enforced at `/supply-chain-audit` + human review |
| MCP allowlist bypass SCAG | `.claude/allowlists/mcp-preapproved.json` | Exemption — documentée |
| Upstream source auto-resolve trust policy | `.claude/allowlists/upstream-sources.json` + `scripts/upstream-watch/auto-resolve.sh` | Automatique — non bloquant |
| Agents feedback loop (Codex / Gemini / subagents / teams) | `memory/agents-feedback.md` + référencé dans `.claude/rules/router-rules.md` § Handoff + `.claude/rules/swarm-patterns.md` § Anti-drift | Guidance — lire avant brief/spawn, update après déviation |
| CLAUDE.md < 50 lignes | `.githooks/pre-commit` | Hard — bloque le commit |
| MCP co-présence integrations.md | `.githooks/pre-commit` | Soft — warning |
| Infra co-présence services-and-access.md | `.githooks/pre-commit` | Soft — warning |
| Nouveau SKILL.md sans MCP Routing | `.githooks/pre-commit` | Soft — warning |
| {{RAG_BACKEND}} auto-sync post-commit | `.githooks/post-commit` (detached background, `scripts/knowledge-sync.py`) | Automatique — non bloquant |
| Codex-done verification checklist | `codex-done-checklist.sh` via settings.json UserPromptSubmit | Guidance — injecte la checklist `verification-discipline.md` § "Codex done" quand le prompt matche `codex done` (non bloquant) |
| KV-secret RULE_8 nudge | `kv-secret-rule8-nudge.sh` via settings.json PostToolUse (Bash) | Guidance — détecte `az keyvault secret set/delete` (CLI = pas de git footprint) et rappelle {{PROJECT}}TECH_RULE_8 (update services-and-access.md same-commit). Non bloquant, fail-safe exit 0 |
| Séparation des responsabilités | Ce fichier (auto-injecté) | Guidance |
| CARL rules | `.carl/{{project}}tech` (injecté par contexte) | Guidance |
| Plan-phase association (`docs/plans/` → `phase:` frontmatter) | `.claude/rules/phase-lifecycle.md` § "Plan-Phase Association" + `docs/plans/INDEX.md` | Guidance — enforced at `/gsd:discuss-phase` |
| Plan archival (phase complete → `docs/plans/archive/`) | `.claude/rules/phase-lifecycle.md` § "Plan-Phase Association" rule 3 | Guidance — enforced at phase closure |
| Todo-phase association (`.planning/todos/` → `phase:` frontmatter) | `.claude/rules/todo-discipline.md` § "Todo-phase association" | Guidance — enforced at `/todo create` + `/todo validate` |
| Todo staleness lifecycle (pending on completed phase → triage) | `.claude/rules/todo-discipline.md` § "Staleness lifecycle" + `workflow-guide.md` § Closure step 4b | Guidance — enforced at phase closure + `/todo stale` |
| Upstream-of-GSD lifecycle (ideation/brainstorm → phase transitions) | `.claude/rules/workflow-guide.md` § Upstream of GSD + `.claude/rules/phase-lifecycle.md` § Brainstorm-Phase Association | Guidance — enforced at brainstorm creation, phase add, phase closure |

> Note : `pre-tool-use.sh` filtre Write, Edit, MultiEdit et Bash. `pre-mcp-gate.sh` filtre les mutations MCP prod ({{WORKFLOW_ENGINE}}-mcp, prod-{{crm_platform}}-mcp, prod-{{crm_platform}}-care-mcp). Les MCP dev et les lectures prod ne sont pas bloqués.

> Setup des hooks git (après clone ou nouvelle machine) : `bash scripts/setup-hooks.sh` — configure `core.hooksPath=.githooks` (per-repo config, non cloné) et vérifie que pre-commit + post-commit sont exécutables.

## Classification des documents

Les règles de classification des documents (quel type va dans quel dossier `docs/`) sont définies dans `docs/references/source-of-truth-map.md` § "Document Classification Rules". C'est la source canonique — ne pas dupliquer ici.
