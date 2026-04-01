---
name: reference-audit
description: "Auto-populate and validate docs/references/ files by scanning the codebase for infra artifacts, detecting staleness, and cross-referencing MCP entries. Triggers on: reference audit, audit references, populate references, vérifier références, sync references."
---

# Reference Audit — Auto-populate & Validate Reference Files

Scan the codebase for infrastructure artifacts and fill docs/references/ files.
Cross-reference MCP entries between services-and-access.md and tool-routing.md.
Detect stale entries. Report findings and propose edits.

---

## Invocation

| Command | What it does |
|---------|-------------|
| `/reference-audit` | Full audit: detect, populate, cross-reference, staleness check |
| `/reference-audit --dry-run` | Report only — no file modifications |
| `/reference-audit --populate` | Auto-populate only — skip cross-reference and staleness |
| `/reference-audit --check` | Cross-reference + staleness only — skip population |

---

## Step 1 — Detect Infrastructure Artifacts

Scan the project for known infrastructure files. Use Glob and Grep (never Bash find/grep).

### Docker detection

```
Glob: **/Dockerfile, **/docker-compose*.yml, **/docker-compose*.yaml
```

For each docker-compose file found:
1. Read the file
2. Extract service names, images, ports, restart policies
3. Compare with docs/references/services-and-access.md "Docker Services" table
4. Report: `[NEW]` services not in reference, `[MATCH]` services already documented, `[STALE]` services in reference but not in compose

### Secrets / Environment Variables detection

```
Glob: **/.env.example, **/.env.sample, **/.env.template
```

If no example file exists, check `.env` but **NEVER read or output values**.
Extract variable names only (left side of `=`).
Compare with docs/references/services-and-access.md "Secrets" table.

### Language & Framework detection

```
Glob: **/package.json, **/Gemfile, **/requirements.txt, **/pyproject.toml,
      **/go.mod, **/Cargo.toml, **/composer.json, **/mix.exs, **/*.csproj
```

For each found:
1. Extract language/framework name and version
2. Compare with docs/references/coding-patterns.md "Language & Framework Stack" table
3. Report `[NEW]` or `[MATCH]`

### MCP detection

```
Read: .claude/settings.json (look for mcpServers key)
Glob: **/.mcp.json, **/.mcp*.json
```

For each MCP server found:
1. Extract name, command/endpoint
2. Compare with docs/references/services-and-access.md "MCP Servers" table
3. Report `[NEW]`, `[MATCH]`, or `[STALE]`

### Entry Points detection

```
Glob: **/Makefile, **/Procfile, **/package.json (scripts section), **/Taskfile.yml
```

Extract key commands (dev, test, build, deploy).
Compare with docs/references/codebase-context.md "Entry Points" table.

### Schema detection

```
Glob: **/schema.rb, **/schema.prisma, **/migrations/**/*.sql,
      **/db/migrate/**/*.rb, **/alembic/**/*.py, **/*.graphql
```

List found schema files. Compare with docs/references/codebase-context.md "Data Schemas" table.

---

## Step 2 — Cross-Reference Validation

### MCP sync: tool-routing.md ↔ services-and-access.md

1. Read `.claude/rules/tool-routing.md`
2. Extract MCP names from "Discipline MCP" table (column 1, pattern `mcp__*`)
3. Read `docs/references/services-and-access.md`
4. Extract MCP names from "MCP Servers" table (column 1)
5. Report:
   - `[DESYNC]` MCPs in tool-routing but NOT in services-and-access
   - `[DESYNC]` MCPs in services-and-access but NOT in tool-routing
   - `[SYNC]` MCPs present in both

### Secrets sync: .env ↔ services-and-access.md

1. Read `.env.example` (or `.env` — names only, never values)
2. Extract variable names
3. Compare with "Secrets" table in services-and-access.md
4. Report `[DESYNC]` for missing entries in either direction

---

## Step 3 — Staleness Check

For each file in docs/references/:
1. Find the `Last verified:` line
2. Parse the YYYY-MM-DD date
3. If > 30 days ago: `[STALE]` — recommend re-verification
4. If no date or unparsable: `[!!]` — no verification date set

---

## Step 4 — Output Report

```
Reference Audit Report
======================

## Detection Results

  Docker Services:
    [NEW]   redis (redis:7-alpine, port 6379)
    [MATCH] app (node:20, port 3000)
    [STALE] old-worker — in reference but not in docker-compose

  Secrets:
    [NEW]   STRIPE_SECRET_KEY — in .env.example, not in reference
    [MATCH] DATABASE_URL

  Languages:
    [MATCH] Node.js 20.x (from package.json)
    [NEW]   Python 3.12 (from requirements.txt)

  MCP Servers:
    [NEW]   mcp__stripe — in settings.json, not in reference

  Entry Points:
    [NEW]   npm run dev (from package.json scripts)

## Cross-Reference

  MCP Sync:
    [DESYNC] mcp__stripe — in tool-routing.md but NOT in services-and-access.md
    [SYNC]   mcp__linear — present in both

  Secrets Sync:
    [DESYNC] REDIS_URL — in .env.example but NOT in services-and-access.md

## Staleness

  [STALE]  architecture-security.md — Last verified 2026-01-15 (64 days ago)
  [ok]     services-and-access.md — Last verified 2026-03-18 (2 days ago)
  [!!]     coding-patterns.md — No verification date set

## Proposed Actions

  1. Add redis service to services-and-access.md Docker table
  2. Add STRIPE_SECRET_KEY to services-and-access.md Secrets table
  3. Add Python 3.12 to coding-patterns.md Language Stack table
  4. Add mcp__stripe to services-and-access.md MCP table
  5. Remove old-worker from services-and-access.md (not in docker-compose)
  6. Update Last verified date on architecture-security.md
```

---

## Step 5 — Apply Changes (unless --dry-run)

For each `[NEW]` and `[STALE]` finding:
1. Propose the edit to the user
2. If user confirms (or no --dry-run): apply the edit
3. Update `Last verified: YYYY-MM-DD` on each modified file

For `[DESYNC]` findings:
1. Propose adding the missing entry to the target file
2. Apply if confirmed

---

## What this skill does NOT do

- Read secret VALUES from .env (only variable names)
- Modify .claude/rules/tool-routing.md (that's CARL RULE_9 / GLOBAL_RULE_9)
- Create reference files if docs/references/ doesn't exist (run init-project.sh first)
- Replace manual documentation — it fills tables, not prose sections
- Run without user confirmation on writes (unless piped into automation)
