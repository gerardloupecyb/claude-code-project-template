---
title: "FORGE — Operating Model"
status: active
last_verified: 2026-04-08
owner: {{OWNER}}
phase: 24
slug: forge
---

# FORGE — Operating Model

## 1. Cycle de vie de session

Chaque session Claude Code suit un cycle en trois phases : démarrage, travail, clôture.

### Démarrage

Le hook `session-start.sh` se déclenche automatiquement à l'ouverture de session (trigger : `startup` ou `compact`). Séquence :

1. **Réinitialisation du log agent** — `.claude/workspace/agent-log.txt` est vidé (used par session-gate pour le Check 19).
2. **{{RAG_BACKEND}} health-check et auto-start** — Si Docker est disponible, le script tente un heartbeat sur `localhost:8000/api/v2/heartbeat`. Code 200 = OK. Code non-200 = `docker compose -f docker-compose.{{rag_backend}}.yml up -d` avec 5 retries à 500 ms. Échec = warning, session continue sans grounding.
3. **Staleness check** — Si {{RAG_BACKEND}} est actif, le registry `config/{{rag_backend}}-registry.json` est lu. Collections non synchronisées depuis plus de 24 h → alerte "Run /knowledge-sync".
4. **Auto incremental sync (source=startup uniquement)** — `scripts/knowledge-sync.py` est lancé via l'env Python de chroma-mcp (`~/.local/share/uv/tools/chroma-mcp/bin/python`). Sync incrémental basé sur MD5, 20 s soft cap, lock `/tmp/{{project}}-knowledge-sync.lock` partagé avec `post-commit`. Silencieux si rien n'a changé ; sinon émet `{{RAG_BACKEND}} auto-sync: collection:+N`. Le log stderr va à `.claude/workspace/knowledge-sync.log`. Saut sur `source=compact` pour garder le resume rapide.
5. **Upstream drift auto-resolve (source=startup uniquement)** — `scripts/upstream-watch/auto-resolve.sh` tourne en background avec soft cap 30 s. Pour chaque source driftée, le script auto-sync uniquement les cas `regenerate_file` dont le host est allowlisté dans `.claude/allowlists/upstream-sources.json` et dont le diff total reste sous `max_auto_diff_lines`. Les erreurs restent sur `stderr`, les résumés vont sur `stdout` et deviennent `additionalContext`. Aucun commit n'est créé.
6. **Injection mémoire** — `memory/MEMORY.md` est injecté en tant que résumé compact dans le contexte (`additionalContext`). Champs extraits : statut, dernière session, phase actuelle, prochaines étapes, travaux récents, blocages ouverts.
7. **CARL rules** — Les règles comportementales domaine-spécifiques sont injectées depuis `.carl/{{project}}tech`.
8. **Session-gate** — Le skill `session-gate` valide l'environnement (marqueurs requis, outils présents, cohérence de l'état).

Après le démarrage, l'agent lit dans cet ordre : `CLAUDE.md` (bootstrap), `AGENTS.md` (routing canonique), puis les fichiers requis pour la tâche courante.

### Injection des rules — path-scoped tiering

Claude Code auto-charge tous les fichiers `.claude/rules/*.md` au démarrage de session, au même niveau de priorité que `.claude/CLAUDE.md` — mécanisme natif documenté à [code.claude.com/docs/en/memory](https://code.claude.com/docs/en/memory#path-specific-rules). Les rules sont injectées en contenu complet dans le context window.

**Tiering par frontmatter `paths:`** (depuis 2026-04-11, commit `8ad66e3`) — les rules dont la portée est limitée à un type de fichier peuvent être scopées via YAML frontmatter :

```yaml
---
paths:
  - ".mcp.json"
  - ".claude/integrations.md"
---
```

Une rule scopée ne se charge que quand Claude ouvre un fichier matching un des patterns. Les rules sans `paths:` restent auto-injectées de manière inconditionnelle (tier-0).

**Tiers actuels :**

| Tier | Chargement | Rules |
| --- | --- | --- |
| tier-0 (inconditionnel) | Chaque session | `verification-discipline`, `tool-routing`, `cognitive-patterns`, `skill-gate`, `workflow-guide` |
| tier-1 (path-scoped) | Sur ouverture d'un fichier matching | `governance` → MCP/integrations/skills, `phase-lifecycle` → `.planning/phases/**`, `supply-chain-audit` → package manifests, `dependency-surveillance` → CVE artefacts, `router-rules` → task briefs/handoffs, `swarm-patterns` → orchestration multi-agent, `todo-discipline` → `.planning/todos/**` |

**Objectif** : réduire le context baseline de ~5k tokens par session sur la première passe, puis encore d'environ 1.5k-2k tokens en sortant `router-rules`, `swarm-patterns` et `todo-discipline` du baseline. Les rules tier-1 ne sont pertinentes que pour certains types de travail et se chargent juste à temps quand Claude lit le fichier concerné.

**Hard gates inchangés** — les hooks `pre-tool-use.sh` et `pre-mcp-gate.sh` enforcent indépendamment les skill gates des domaines protégés ({{cloud_provider}}, {{WORKFLOW_ENGINE}}, {{crm_platform}}), indépendamment du contenu rules chargé. Le tiering n'affecte que les reminders soft.

**Pointeurs tier-0** — `.claude/rules/skill-gate.md` contient une section "Path-scoped rules — déclencheurs soft" qui liste les triggers et rules correspondantes. Claude sait que ces rules existent et peut les lire proactivement si un trigger s'applique avant d'avoir ouvert un fichier matching.

**Rollback** — supprimer le bloc frontmatter `paths:` d'un rule file restaure le chargement inconditionnel. Aucun hook à modifier. Rollback complet : `git revert 8ad66e3`.

**Vérification post-déploiement** — todo `.planning/todos/pending/074-pending-p3-verify-rules-tiering-gain.md` liste les checks à faire à la prochaine session fresh : observer l'injection, mesurer le delta tokens, tester un trigger path-scoped.

### Travail

Durant la session, le comportement dépend du contexte actif :

| Contexte | Comportement |
|----------|-------------|
| Phase GSD active ou requête numérotée explicite | Suivre `workflow-architecture.md` §3 — flow structuré (discuss → plan → checker → pre-flight → execute → closure) |
| Pas de phase GSD active | Suivre `workflow-architecture.md` §1 "Path Selection Outside GSD" |
| Domaine protégé ({{CLOUD_PROVIDER}} / {{WORKFLOW_ENGINE}} / {{CRM_PLATFORM}}) | Skill-gate obligatoire — créer marker `.skill-locks/{domain}` avant toute écriture |
| Installation de dépendance externe | SCAG gate obligatoire — `/supply-chain-audit` avant `pip install / npm install / claude mcp add` ; token `.skill-locks/scag-approved` requis par `pre-tool-use.sh` |
| Claim sur architecture ou décisions passées | Grounding {{RAG_BACKEND}} requis (collection `reference` ou `knowledge`) |

Le hook `pre-tool-use.sh` bloque toute écriture sur des fichiers de domaine protégé si le marker est absent, et bloque tout verbe install (pip/uv/npm/yarn/pnpm/bun/claude-mcp-add) si le token `scag-approved` est absent. Le hook `pre-mcp-gate.sh` bloque toute mutation prod MCP ({{WORKFLOW_ENGINE}}-mcp, prod-{{crm_platform}}-mcp, prod-{{crm_platform}}-care-mcp) sans marker.

### Clôture

La clôture est obligatoire après chaque exécution de phase ou tâche significative. Voir Section 2 pour le protocole complet en 8 étapes.

---

## 2. Protocole de clôture

Les 8 étapes, dans l'ordre :

1. **Écrire le SUMMARY.md** — `.planning/phases/{phase-name}/*-SUMMARY.md` documentant les tâches complètes, les décisions prises, et les déviations.
2. **Mettre à jour MEMORY.md** — Ajouter l'entrée de session dans "Ce qui a été fait". Si la section dépasse 8 sessions : archiver le surplus dans `memory/archive-YYYY-MM.md`.
3. **Logger les déviations** — Si des déviations non triviales ont eu lieu (bug auto-fixé, déviation d'architecture), les consigner dans MEMORY.md sous la session courante.
4. **Capturer une leçon** — Si un fix non trivial ou un nouveau pattern a été découvert : invoquer `/lesson` pour ajouter une entrée dans `LESSONS.md` (cap 50 entrées).
5. **Exécuter les tests disponibles** — Corriger les échecs avant de revendiquer la complétion. Appliquer la verification discipline : pas de "should work" sans preuve d'exécution.
6. **Lancer `/gsd:verify-work`** — Vérification formelle à l'intérieur des phases GSD. Produit `.planning/{phase}-VERIFICATION.md`.
7. **Indexer si archivage** — Si MEMORY.md a été archivé à l'étape 2 : lancer `./scripts/index-memory-to-agentdb.sh` pour maintenir l'index AgentDB.
8. **Proposer `/commit-push`** — Formuler "Commit et push ?" et exécuter seulement si l'utilisateur confirme. Ne pas exécuter automatiquement.

---

## 3. Hygiène mémoire

### Fichiers d'état et leurs caps

| Fichier | Rôle | Cap | Action au dépassement |
|---------|------|-----|----------------------|
| `memory/MEMORY.md` | Journal de session — ce qui a été fait, prochaines étapes, blocages | 8 sessions dans "Ce qui a été fait" | Archiver le surplus dans `memory/archive-YYYY-MM.md` à la clôture |
| `LESSONS.md` | Cache de leçons — patterns découverts, erreurs évitées | 50 entrées | Archiver les leçons les plus anciennes ou les moins applicables |
| `DECISIONS.md` | Décisions architecturales actives | ~25 décisions | Archiver les décisions remplacées ou obsolètes |
| `.planning/STATE.md` | Position GSD (phase courante, plan, progression) | Auto-géré | Mis à jour par `gsd-tools.cjs` — ne pas éditer manuellement |

### Quand lire chaque fichier

- **MEMORY.md** — toujours lu au démarrage (injecté par session-start.sh)
- **LESSONS.md** — lire avant : implémentation, review, debug, fix, refactor, modification de workflow, changement auth/infra/sécurité
- **DECISIONS.md** — lire avant toute décision architecturale pour éviter de contredire une décision active
- **STATE.md** — lu par les outils GSD ; lire manuellement en début de phase pour connaître la position

### Hiérarchie mémoire 6 couches

MEMORY.md, LESSONS.md et DECISIONS.md couvrent les 3 premières couches (cache chaud, leçons, décisions). Les 3 couches suivantes — AgentDB (index sémantique VPS), {{RAG_BACKEND}} (RAG local), Supermemory (cross-projet) — constituent l'infrastructure de mémoire longue durée. Voir le doc de solution `docs/solutions/agents/memory-layer-hierarchy.md` pour la table complète avec scope, caps et guidance d'utilisation.

---

## 4. Template-Sync

Le projet {{PROJECT}} est instancié depuis le template `project-template-collab`. Des mises à jour du template peuvent apporter des améliorations aux hooks, rules, skills et templates GSD.

### Ce qui se synchronise

| Composant | Outil de sync | Déclencheur |
|-----------|--------------|-------------|
| `.claude/rules/*.md` | `template-sync` skill | Manuellement ou lors d'une mise à jour GSD |
| `.claude/hooks/` | `template-sync` skill | Manuellement ou lors d'une mise à jour GSD |
| `.claude/skills/` (skills communs) | `template-sync` skill | Manuellement |
| Templates GSD (`$HOME/.claude/get-shit-done/`) | Mise à jour GSD distincte | Via le système GSD lui-même |

### Ce qui ne se synchronise PAS

- `docs/` (architecture, solutions, codebase) — spécifique à {{PROJECT}}
- `memory/` — journal de session, non partageable
- `DECISIONS.md`, `LESSONS.md` — spécifiques au projet
- `.carl/{{project}}tech` — rules CARL propres à {{PROJECT}}
- `.planning/` — état GSD spécifique au projet

La synchronisation s'effectue via `/skill-refresh` (mise à jour d'un skill spécifique) ou via le skill `template-sync` selon la portée (`project-template-sync` retiré — D-6 / Phase 22, modèle allowlist absorbé par `template-sync`).

---

## 5. Maintenance

### Activités récurrentes

| Activité | Fréquence | Commande / Mécanisme |
|----------|-----------|---------------------|
| Staleness {{RAG_BACKEND}} | Automatique — chaque démarrage | `session-start.sh` lit `{{rag_backend}}-registry.json` |
| Auto sync session startup | Automatique — chaque démarrage (source=startup uniquement) | `session-start.sh` lance `scripts/knowledge-sync.py` incrémental |
| Auto sync post-commit | Automatique — chaque `git commit` (détaché background) | `.githooks/post-commit` lance `scripts/knowledge-sync.py` incrémental |
| Synchronisation manuelle | Ad hoc — recovery (`--full`), collection spécifique (`--collection`), ou sessions sans hooks | `/knowledge-sync` skill |
| Rafraîchissement skill | À la demande ou sur alerte {{WORKFLOW_ENGINE}} release monitor | `/skill-refresh` |
| Audit références | Ad hoc — quand des liens brisés sont suspectés | `/reference-audit` |
| Audit architecture | Tous les 180 jours | `/architecture-kit --check` — détecte les artefacts `last_verified` > 180 jours |
| Rétrospective engineering | Fin de milestone ou hebdomadaire | `/retro` → output dans `docs/retros/YYYY-MM-DD.md` |
| Graphify graph rebuild (code) | Automatique — chaque `git commit` + watch continu | `.githooks/post-commit` graphify block + `graphify.watch` background |
| Graphify graph rebuild (docs) | Manuel — quand `graphify-out/needs_update` est flaggé | `/graphify . --update` |

### Auto-sync et nudge PostToolUse

**Auto-sync déterministe (D-B11b, 2026-04-10) :** Deux checkpoints lancent automatiquement `scripts/knowledge-sync.py` :

1. **Session startup** — `session-start.sh` après le healthcheck {{RAG_BACKEND}} (source=startup uniquement, pas compact). Soft cap 20 s, silencieux si rien à sync.
2. **Post-commit** — `.githooks/post-commit` détaché background après chaque `git commit`. Retourne en <10 ms, sync async.

Les deux partagent le lock `/tmp/{{project}}-knowledge-sync.lock` (stale > 60 s = effacé). Log consolidé dans `.claude/workspace/knowledge-sync.log`.

**Nudge PostToolUse (D-B21) :** Le hook `.claude/hooks/post-knowledge-sync.sh` reste un best-effort — il maintient une queue `.claude/.sync-queue` et émet un nudge consolidé "Run /knowledge-sync" quand 10 s d'idle sont détectées entre éditions. **Il ne fait PAS de mutation {{RAG_BACKEND}}**, c'est un rappel pour les sessions longues avec des modifs non commitées.

**Synchronisation manuelle `/knowledge-sync`** : utilisée pour recovery (`--full` wipe-and-rebuild), collection spécifique (`--collection`), ou sessions où les hooks sont indisponibles (fresh clone sans `setup-hooks.sh`, {{RAG_BACKEND}} down, Python env de chroma-mcp absent).

### Cohérence des fichiers canoniques

Tout changement sur un serveur MCP, une intégration externe, ou un point d'accès doit mettre à jour les fichiers canoniques dans le même commit :
- `.claude/integrations.md` — inventaire des intégrations actives
- `docs/codebase/services-and-access.md` — accès et exploitation
- `.claude/rules/tool-routing.md` — si les caps MCP changent

---

*Phase: 24-forge-architecture-documentation*
*Generated: 2026-04-08*
