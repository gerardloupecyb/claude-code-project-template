# Routing des outils — prévention du context flooding

IMPORTANT : Le context window se remplit vite et les performances se dégradent.
Chaque tool call a un coût. Toujours utiliser le bon outil.

## Table de routing

| Situation | Outil correct | Anti-pattern — NE PAS faire |
|-----------|--------------|----------------------------|
| Lire un fichier connu | `Read` (offset/limit si > 500 lignes) | `Bash(cat file)` |
| Chercher des fichiers par nom | `Glob` | `Bash(find . -name ...)` |
| Chercher du contenu dans le code | `Grep` | `Bash(grep -r / rg)` sans cap |
| Commandes git courtes (add, commit, status) | `Bash` direct | — |
| `git log` / `git diff` | `Bash(git log --oneline -20)` — TOUJOURS avec flag de cap | `git log` brut = 2K-10K tokens |
| Fetch de documentation web | `WebFetch` | `Bash(curl url)` = HTML brut ~12K tokens |
| Investigation multi-fichiers | `Agent` retourne résumé 200 mots max | Lire tous les fichiers en main session |
| MCP retournant > 20 lignes | Extraire champs utiles seulement | Ré-énoncer la réponse MCP complète |
| Playwright browser_snapshot | TOUJOURS passer `filename` param | Sans filename = ~135K tokens |
| Trouver une fonction/classe | `Grep` regex par langage → résultat ciblé | `Read` du fichier entier pour chercher |
| Lire une seule fonction | `Grep` pour la ligne → `Read(offset, limit:30)` | `Read` du fichier complet |
| Impact d'un changement | `Grep` refs → `Grep` importeurs (2 degrés max) | Lire manuellement chaque fichier |
| Project knowledge query (architecture, patterns, decisions, procedures) | `chroma_query_documents` avec `where` filter + `n_results=5` | `Read` fichier complet dans le contexte |
| Sync docs vers {{RAG_BACKEND}} | `/knowledge-sync` skill | `chroma_add_documents` manuel sans chunking |

## Coûts de référence

| Anti-pattern | Coût token estimé |
|-------------|------------------|
| `browser_snapshot()` sans filename | ~135 000 tokens |
| `git log` brut sur repo mature | 2 000-10 000 tokens |
| `curl url` (retourne HTML) | ~12 500 tokens |
| `cat` fichier JSON 100KB | ~25 000 tokens |
| `list_mail_messages` sans `$top`/`$select` | 30 000-60 000 tokens |
| `{{accounting_platform}} query` sans MAXRESULTS | jusqu'à 25 000 tokens |
| CLAUDE.md > 200 lignes | Dégradation d'adhérence |

## Anti-patterns — NEVER

- Ne jamais lancer `git log`, `git diff`, `find`, `grep -r` sans flag de cap
- Ne jamais faire `Bash(curl url)` — utiliser `WebFetch`
- Ne jamais laisser un subagent retourner plus qu'un résumé de 200 mots
- Ne jamais faire `browser_snapshot()` sans `filename` param
- Réponses prose : max ~500 mots sauf demande explicite
- Plans, specs, blocs de code > 50 lignes : écrire dans un fichier, retourner le chemin
- Ne jamais `Read` un fichier entier pour trouver une fonction — `Grep` d'abord, `Read(offset, limit)` ensuite

## Discipline MCP — limit parameters par outil

| Outil | Paramètre | Valeur recommandée |
|-------|-----------|-------------------|
| `mcp__ms365__list_mail_*` | `$top` + `$select` | `$top=20&$select=subject,from,receivedDateTime` |
| `mcp__{{accounting_platform}}__query` | `MAXRESULTS` dans la requête SQL | `MAXRESULTS 25` |
| `mcp__airtable__list_records` | `maxRecords` | `20` exploration, `100` max export |
| `mcp__linear__list_issues` | `first` | `25` |
| `mcp__{{cloud_provider}}-mcp__*` | filtre par resource group | Obligatoire — jamais scope subscription entier |
| `mcp__{{WORKFLOW_ENGINE}}-mcp__{{WORKFLOW_ENGINE}}_list_workflows` | aucun natif | Déléguer à subagent résumé 10 lignes max |
| `mcp__{{WORKFLOW_ENGINE}}-mcp__{{WORKFLOW_ENGINE}}_get_workflow` | `mode` | `structure` pour inspecter params/config — `full` duplique tous les nœuds dans `activeVersion` (~2x payload) |
| `mcp__prod-{{crm_platform}}-mcp__contacts_get-contacts` | `limit` | `20` — jamais appel sans filtre |
| `mcp__google-analytics__run_report` | `limit` + date range | `limit=25`, date range 30 jours max |
| `chroma_query_documents` | `n_results` | `5` default, max `10` |
| `chroma_add_documents` | batch size | max `50` documents per call |

Si aucun paramètre de limite disponible : subagent obligatoire avec contrat de retour explicite
"retourne une table avec colonnes [X, Y, Z], max 10 lignes"

## Ajout de nouveaux MCP — mise à jour obligatoire

Après chaque `claude mcp add <name>`, mettre à jour cette table :

1. Identifier le paramètre de limite natif du nouveau MCP (`limit`, `maxResults`, `first`, `$top`, etc.)
2. Ajouter une ligne dans la table ci-dessus avec la valeur recommandée
3. Si aucun paramètre natif : documenter "subagent obligatoire" dans la table

## Hiérarchie de recherche

Pour les requêtes de connaissance : `context7 (docs librairies externes) > {{RAG_BACKEND}} (knowledge projet) > exa (patterns) > WebSearch (fallback)`

| Situation | Outil | Raison |
|-----------|-------|--------|
| Documentation lib/framework/SDK externe | `context7` | Docs à jour, token-efficient |
| Knowledge projet (architecture, décisions, patterns, procédures) | {{RAG_BACKEND}} (`chroma_query_documents`) | Ancré dans les docs projet réels |
| Patterns et exemples publics | `exa` | Recherche sémantique web |
| Fallback général | `WebSearch` | Dernier recours |

## Scope-Based Routing — {{RAG_BACKEND}} vs Grep

> Source of truth for what is indexed in {{RAG_BACKEND}}: `.claude/skills/knowledge-grounding/SKILL.md` § {{RAG_BACKEND}} Indexed Scope.
> This section is the deterministic lookup — no semantic heuristic, no classifier. Route based on file path and extension.

The {{RAG_BACKEND}} indexed scope and the Grep-native scope are **disjoint by construction**: only `.md` files under specific `watched_paths` are indexed; everything else is structurally out of reach for `chroma_query_documents` regardless of query phrasing.

> **Obsidian vault retired (Phase 27 Plan 00, 2026-04-25):** the `cross-project` collection is deprecated. The entire `Obsidian Vault/` content tree is no longer indexed. Treat any vault file as out-of-scope for {{RAG_BACKEND}}; use Read direct or Grep if you must reach legacy content.

| File type or path | Canonical source | Rationale |
|-------------------|------------------|-----------|
| `.claude/rules/*.md`, `.claude/skills/**/SKILL.md`, `.claude/commands/*.md` | {{RAG_BACKEND}} `reference` | Governance & skill docs — semantic search accelerates pattern lookup |
| `AGENTS.md`, `docs/architecture/**/*.md`, `docs/references/**/*.md`, `docs/specs/**/*.md` | {{RAG_BACKEND}} `reference` | Project architecture refs — primary grounding source |
| `docs/references/frameworks/cwe-top-25-2025.md` | {{RAG_BACKEND}} `reference` | Curated CWE ranked list — consumed by {{project}}-review threat-intel-analyst + pre-flight security-sentinel |
| `docs/references/{{scripting_lang}}-dangerous-functions.md` | {{RAG_BACKEND}} `reference` | Curated PS primitives catalog — consumed by {{project}}-{{scripting_lang}}-script-writer + {{project}}-review |
| `docs/references/security-review/*.md` | {{RAG_BACKEND}} `reference` | Reviewer configuration (scoring-rubric, FP suppression) — consumed by all security reviewer personas |
| `LESSONS.md`, `DECISIONS.md`, `docs/solutions/**/*.md` | {{RAG_BACKEND}} `knowledge` | Past decisions & patterns — cross-session memory |
| `.planning/phases/**/*SUMMARY*.md`, `*CONTEXT*.md`, `*RESEARCH*.md`, `*VERIFICATION*.md` | {{RAG_BACKEND}} `knowledge` | Phase outcomes — indexed via recursive glob across `active/`, `planned/`, `complete/` |
| `.planning/phases/active/**/*.md`, `memory/MEMORY.md`, `docs/brainstorms/*.md`, `docs/plans/*.md` | {{RAG_BACKEND}} `planning` | Live session state & active phase context |
| `docs/standards/*.md`, `docs/procedures/*.md`, `docs/runbooks/*.md`, `docs/audits/**/*.md` | {{RAG_BACKEND}} `governance-ops` | Ops & compliance docs |
| **`scripts/runbooks/*.ps1`, `scripts/*.sh`, `scripts/*.py`** | **Grep `scripts/`** | Non-`.md` extension — structurally out of {{RAG_BACKEND}} scope (loader filters `.md` only) |
| **`scripts/security-fixtures/**/*`** | **Grep `scripts/security-fixtures/`** | Synthetic vulnerable fixtures — non-`.md` language files, Grep-only |
| **`config/security/*.json`** | **Grep `config/security/`** | JSON config — non-`.md` extension, not indexed in {{RAG_BACKEND}} |
| **`.claude/allowlists/slopsquatting-exceptions.json`** | **Grep `.claude/allowlists/`** | JSON allowlist — non-`.md`, Grep-only per {{PROJECT}} routing convention |
| **`.claude/skills/supply-chain-audit/patterns/helpers/*.py`** | **Grep `.claude/skills/`** | Helper scripts — non-`.md`, Grep-only |
| **`config/*.json`, `.mcp.json`, `.claude/settings*.json`** | **Grep `config/` or Read direct** | JSON configs — never indexed |
| **`.github/workflows/*.yml`, `.github/dependabot.yml`** | **Grep `.github/`** | YAML configs — never indexed |
| **`README.md`, `CLAUDE.md`** | **Read direct** | Root-level docs — NOT in any `watched_paths` array (AGENTS.md IS indexed, these are not) |
| **`infra/**/*.bicep`, `docker-compose*.yml`** | **Grep `infra/` or `./`** | Infrastructure-as-code — non-`.md` |
| **`{{WORKFLOW_ENGINE}}/workflows/*.json`** | **Grep `{{WORKFLOW_ENGINE}}/workflows/`** | {{WORKFLOW_ENGINE}} workflow JSON — non-`.md` |
| **`~/.claude/projects/*/memory/*.md`** | **Grep `~/.claude/projects/`** | Auto-memory — outside repo tree |
| **`docs/codebase/*.md`** | **Read direct or Grep `docs/codebase/`** | Explicitly excluded by `excluded_paths` (L1-L3 human coding refs) |
| **Obsidian vault content (retired)** | **Deprecated — no longer indexed; see Phase 27 Plan 00** | `cross-project` collection deprecated 2026-04-25; vault dir removal pending operator confirmation (`docs/ideation/2026-04-25-obsidian-vault-removal.md`) |
| **`.planning/phases/{planned,complete}/**/*PLAN*.md`** | **Grep `.planning/phases/`** | PLAN files not matched by any glob (only SUMMARY/CONTEXT/RESEARCH/VERIFICATION are) |
| **`.planning/todos/**/*.md`** | **Grep `.planning/todos/`** | Not in any `watched_paths` |

**Rule :** if a query targets a file in the top half of the table → `chroma_query_documents` with the named collection. If the query targets a file in the **bold bottom half** → Grep (or Read direct for single-file lookups). Never attempt {{RAG_BACKEND}} on the bottom half — it will silently return zero hits and create a false sense of "I checked the knowledge base."
