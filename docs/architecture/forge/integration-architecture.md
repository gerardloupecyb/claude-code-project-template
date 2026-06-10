---
title: "FORGE — Integration Architecture"
status: active
last_verified: 2026-04-08
owner: {{OWNER}}
phase: 24
slug: forge
---

# FORGE — Integration Architecture

## 1. Topologie MCP

FORGE s'integre avec 15 MCP servers actifs, regroupes en 6 domaines fonctionnels (13 dans `.claude/integrations.md` + chroma-mcp + context7 dans le domaine Knowledge). Claude Code est l'orchestrateur c{{identity_provider}}l — les MCP servers sont les executors specialises.

### Microsoft

| Serveur MCP | Objet | Scope | Limites |
|-------------|-------|-------|---------|
| `ms365` | {{IDENTITY_PLATFORM}} — mail, calendar, users, SharePoint | Lecture + ecriture (sous governance) | `$top=20`, `$select` obligatoire |
| `{{cloud_provider}}-mcp` | {{CLOUD_PROVIDER}} Resource Manager — resources, diagnostics, cost | Lecture + operations limitees | Filtre par resource group obligatoire — jamais scope subscription entier |
| `powerplatform` | Power Platform — solutions, environnements, CLI (pac) | Administration Power Platform | Subagent si > 20 lignes |
| `cipp-mcp` | CIPP — Gestion multi-tenant {{IDENTITY_PLATFORM}} ({{BUSINESS_MODEL}}) | Administration tenants clients | Requetes ciblees avec tenant filter |

### Automation

| Serveur MCP | Objet | Scope | Limites |
|-------------|-------|-------|---------|
| `{{WORKFLOW_ENGINE}}-mcp` | {{WORKFLOW_ENGINE}} prod — workflows, executions | **Lecture seule** (mutations bloquees par pre-mcp-gate sauf marker {{WORKFLOW_ENGINE}}) | Lister : subagent obligatoire (pas de limit natif) |
| `{{WORKFLOW_ENGINE}}-dev-mcp` | {{WORKFLOW_ENGINE}} dev — workflows, tests | Lecture + mutations (environnement dev) | Dev-first rule (CARL RULE_15) |

### CRM

| Serveur MCP | Objet | Scope | Limites |
|-------------|-------|-------|---------|
| `prod-{{crm_platform}}-mcp` | Go{{CRM_PLATFORM}} prod — contacts, workflows, locations | **Mutations bloquees** par pre-mcp-gate sauf marker {{crm_platform}} | `limit=20` obligatoire sur contacts |
| `prod-{{crm_platform}}-care-mcp` | Go{{CRM_PLATFORM}} Care tenant prod | **Mutations bloquees** par pre-mcp-gate sauf marker {{crm_platform}} | Meme regles que prod-{{crm_platform}}-mcp |

### Data

| Serveur MCP | Objet | Scope | Limites |
|-------------|-------|-------|---------|
| `{{accounting_platform}}-mcp` | {{ACCOUNTING_PLATFORM}} Online — facturation, comptabilite | Lecture + creation transactions | `MAXRESULTS 25` dans les requetes SQL |
| `airtable-mcp` | Airtable — bases, records, vues | Lecture + ecriture | `maxRecords=20` exploration, `100` max export |
| `google-analytics-mcp` | Google Analytics — reports, audiences | Lecture seule | `limit=25`, date range 30 jours max |
| `gtm-mcp` | Google Tag Manager — tags, triggers, variables | Lecture + publication | Subagent si modifications complexes |

### Browser

| Serveur MCP | Objet | Scope | Limites |
|-------------|-------|-------|---------|
| `playwright-mcp` | Browser automation — screenshots, actions, forms | Automation web | `filename` obligatoire pour browser_snapshot (sinon ~135K tokens) |

### Knowledge

| Serveur MCP | Objet | Scope | Limites |
|-------------|-------|-------|---------|
| `chroma-mcp` | {{RAG_BACKEND}} local — 4 collections RAG | Lecture + indexation | `n_results=5` default, max `10` ; batch max `50` |
| `context7` | Documentation librairies/frameworks externes | Lecture seule (web) | Premier choix pour docs externes |

```mermaid
graph TD
    CLAUDE["Claude Code<br/>Orchestrateur FORGE"]

    subgraph Microsoft["Microsoft / {{IDENTITY_PLATFORM}}"]
        MS365["ms365<br/>Mail, Calendar, Users"]
        {{CLOUD_PROVIDER}}["{{cloud_provider}}-mcp<br/>Resource Manager"]
        PP["powerplatform<br/>Power Platform"]
        CIPP["cipp-mcp<br/>Multi-tenant {{BUSINESS_MODEL}}"]
    end

    subgraph Automation["Automation"]
        {{WORKFLOW_ENGINE}}_PROD["{{WORKFLOW_ENGINE}}-mcp<br/>Prod (lecture seule)"]
        {{WORKFLOW_ENGINE}}_DEV["{{WORKFLOW_ENGINE}}-dev-mcp<br/>Dev (dev-first)"]
    end

    subgraph CRM["CRM"]
        {{CRM_PLATFORM}}["prod-{{crm_platform}}-mcp<br/>Go{{CRM_PLATFORM}} Prod"]
        {{CRM_PLATFORM}}_CARE["prod-{{crm_platform}}-care-mcp<br/>Go{{CRM_PLATFORM}} Care"]
    end

    subgraph Data["Data / Analytics"]
        QB["{{accounting_platform}}-mcp<br/>Comptabilite"]
        AT["airtable-mcp<br/>Bases de donnees"]
        GA["google-analytics-mcp<br/>Rapports"]
        GTM["gtm-mcp<br/>Tag Manager"]
    end

    subgraph Browser["Browser"]
        PW["playwright-mcp<br/>Automation web"]
    end

    subgraph Knowledge["Knowledge / Grounding"]
        CHROMA["chroma-mcp<br/>{{RAG_BACKEND}} local RAG"]
        CTX7["context7<br/>Docs librairies"]
    end

    CLAUDE -->|"operations {{IDENTITY_PLATFORM}}"| Microsoft
    CLAUDE -->|"automation workflows"| Automation
    CLAUDE -->|"CRM (gate prod)"| CRM
    CLAUDE -->|"donnees metier"| Data
    CLAUDE -->|"tests UI/web"| Browser
    CLAUDE -->|"grounding semantique"| Knowledge

    PRE_TOOL["pre-tool-use.sh<br/>+ pre-mcp-gate.sh"] -->|"bloque mutations prod"| CRM
    PRE_TOOL -->|"bloque mutations prod"| Automation
```

## 2. CLI Tools — Executors multi-modele

En complement des MCP servers, FORGE utilise deux CLI pour la delegation de taches d'implementation a des modeles externes.

### Codex CLI (GitHub Copilot)

| Aspect | Detail |
|--------|--------|
| **Usage** | Transport prefere pour les modeles OpenAI (gpt-5.3-codex, o3, gpt-4.1-mini) |
| **Activation** | Via GitHub Copilot dans VS Code |
| **Briefs** | Claude genere `.task-briefs/{NNN}-{slug}.md` avec frontmatter + contexte complet |
| **Domaine principal** | {{SCRIPTING_LANG}}, Bicep, KQL, Graph API (domain override {{CLOUD_PROVIDER}}{{IDENTITY_PLATFORM}}) |
| **Return signal** | Utilisateur tape `Codex done {slug}` — Claude fait git diff + AC check |

### Gemini CLI

| Aspect | Detail |
|--------|--------|
| **Usage** | Transport prefere pour les modeles Google (gemini-3.1) |
| **Activation** | Gemini CLI local |
| **Cas d'usage** | Large context path — audits complets de tenant, analyse de logs volumineux |
| **Fallback** | OpenRouter si Gemini CLI indisponible |

### OpenRouter (fallback)

| Aspect | Detail |
|--------|--------|
| **Usage** | Fallback pour OpenAI si Codex CLI indisponible, ou en mode GSD autonome (pas d'acces Copilot) |
| **Activation** | API key dans env + `.claude/settings.json` |
| **Modeles** | Tous modeles disponibles via OpenRouter |

### Protocol de retour — Return Signal

```
1. Claude genere le brief : .task-briefs/{NNN}-{slug}.md
   → frontmatter : status: pending, target_model, attempt: 0
   → contenu : contexte complet, criteres d'acceptance, snippets de code pertinents

2. Claude affiche : → Codex VS Code : "lis .task-briefs/{NNN}-{slug}.md et execute"

3. Executor produit le code

4. Utilisateur tape : Codex done {slug}

5. Claude execute :
   - git diff → voir les changements
   - Verifie chaque AC du brief
   - PASS → status: reviewed → next task
   - FAIL → attempt += 1
       - attempt ≤ 2 : corrections dans le brief, status: pending (retry)
       - attempt > 2  : status: rejected → Claude execute lui-meme (escalade Opus)
```

## 3. {{RAG_BACKEND}} — Grounding semantique

{{RAG_BACKEND}} est la couche RAG (Retrieval Augmented Generation) locale de FORGE. Son role est d'ancrer les claims des agents dans des sources documentaires verifiees plutot que dans les donnees d'{{identity_provider}}inement potentiellement stalees.

### 4 collections

| Collection | Contenu | Watched paths (sync) | kind filters |
|-----------|---------|---------------------|-------------|
| `reference` | Architecture, securite, coding patterns | `docs/codebase/*`, `docs/references/*`, `docs/architecture/*` | architecture, auth, patterns |
| `knowledge` | Lecons, decisions, solutions, summaries | `LESSONS.md`, `DECISIONS.md`, `docs/solutions/*`, `*-SUMMARY.md` | lesson, decision |
| `planning` | Plans, contextes, roadmap | `.planning/phases/*`, `memory/MEMORY.md` | plan, context |
| `governance-ops` | Standards, guides, procedures, registres | `docs/standards/*`, `docs/guides/*`, `docs/procedures/*`, `docs/playbooks/*` | standard, procedure |

### Mecanisme de synchronisation

| Etape | Outil | Detail |
|-------|-------|--------|
| **Declenchement** | `post-knowledge-sync.sh` (hook PostToolUse) | Nudge apres chaque Write/Edit/MultiEdit sur un watched path |
| **Sync incrementale** | `/knowledge-sync` skill | Compare MD5 avec `config/{{rag_backend}}-registry.json` — ne resync que les fichiers changes |
| **Sync complete** | `/knowledge-sync --full` | Rebuild complet de toutes les collections |
| **Sync par collection** | `/knowledge-sync --collection reference` | Sync ciblee |
| **Registry** | `config/{{rag_backend}}-registry.json` | Hash + timestamp par fichier synce |

### Patterns de requete

| Situation | Collection | kind filter | n_results |
|-----------|-----------|------------|-----------|
| Comment fonctionne un composant FORGE | `reference` | `architecture` | 5 |
| Verifier une decision passee | `knowledge` | `decision` | 5 |
| Reproduire un pattern eprouve | `knowledge` | `lesson` | 5 |
| Contexte d'une phase | `planning` | `context` ou `plan` | 3 |
| Standard de governance | `governance-ops` | `standard` ou `procedure` | 5 |

**Obligation D-B7 :** La clause `where` est obligatoire sur chaque `chroma_query_documents`. Ne pas se fier a la recherche semantique seule.

**Fallback :** Si {{RAG_BACKEND}} est indisponible (Docker arrete), lire directement le fichier source. Non bloquant.

**Grounding rule :** Avant toute claim sur l'architecture, les patterns, ou les decisions passees — interroger {{RAG_BACKEND}}. "J'ai deja vu ce fichier dans la session" n'est pas une preuve valide (cognitive-patterns.md rationalization table).

### Infrastructure

| Composant | Detail |
|-----------|--------|
| Image | `{{rag_backend}}/chroma:1.5.5` |
| Port | `127.0.0.1:8000:8000` (localhost-only) |
| Volume | `.chroma-data/` (gitignored) |
| Config | `docker-compose.{{rag_backend}}.yml` |
| Auto-start | `session-start.sh` → healthcheck → `docker compose up -d` |
| MCP bridge | `chroma-mcp` (chroma-core/chroma-mcp v0.2.6) — installe via `uv tool install chroma-mcp` (binaire permanent, pas uvx) |
| Setup | `bash scripts/setup-{{rag_backend}}.sh` — script idempotent (Docker + chroma-mcp + enregistrement MCP) |

## 4. Services externes

| Service | Role | Methode d'integration | Notes |
|---------|------|-----------------------|-------|
| **Linear** | Gestion de projet — issues, milestones, sprints | MCP `linear` (non liste dans integrations.md — via config) | `first=25` limit |
| **{{SECRETS_MANAGER}} Secrets Manager** | Gestion des secrets MSP (~250$/mois, ~10-15 clients) | {{SECRETS_MANAGER}} SDK — pas de MCP actif | Migration KSM decidee (memory/MEMORY.md) |
| **VPS {{HOSTING_VENDOR}}cloud** | Hebergement {{WORKFLOW_ENGINE}} prod + {{WORKFLOW_ENGINE}} dev + PostgreSQL + AgentDB (Qdrant) | SSH + scripts {{SCRIPTING_LANG}} | Services systemd ; details dans `docs/references/services-and-access.md` |
| **GitHub** | Version control, CI/CD, Copilot (Codex CLI) | Git + gh CLI + GitHub Actions | Pre-commit hooks locaux + SAST en CI |
| **Supermemory** | Memoire cross-projet (Claude Code natif) | Integration native Claude Code | Couche complementaire a {{RAG_BACKEND}} |
| **AgentDB (Qdrant VPS)** | Memoire semantique cross-session hebergee | MCP `agentdb` | Indexee par `index-memory-to-agentdb.sh` |

## 5. Routing des appels — Hierarchie de recherche

Pour toute requete de connaissance, FORGE impose une hierarchie stricte pour optimiser la precision et minimiser la consommation de contexte.

```
context7 (docs lib/frameworks externes)
    ↓ si pas de doc externe applicable
{{RAG_BACKEND}} (knowledge projet ancre)
    ↓ si pas d'entree project pertinente
exa (patterns et best practices publics)
    ↓ dernier recours
WebSearch (recherche generale)
```

| Situation | Outil | Raison |
|-----------|-------|--------|
| Documentation lib/framework/SDK externe (React, Next.js, Prisma, {{CLOUD_PROVIDER}} SDK, etc.) | `context7` | Docs a jour, token-efficient, premier choix |
| Architecture projet, decisions, patterns etablis | `chroma_query_documents` | Ancre dans les docs projet reels |
| Patterns et exemples publics (GitHub, blogs tech) | `exa` | Recherche semantique web ciblee |
| Fallback general | `WebSearch` | Dernier recours — cout token eleve |

### Anti-patterns a eviter

| Anti-pattern | Impact | Regle |
|-------------|--------|-------|
| `git log` sans flag de cap | 2K-10K tokens | Toujours `git log --oneline -20` |
| `grep -r` sans cap | Context flooding | Utiliser `Grep` tool avec `head_limit` |
| `curl url` direct | ~12K tokens HTML brut | Utiliser `WebFetch` |
| `browser_snapshot()` sans `filename` | ~135K tokens | `filename` param obligatoire |
| `Read` du fichier entier pour chercher une fonction | Cout inutile | `Grep` d'abord, `Read(offset, limit)` ensuite |
| `chroma_query_documents` sans clause `where` | Resultats imprecis | `where: {kind: X}` obligatoire (D-B7) |
| Subagent qui retourne > 200 mots | Context flooding | Contrat de retour explicite dans le prompt |
| `list_mail_messages` sans `$top`/`$select` | 30K-60K tokens | `$top=20&$select=subject,from,receivedDateTime` |

---
*Phase: 24-forge-architecture-documentation*
*Generated: 2026-04-08*
