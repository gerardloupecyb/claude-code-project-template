# Roadmap: project-template-v2 — ruflo concepts integration

## Overview

Two-milestone project enriching project-template-v2 with ruflo concepts. Milestone 1 (Track A) delivers 7 standalone template enrichments — swarm conventions, SPARC micro-execution, pre-flight enforcement, decision tracking, DDD léger, agent spawn auditing, and template/init wiring — all with zero external dependencies. Milestone 2 (Track B) builds the self-hosted AgentDB stack (Qdrant + embedding + MCP client + git entries) that replaces Supermemory with a debuggable, team-shared semantic memory.

## Milestones

- 🚧 **Milestone 1 — Track A: Template Enrichments** - Phases 1-7 (in progress)
- 📋 **Milestone 2 — Track B: AgentDB Self-Hosted** - Phases 8-11 (planned)

## Phases

### Milestone 1 — Track A: Template Enrichments

- [ ] **Phase 1: swarm-patterns.md** - Document 8 agent roles, 3 topologies, 3-tier model routing, SPARC routing, escalation rules
- [ ] **Phase 2: Pre-flight Agent 5 Critic** - Add critic agent (sequential after Agent 1), Architecture Challenge section, DDD integration
- [ ] **Phase 3: SPARC Skill** - Create 5-phase SPARC skill with dual-agent phases 3 and 5, workspace files, contexts.md
- [ ] **Phase 4: Pre-flight Enforcement** - Add CARL rule + session-gate Check 18 blocking execution without pre-flight
- [ ] **Phase 5: Execution Quality + DDD** - Add Decision Tracking to execution-quality.md + create contexts.md.template + wire pre-flight and SPARC
- [ ] **Phase 6: Agent Spawn Hook** - Create pre-agent.sh hook, update settings.json, session-gate Check 19, session-start.sh
- [ ] **Phase 7: Template + Init** - Update CLAUDE.md.template references (SPARC, swarm-patterns, AgentDB), update init-project.sh

### Milestone 2 — Track B: AgentDB Self-Hosted

- [ ] **Phase 8: VPS Infrastructure** - Docker Compose with Qdrant + embedding service + agentdb-api REST
- [ ] **Phase 9: MCP Thin Client** - Create .claude/mcp/agentdb/ with 5 tools, local-first writes, per-project config
- [ ] **Phase 10: Entries Format + Git** - Define entry format, .agentdb/entries/ git-tracked, reindex script
- [ ] **Phase 11: Migration Supermemory → AgentDB** - Migration guide, update CLAUDE.md.template, update flywheel

## Phase Details

### Phase 1: swarm-patterns.md
**Goal**: Multi-agent conventions are formalized and auto-loaded by all subagents
**Depends on**: Nothing (first phase)
**Requirements**: SWARM-01, SWARM-02, SWARM-03, SWARM-04, SWARM-05
**Success Criteria** (what must be TRUE):
  1. `.claude/rules/swarm-patterns.md` exists and lists all 8 agent roles with responsibilities
  2. Three topology patterns (hierarchical, anti-drift, shared namespace) are documented
  3. 3-tier model routing table (Haiku/Sonnet/Opus) is present with escalation conditions
  4. SPARC phase-to-model routing table exists with Opus escalation conditions
  5. File stays under 80 lines
**Plans**: TBD

### Phase 2: Pre-flight Agent 5 Critic
**Goal**: Pre-flight challenges its own architecture findings before a plan is approved
**Depends on**: Phase 1 (references swarm-patterns.md critic role)
**Requirements**: PREFLT-01, PREFLT-02, PREFLT-03, PREFLT-04, PREFLT-05, PREFLT-06
**Success Criteria** (what must be TRUE):
  1. Agent 5 Critic appears in `.claude/skills/pre-flight/SKILL.md`, runs after Agent 1 output is available
  2. Agent 5 references the `critic` role from swarm-patterns.md
  3. Pre-flight report template includes an "Architecture Challenge" section
  4. Agent 5 is skipped when Agent 1 finds no architectural concerns (trivial plan)
  5. Agent 5 reads `docs/architecture/contexts.md` as a constraint when the file exists
**Plans**: TBD

### Phase 3: SPARC Skill
**Goal**: Developers can invoke a structured 5-phase micro-execution skill within any GSD phase
**Depends on**: Phase 1 (model routing), Phase 2 (critic role pattern)
**Requirements**: SPARC-01, SPARC-02, SPARC-03, SPARC-04, SPARC-05, SPARC-06, SPARC-07, SPARC-08, SPARC-09
**Success Criteria** (what must be TRUE):
  1. `.claude/skills/sparc/SKILL.md` exists with Spec, Pseudo, Arch, Refine, Complete phases
  2. Phase 3 (Arch) spawns architect + critic agents in parallel at tier 3
  3. Phase 5 (Complete) spawns reviewer + critic agents in parallel at tier 3
  4. Each phase requires explicit user validation before advancing
  5. SPARC works standalone (Phase 5 invocable alone for Codex review without full GSD)
  6. Workspace artifacts written to `.claude/workspace/sparc-*.md`
  7. File stays under 150 lines
**Plans**: TBD

### Phase 4: Pre-flight Enforcement
**Goal**: Executing a GSD phase without a completed pre-flight is mechanically blocked
**Depends on**: Phase 2 (pre-flight exists), Phase 3 (session-gate pattern)
**Requirements**: ENFC-01, ENFC-02, ENFC-03, ENFC-04, ENFC-05, ENFC-06
**Success Criteria** (what must be TRUE):
  1. A CARL rule exists stating "do not run /gsd:execute-phase without a *-PREFLIGHT.md file"
  2. Session-gate Check 18 (mode END) detects a PLAN file with no corresponding PREFLIGHT file
  3. Check 18 also detects a NO-GO verdict that has not been relaunched
  4. Check 18 searches both `.planning/` and `.planning/milestones/` paths
  5. Error messages are actionable (tell the user exactly what command to run next)
**Plans**: TBD

### Phase 5: Execution Quality + DDD
**Goal**: Architectural decisions are auto-tracked and cross-domain boundaries are visible before modification
**Depends on**: Phase 3 (SPARC references contexts.md), Phase 4 (execution-quality.md still under budget)
**Requirements**: ADR-01, ADR-02, ADR-03, DDD-01, DDD-02, DDD-03, DDD-04, DDD-05
**Success Criteria** (what must be TRUE):
  1. `execution-quality.md` contains a "Decision Tracking" section with skip heuristic
  2. `execution-quality.md` total line count stays under 80 lines
  3. `docs/architecture/contexts.md.template` exists with domain placeholder sections
  4. Pre-flight SKILL.md (Agent 5) and SPARC SKILL.md (Phase 3) both reference contexts.md
  5. When contexts.md has only unfilled placeholders, agents ignore it without error
**Plans**: TBD

### Phase 6: Agent Spawn Hook
**Goal**: Every agent spawn is logged per session and audited at session end
**Depends on**: Phase 5 (session-gate has Check 18 before adding Check 19)
**Requirements**: HOOK-01, HOOK-02, HOOK-03, HOOK-04, HOOK-05, HOOK-06
**Success Criteria** (what must be TRUE):
  1. `.claude/hooks/pre-agent.sh` exists, logs timestamp + agent type + description on each spawn
  2. Log entries are written to `.claude/workspace/agent-log.txt`
  3. Hook always exits 0 (never blocks Claude from spawning an agent)
  4. `.claude/settings.json` has a `PreToolUse` matcher for `Agent` triggering the hook
  5. Session-gate Check 19 (END, informational) counts spawns and alerts when count exceeds 15
  6. `session-start.sh` clears agent-log.txt so the counter resets each session
**Plans**: TBD

### Phase 7: Template + Init
**Goal**: New projects initialized from the template get all Milestone 1 enrichments wired automatically
**Depends on**: Phases 1-6 (all template files must exist to be referenced)
**Requirements**: TMPL-01, TMPL-02, TMPL-03, TMPL-04, TMPL-05, TMPL-06, TMPL-07
**Success Criteria** (what must be TRUE):
  1. `CLAUDE.md.template` references SPARC skill, swarm-patterns, and AgentDB (forward pointer)
  2. `CLAUDE.md.template` documents the complex-task flow (when to invoke SPARC)
  3. `CLAUDE.md.template` stays under 200 lines
  4. `init-project.sh` copies `docs/architecture/contexts.md.template` into new projects
  5. `init-project.sh` copies `.claude/hooks/pre-agent.sh` and wires it into settings.json
  6. `init-project.sh` adds `.claude/workspace/` to `.gitignore`
**Plans**: TBD

### Phase 8: VPS Infrastructure
**Goal**: A self-hosted vector search stack accepts store/search requests from Claude
**Depends on**: Nothing (first Milestone 2 phase, independent of Track A)
**Requirements**: VPS-01, VPS-02, VPS-03, VPS-04
**Success Criteria** (what must be TRUE):
  1. `docker-compose.yml` brings up Qdrant + embedding service + agentdb-api with one command
  2. Embedding service returns vectors for a test string using nomic-embed-text-v1.5
  3. Qdrant accepts a store request and returns the same document on search
  4. agentdb-api responds on all 5 endpoints: store, search, list, delete, reindex
**Plans**: TBD

### Phase 9: MCP Thin Client
**Goal**: Claude can store and search semantic memory via MCP tools backed by the VPS
**Depends on**: Phase 8 (VPS must be reachable for integration tests)
**Requirements**: MCP-01, MCP-02, MCP-03, MCP-04, MCP-05, MCP-06
**Success Criteria** (what must be TRUE):
  1. `.claude/mcp/agentdb/` contains a working index.js + package.json
  2. Five tools are exposed: agentdb_store, agentdb_search, agentdb_list, agentdb_delete, agentdb_debug
  3. `agentdb_store` writes a local file under `.agentdb/entries/` before attempting VPS sync
  4. `agentdb_debug` returns raw similarity scores for a query (diagnosability)
  5. When VPS is unreachable, `agentdb_store` still succeeds with the local file created
  6. Project config lives in `.agentdb/config.json` (vps_url, api_key, namespace)
**Plans**: TBD

### Phase 10: Entries Format + Git
**Goal**: Agent memory entries are human-readable, git-tracked, and rebuildable from source
**Depends on**: Phase 9 (MCP client writes entries; format must be final before migration)
**Requirements**: ENT-01, ENT-02, ENT-03, ENT-04
**Success Criteria** (what must be TRUE):
  1. Entry format is defined: frontmatter (title, domain, classification, date, author, tags) + markdown body sections
  2. `.agentdb/entries/` is git-tracked (entries committed alongside code)
  3. `.agentdb/config.json` template uses environment variable references for sensitive values
  4. `agentdb-reindex.sh` rebuilds the VPS index from local entry files without data loss
**Plans**: TBD

### Phase 11: Migration Supermemory → AgentDB
**Goal**: AgentDB is the canonical memory tool and Supermemory references are removed from the workflow
**Depends on**: Phase 10 (entry format finalized before migration guide is written)
**Requirements**: MIG-01, MIG-02, MIG-03
**Success Criteria** (what must be TRUE):
  1. A migration guide documents how to export from Supermemory and re-import into AgentDB
  2. `CLAUDE.md.template` references AgentDB as the memory tool (Supermemory removed)
  3. The flywheel workflow (`/lesson migrate`) points to AgentDB store calls, not Supermemory
**Plans**: TBD

## Progress

**Execution Order:** 1 → 2 → 3 → 4 → 5 → 6 → 7 (Milestone 1), then 8 → 9 → 10 → 11 (Milestone 2)

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. swarm-patterns.md | Track A | 0/TBD | Not started | - |
| 2. Pre-flight Agent 5 Critic | Track A | 0/TBD | Not started | - |
| 3. SPARC Skill | Track A | 0/TBD | Not started | - |
| 4. Pre-flight Enforcement | Track A | 0/TBD | Not started | - |
| 5. Execution Quality + DDD | Track A | 0/TBD | Not started | - |
| 6. Agent Spawn Hook | Track A | 0/TBD | Not started | - |
| 7. Template + Init | Track A | 0/TBD | Not started | - |
| 8. VPS Infrastructure | Track B | 0/TBD | Not started | - |
| 9. MCP Thin Client | Track B | 0/TBD | Not started | - |
| 10. Entries Format + Git | Track B | 0/TBD | Not started | - |
| 11. Migration Supermemory → AgentDB | Track B | 0/TBD | Not started | - |
