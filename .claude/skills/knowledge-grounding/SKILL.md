---
name: knowledge-grounding
description: "Collection routing and grounding query patterns for {{RAG_BACKEND}} semantic search. Use this skill when answering architecture questions, looking up past decisions, checking compliance requirements, verifying patterns, or any query that benefits from grounded retrieval from the project knowledge base."
triggers:
  - architecture question
  - pattern lookup
  - decision check
  - compliance query
  - security baseline
  - past lesson
  - how was X implemented
version: "1.1"
---

# Knowledge Grounding

Routes domain questions to the correct {{RAG_BACKEND}} collection and provides query templates. Ensures agents use `where` metadata filters (D-B7) for scoped results.

## Domain-to-Collection Routing

| Domain / Question Type | Collection | kind filter |
|----------------------|------------|-------------|
| Architecture, code patterns, services, auth model | `reference` | `architecture`, `patterns`, `services`, `auth` |
| Past decisions, lessons learned, solution patterns | `knowledge` | `decision`, `lesson`, `solution` |
| Phase plan summaries, implementation outcomes | `knowledge` | `summary` |
| Current phase plans, research, context | `planning` | `plan`, `context`, `research` |
| Current session state, next steps | `planning` | `memory` |
| Security baselines, compliance standards | `governance-ops` | `standard` |
| Operational procedures, runbooks | `governance-ops` | `procedure`, `runbook` |
| Risk assessments, audit registers | `governance-ops` | `risk`, `register` |
| ~~Cross-project notes, prior project patterns, Obsidian vault notes~~ *[DEPRECATED 2026-04-28 — collection deleted, vault removed]* | ~~`cross-project`~~ | — |

## Query Templates

**Single-domain query:**
```
chroma_query_documents(
  collection_name="reference",
  query_texts=["how is authentication implemented"],
  n_results=5,
  where={"kind": "auth"}
)
```

**Cross-domain query (check primary + secondary):**
```
# Primary: reference collection for architecture
chroma_query_documents(collection_name="reference", query_texts=["billing integration"], n_results=5, where={"kind": "architecture"})
# Secondary: knowledge collection for past decisions
chroma_query_documents(collection_name="knowledge", query_texts=["billing decision"], n_results=3, where={"kind": "decision"})
```

**Compound filter:**
```
chroma_query_documents(
  collection_name="knowledge",
  query_texts=["retention policy"],
  n_results=5,
  where={"$and": [{"kind": "decision"}, {"phase": "5"}]}
)
```

## Pre-Flight Grounding (R15)

Before executing a phase, query `reference` collection for architecture constraints:
```
chroma_query_documents(collection_name="reference", query_texts=["constraints for {domain}"], n_results=5)
```
This is guidance-level enforcement (not a hard gate). If {{RAG_BACKEND}} unavailable, proceed with file reads.

## Verification Grounding (R16)

Before marking implementation complete, query `reference` to verify alignment:
```
chroma_query_documents(collection_name="reference", query_texts=["expected behavior for {feature}"], n_results=3)
```
Check: does the implementation match the documented architecture?

## {{RAG_BACKEND}} Indexed Scope

<!-- Source: config/{{rag_backend}}-registry.json — update both together in the same commit -->

> **For queries on files outside {{RAG_BACKEND}} indexed scope (see enumeration below), route to Grep directly per `.claude/rules/tool-routing.md` § Scope-Based Routing — {{RAG_BACKEND}} vs Grep.**

**Extension filter (global, derived from `scripts/knowledge-sync.py`):** ONLY `.md` files are indexed. `.ps1`, `.sh`, `.py`, `.ts`, `.json`, `.yaml`, `.bicep` are structurally out of scope — not by exclusion rule, but because the loader never matches them.

### Collection: `reference`

| Property | Value |
|----------|-------|
| `watched_paths` | `docs/references/`, `AGENTS.md`, `docs/architecture/`, `docs/specs/`, `docs/brand-identity/`, `.claude/rules/`, `.claude/skills/`, `.claude/commands/` |
| Typically indexed | `AGENTS.md`, `docs/architecture/**/*.md`, `.claude/rules/*.md` (governance), `.claude/skills/**/SKILL.md`, `docs/references/frameworks/*.md` |
| NOT indexed in this collection | `docs/codebase/**` (explicitly excluded — L1-L3 human refs), any non-`.md` file, `.planning/**`, `docs/standards/**` (see `governance-ops`) |

### Collection: `knowledge`

| Property | Value |
|----------|-------|
| `watched_paths` | `LESSONS.md`, `DECISIONS.md`, `docs/solutions/`, `docs/archive/`, `memory/archive-*.md`, `.planning/phases/**/*SUMMARY*.md`, `.planning/phases/**/*CONTEXT*.md`, `.planning/phases/**/*RESEARCH*.md`, `.planning/phases/**/*VERIFICATION*.md` |
| Typically indexed | `LESSONS.md` (full cap-50 cache), `DECISIONS.md`, `docs/solutions/**/*.md`, SUMMARY/CONTEXT/RESEARCH/VERIFICATION across `active/`, `planned/`, `complete/` phase dirs |
| NOT indexed in this collection | Phase `PLAN.md` files (see `planning`), `memory/MEMORY.md` (see `planning`), any non-`.md`, files that don't match the glob names (e.g. `*-NOTES.md`) |

### Collection: `planning`

| Property | Value |
|----------|-------|
| `watched_paths` | `.planning/phases/active/`, `memory/MEMORY.md`, `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`, `docs/brainstorms/`, `docs/plans/` |
| Typically indexed | `.planning/phases/active/**/*.md` (ONLY active — not planned or complete), `memory/MEMORY.md`, `docs/brainstorms/*.md`, `docs/plans/*.md` |
| NOT indexed in this collection | `.planning/phases/planned/**` (but their CONTEXT/RESEARCH files ARE indexed via `knowledge` collection glob), `.planning/phases/complete/**` (same nuance), `.planning/todos/**` (not watched) |

### Collection: `governance-ops`

| Property | Value |
|----------|-------|
| `watched_paths` | `docs/standards/`, `docs/guides/`, `docs/procedures/`, `docs/registers/`, `docs/risk/`, `docs/runbooks/`, `docs/playbooks/`, `docs/templates/`, `docs/audits/` |
| Typically indexed | `docs/standards/*.md`, `docs/procedures/*.md`, `docs/runbooks/*.md`, `docs/audits/**/*.md` |
| NOT indexed in this collection | Anything outside `docs/`, any non-`.md`, `docs/references/**` (see `reference`), `docs/architecture/**` (see `reference`) |

### Collection: `cross-project` *(DEPRECATED 2026-04-28)*

> **Historical reference only.** Collection deleted server-side via
> `chroma_delete_collection` on 2026-04-28 (Phase 27 Plan 00 D5 / Item 4
> cleanup). Obsidian Vault filesystem removed in commit `97be5a0`. Pre-purge
> dump archived to
> `.planning/phases/active/27-knowledge-layer-infrastructure/artifacts/cross-project-purge-dump-2026-04-28.json`.
> Section retained for audit trail / restorability.

| Property | Value (historical) |
|----------|-------|
| `watched_paths` | `Obsidian Vault/cross-project-inbox/**/*.md`, `Obsidian Vault/{{PROJECT}}/**/*.md`, `Obsidian Vault/Marketing OS/**/*.md` |
| Excluded | `Obsidian Vault/**/.obsidian/**` (system dir, not indexed) |
| Was indexed | Exported Supermemory notes, cross-project Obsidian vault notes |
| NOT indexed | `.obsidian/` config dirs, any non-`.md` vault files |
| Used for | Cross-project patterns, lessons from other projects, marketing strategy notes |
| kind filter | `note` (vault notes), `memory` (exported Supermemory items) |

### Global Excluded Paths

- `config/{{rag_backend}}-registry.json` — the registry itself (prevents infinite reindex loop)
- `docs/codebase/` — explicitly excluded; these are L1-L3 human-maintained coding refs read via Read/Grep, never via semantic search

### Structural Gaps (NO collection covers these — route to Grep via `tool-routing.md § Scope-Based Routing`)

| Category | Example path | Why out of scope | Canonical access |
|----------|--------------|------------------|------------------|
| {{SCRIPTING_LANG}} runbooks | `scripts/runbooks/*.ps1` | Non-`.md` extension | Grep `scripts/runbooks/` |
| Shell scripts | `scripts/*.sh`, `scripts/upstream-watch/*.sh` | Non-`.md` extension | Grep `scripts/` |
| Python scripts | `scripts/knowledge-sync.py`, `scripts/*.py` | Non-`.md` extension | Grep `scripts/` or Read direct |
| JSON configs | `config/*.json`, `.mcp.json`, `.claude/settings*.json` | Non-`.md` extension | Read direct or Grep `config/` |
| YAML configs | `.github/workflows/*.yml`, `.github/dependabot.yml` | Non-`.md` extension | Grep `.github/` |
| Root-level docs | `README.md`, `CLAUDE.md` | Not in any `watched_paths` array | Read direct |
| Infrastructure as code | `infra/**/*.bicep`, `docker-compose*.yml` | Non-`.md` extension | Grep `infra/` |
| {{WORKFLOW_ENGINE}} workflows | `{{WORKFLOW_ENGINE}}/workflows/*.json` | Non-`.md` extension | Grep `{{WORKFLOW_ENGINE}}/workflows/` |
| Auto-memory (home dir) | `~/.claude/projects/*/memory/*.md` | Outside repo tree | Grep `~/.claude/projects/` |
| `docs/codebase/` refs | `docs/codebase/*.md` | Explicitly excluded (see above) | Read direct or Grep `docs/codebase/` |
| Planned/complete phase `PLAN.md` | `.planning/phases/{planned,complete}/*/*PLAN*.md` | Not matched by any glob | Grep `.planning/phases/` |
| `.planning/todos/**` | `.planning/todos/pending/*.md` | Not in any watched_paths | Grep `.planning/todos/` |

## MCP Routing

- Preferred: chroma-mcp (`chroma_query_documents`)
- Fallback: Direct file Read (if {{RAG_BACKEND}} unavailable)
- Always use `where` clause with `kind` filter (D-B7)
- Default `n_results=5`, max `n_results=10`
- Reference: `.claude/rules/tool-routing.md`

## Rules

1. ALWAYS include `where` clause with at least a `kind` filter (D-B7)
2. For cross-domain queries, query primary collection first, then secondary
3. If query returns 0 results, broaden the `kind` filter or remove it, then re-query
4. {{RAG_BACKEND}} unavailability is NEVER blocking (fallback to direct file reads)
5. Queries are stateless — no conversation isolation needed (R12)
