---
title: "feat: Integrate ruflo orchestration concepts — SPARC, dual-agent, AgentDB, DDD"
type: feat
status: active
date: 2026-03-31
origin: docs/plans/2026-03-31-feat-ruflo-concepts-integration-plan.md
tracks: 2
---

# Integrate ruflo Orchestration Concepts into project-template-v2

## Overview

Extract and adapt key concepts from [ruvnet/ruflo](https://github.com/ruvnet/ruflo) into the project template **with zero dependency on ruflo**. Two parallel tracks: template enrichments (Track A) and AgentDB self-hosted semantic memory (Track B).

See origin document for full technical specifications: [docs/plans/2026-03-31-feat-ruflo-concepts-integration-plan.md](docs/plans/2026-03-31-feat-ruflo-concepts-integration-plan.md)

## Problem Statement

The current template has 8 identified gaps vs. ruflo:

1. **No micro-execution methodology** — GSD handles macro (roadmap, phases) but not micro (how to execute a complex task step-by-step)
2. **Mono-perspective review** — single agent reviews code, no structured challenge
3. **Weak design validation** — pre-flight has 4 agents but no devil's advocate
4. **No pre-flight enforcement** — pre-flight is recommended but not enforced; Claude has skipped it
5. **Poor semantic memory** — Supermemory recall returns noise, no debugging visibility
6. **Implicit multi-agent conventions** — no formal rules for agent topology, max count, anti-drift
7. **Lost architectural decisions** — DECISIONS.md manually maintained; decisions made during execution are dropped
8. **No DDD tracking** — bounded contexts undocumented, cross-domain violations undetected

## Proposed Solution

### Track A — Template Enrichments (18 deliverables, zero external dependencies)

| ID | Deliverable | File(s) |
|----|------------|---------|
| A1 | `swarm-patterns.md` — agent roles, topology, model routing, limits | `.claude/rules/swarm-patterns.md` |
| A2 | Pre-flight Agent 5 Critic — architecture challenge | `.claude/skills/pre-flight/SKILL.md` |
| A3 | SPARC skill — 5-phase micro-executor | `.claude/skills/sparc/SKILL.md` |
| A4 | CARL rule — enforce pre-flight before execute-phase | `.carl/{domain}` |
| A5 | Session-gate Check 18 — pre-flight file detection | `.claude/skills/session-gate/SKILL.md` |
| A6 | ADR auto-tracking — decision capture rule | `.claude/rules/execution-quality.md` |
| A7 | DDD contexts template — bounded contexts doc | `docs/architecture/contexts.md.template` |
| A8 | PreToolUse hook — agent spawn logger | `.claude/hooks/pre-agent.sh` + `settings.json` |
| A9 | CLAUDE.md.template + init-project.sh (phase 1) | `CLAUDE.md.template`, `init-project.sh` |
| A10 | Codex plugin install — config + manual instructions | `init-project.sh`, `.codex/config.toml.template` |
| A11 | SPARC Phase 4 — Codex rescue option | `.claude/skills/sparc/SKILL.md` |
| A12 | SPARC Phase 5 — dual review (Codex adversarial + CE:review) | `.claude/skills/sparc/SKILL.md` |
| A13 | Pre-flight — Codex adversarial on the plan | `.claude/skills/pre-flight/SKILL.md` |
| A14 | `/prepare-phase` orchestrator | `.claude/skills/prepare-phase/SKILL.md` |
| A16 | `/todo` skill — CRUD encapsulation for `todos/` | `.claude/skills/todo/SKILL.md` |
| A17 | CARL rule — forbid direct Write to `todos/` | `.carl/{domain}` |
| A18 | CLAUDE.md.template + init-project.sh (final) | `CLAUDE.md.template`, `init-project.sh` |

### Track B — AgentDB Self-Hosted (7 deliverables, replaces Supermemory 100%)

| ID | Deliverable | Description |
|----|------------|-------------|
| B1 | VPS setup — Qdrant + embedding + API | Docker compose, REST API (5 endpoints) |
| B2 | MCP thin client — local-first + VPS sync | `.claude/mcp/agentdb/` Node.js server |
| B3 | Entry format — markdown + YAML frontmatter | `.agentdb/entries/` (git-tracked source of truth) |
| B4 | Hooks — sync via agentdb_store, reindex script | `scripts/agentdb-reindex.sh` (Node.js) |
| B5 | Skills update — redirect Supermemory → AgentDB | `/lesson`, `/ce:compound`, `/project-bootstrap` |
| B6 | Cross-project namespace — scope=global | Shared Qdrant collection across projects |
| B7 | Supermemory deprecation — 2-week coexistence | Remove MCP refs, update CLAUDE.md |

## Technical Approach

### Architecture

**Workflow layers after implementation:**

```
Layer         Scope           Tool                  Granularity
---------------------------------------------------------------
MACRO         Roadmap/phases  GSD                   Days/weeks
MICRO         Task execution  SPARC (in GSD)        Hours
MICRO (alt)   Isolated tasks  CE:work               Hours
QUICK FIX     Trivial         /gsd:fast             Minutes
MEMORY        Semantic store  AgentDB               Persistent
```

**Canonical workflows:**

```
Phase GSD:  /prepare-phase {N} → /sparc "description" → /gsd:verify-work

Isolated:   CE:work (structured tasks outside GSD)
Quick fix:  /gsd:fast (user consciously shortcuts)
```

**Key architectural decisions (see origin for full Decision Log):**

- No ruflo npm dependencies (claude-flow, ruv-swarm, AgentDB ruflo)
- Agent roles merged into `swarm-patterns.md` (single source of truth, no stale YAML dir)
- Dual-agent design in pre-flight (not standalone skill — fewer commands to memorize)
- AgentDB on VPS (not local SQLite — colleagues share real-time, no local rebuild)
- Supermemory replaced not improved (fundamental problem: undebuggable black box)
- `/gsd:execute-phase` NOT wrapped — SPARC is an independent template skill

### Implementation Phases

#### Phase 1 — Stabilize the Orchestration Contract (blocker for Phase 3)

Freeze the workflow contract in `docs/architecture/workflow-architecture.md` before building:
- Remove /gsd:execute-phase wrapper concept
- Fix canonical parcours (see Technical Approach above)
- Align A3, A14 with the new contract

**Deliverables:** Updated `workflow-architecture.md`

#### Phase 2 — AgentDB (parallel, blocker for A18 via B5)

Develop as autonomous track. Interfaces to freeze before start:
- `local-first` contract: `agentdb_store` writes local then syncs VPS
- `.agentdb/config.json` gitignored, `.agentdb/config.json.template` versioned
- Retry queue for failed syncs → `.agentdb/sync-errors.log`
- Fallback: `scripts/agentdb-reindex.sh` (Node.js, no python3 dependency)
- Auth v1: project-scoped API key (no JWT/RBAC until specified)

**Deliverables:** B1 → B7 in sequence

#### Phase 3 — Skills, Rules, Hooks (sequential, depends on Phase 1)

```
A1 → A2 → A3 → A6 → A7 → A10 → A11 → A12 → A13 → A4 → A5 → A14 → A16 → A17 → A8
```

**Order rationale:** swarm-patterns.md (A1) is the foundation — all agent roles reference it. Pre-flight (A2) and SPARC (A3) depend on A1. CARL enforcement (A4, A17) and session-gate (A5) depend on the skills existing. A14 depends on A2, A3, A13. A8 (hook) is last since it depends on workspace dir existing.

#### Phase 4 — UX Polish (depends on Phase 3)

- `--from` flag on /prepare-phase
- Session-gate Check 19 (agent spawn audit consuming agent-log.txt)
- `/todo` duplicate prevention (title similarity check)
- Documentation: "Getting Started" progressive disclosure in workflow-architecture.md

#### Phase 5 — Optimizations (DEFER — under proof)

- Agent 5 in parallel with Agents 2-4 (redefine role first)
- Embedding model benchmark (bge-small vs nomic-embed-text-v1.5)
- Budget reduction swarm-patterns.md (60 vs 80 lines)
- /gsd:quick redefinition (external semantics — do not touch)

#### Phase Final — Documentation and init (depends on Phase 3 + B5)

- A18: CLAUDE.md.template + init-project.sh (full update)
- `init-project.sh --upgrade` (spec to define during implementation)

### Dependencies

```
Phase 1 (contract) ← blocks Phase 3 (skills)
Phase 2 (AgentDB)  ← parallel, blocks A18 via B5
Phase 3 (skills)   ← blocks Phase 4 (UX)
Phase 4 (UX)       ← blocks Phase Final
Phase 5 (optim)    ← independent, under proof
```

## Alternative Approaches Considered

| Rejected approach | Chosen approach | Reason |
|-------------------|-----------------|--------|
| Integrate ruflo npm packages | Extract concepts only | Too heavy, breaking change risk, every colleague must install |
| Separate `agents/` dir with YAML | Merge roles into `swarm-patterns.md` | Duplication risk between two sources |
| Standalone `/dual-agent` skill | Dual-agent inside pre-flight + SPARC | Redundant command, same mechanics |
| Standalone `/codex-review` skill | Dual review in SPARC Phase 5 | Same pattern, code source doesn't change the mechanic |
| CARL rule alone | CARL + session-gate combined | Claude violates rules sometimes — defense in depth required |
| Local SQLite for AgentDB | VPS-hosted Qdrant | Colleagues share knowledge real-time, no local rebuild |
| Improve Supermemory | Replace Supermemory | Fundamental problem: undebuggable black box, not just bad tags |
| Full DDD tracking (like ruflo) | Lightweight DDD (1 file + 1 rule) | Most projects have domains; full tracking system is overkill |

## System-Wide Impact

### Interaction Graph

**A1 swarm-patterns.md** — auto-loaded into every Claude context (`.claude/rules/` mechanism). All 8 agent roles referenced by SPARC (5 phases) and pre-flight (Agent 5). Changes to role definitions propagate to SPARC and pre-flight immediately.

**A2 pre-flight Agent 5 Critic** — fires sequentially AFTER Agent 1 (Architecture Strategist) completes. Adds ~30s to pre-flight. Receives Agent 1 output + `docs/architecture/contexts.md` if it exists. Two-level trace: Agent 1 proposes → Agent 5 challenges → Claude synthesizes.

**A3 SPARC** — spawns up to 4 agents per execution (spec-writer, logic-planner, architect+critic in parallel, reviewer+critic in parallel). Each phase writes to `.claude/workspace/sparc-{phase}.md`. Downstream: Phase 4 triggers GSD standard execution; Phase 5 triggers CE:review and Codex adversarial.

**A4 CARL rule** — fires on every `/gsd:execute-phase` invocation. Checks for `*-PREFLIGHT.md` in `.planning/` or `.planning/milestones/{milestone}/`. No runtime overhead except the file check.

**A8 pre-agent.sh hook** — fires on EVERY `Agent` tool call via PreToolUse hook in settings.json. Appends one line to `.claude/workspace/agent-log.txt`. Must exit 0 always. Log reset at every session start (session-start.sh modification). Two-level trace: Agent spawned → logged → Check 19 audits at END.

**AgentDB** — called by `/lesson`, `/ce:compound`, `/project-bootstrap`, `/memory-consolidate`. `agentdb_store` triggers: local file write (`.agentdb/entries/`) + HTTP POST to VPS. If VPS down: local write succeeds, HTTP fails, error logged to `.agentdb/sync-errors.log`. No caller failure propagation.

### Error and Failure Propagation

| Component | Error source | Propagation | Handling |
|-----------|-------------|-------------|----------|
| `pre-agent.sh` | Any error in hook | `exit 0` always | Never blocks Agent tool |
| `agentdb_store` | VPS HTTP failure | Log to sync-errors.log | Caller gets success (local write succeeded) |
| `agentdb_store` | Local write failure | Propagated | Caller must handle |
| SPARC phase failure | Agent returns < 3 lines | Stop chain | Report to user, do not auto-retry |
| /prepare-phase | discuss/plan-phase failure | Stop chain | Diagnostic to user |
| Pre-flight NO-GO | — | /prepare-phase stops | User informed, plan revision proposed |
| Codex unavailable | Plugin not installed | Skip silently | Never blocks pre-flight or SPARC |
| session-gate Check 18/19 | File not found | `[--]` warning only | Never blocks |

### State Lifecycle Risks

**`.claude/workspace/agent-log.txt`** — reset at session start via `session-start.sh` modification. Risk: if session-start hook fails, log is not reset and Check 19 shows stale count. Mitigation: hook uses `> "$FILE"` (truncate, not rm) — safe even if file doesn't exist.

**`.agentdb/entries/`** — append-only (git-tracked, source of truth). No delete path except explicit `agentdb_delete` tool call. VPS Qdrant is the search index — rebuilable from entries via `/reindex`. Zero state loss if VPS crashes.

**`.claude/workspace/sparc-*.md`** — session-scoped workspace. Can be overwritten if SPARC runs twice in same session. Risk: second SPARC run overwrites Phase 1-3 context. Mitigation: SPARC should detect existing workspace files and ask before overwriting.

**`DECISIONS.md`** — append-only by execution-quality ADR rule. No conflict risk (append only). Old decisions never deleted. Lightweight risk.

**`*-PREFLIGHT.md`** — written per phase by pre-flight skill. Check 18 looks for MOST RECENT preflight with GO verdict. If re-run after a NO-GO, the new file is newer → Check 18 passes correctly.

### API Surface Parity

Skills requiring update when AgentDB replaces Supermemory (B5):
- `/lesson` — `memory("store...")` → `agentdb_store(...)`, `recall(...)` → `agentdb_search(...)`
- `/lesson migrate` — destination `.agentdb/entries/` + VPS sync
- `/ce:compound` — flywheel Supermemory step → `agentdb_store` with cross-project classification
- `/project-bootstrap` — `recall` → `agentdb_search(scope="global")`
- `/memory-consolidate` — add `.agentdb/entries/` vs LESSONS.md coherence check
- `CLAUDE.md.template` — replace Supermemory references in "Fichiers mémoire" section

Session-gate checks are additive (new checks 18, 19). Existing checks 1-17 unaffected. New checks use only file existence + grep — no semantic evaluation.

Pre-flight interface unchanged from callers' perspective (same inputs, richer output). Agent count 4→5 is internal.

### Integration Test Scenarios

1. **Pre-flight enforcement flow**: Run `/gsd:execute-phase` without a PREFLIGHT file present → CARL rule should warn; Check 18 at END should show `[!!]` warning with phase name.

2. **SPARC end-to-end**: Run `/sparc "add validation to user model"` → verify `.claude/workspace/sparc-spec.md`, `sparc-pseudo.md`, `sparc-arch.md` created; Phase 5 produces GO/NO-GO verdict.

3. **AgentDB cross-project namespace**: Run `/lesson` with `cross-projet` classification → verify entry appears in both `.agentdb/entries/` (local) AND in both `project` and `global` Qdrant collections on VPS; `agentdb_search(scope="all")` returns it.

4. **AgentDB VPS failure**: Bring VPS down → run `agentdb_store` → verify local file written, error logged to `sync-errors.log`, NO exception thrown to caller; run `agentdb-reindex.sh` after VPS recovers → verify entry indexed.

5. **Session agent audit**: Run a session spawning 6 agents → restart session → verify agent-log.txt is empty; spawn 20 agents → session-gate Check 19 shows `[!!] Unusually high agent count`.

## Acceptance Criteria

### Track A

- [ ] `swarm-patterns.md` exists, < 80 lines, defines all 8 agent roles with model tier
- [ ] Pre-flight has 5 agents; Agent 5 = critic referencing `swarm-patterns.md`
- [ ] Pre-flight report includes "Architecture Challenge" and "Cross-Model Challenge" sections
- [ ] SPARC skill works end-to-end (5 phases), workspace files created per phase
- [ ] SPARC Phase 3 spawns architect + critic in parallel (both Opus/tier-3)
- [ ] SPARC Phase 4 asks once: Claude Code or Codex
- [ ] SPARC Phase 5 launches Codex adversarial + CE:review automatically → unified verdict
- [ ] CARL rule blocks /gsd:execute-phase without PREFLIGHT file (A4)
- [ ] Session-gate Check 18 detects missing PREFLIGHT, emits actionable `[!!]` message
- [ ] `execution-quality.md` has ADR auto-tracking section; total < 80 lines
- [ ] `docs/architecture/contexts.md.template` exists with placeholder structure
- [ ] `pre-agent.sh` hook exists, logs to agent-log.txt, always exit 0
- [ ] Codex plugin: `.codex/config.toml.template` copied by init-project.sh, manual install instructions printed
- [ ] `/prepare-phase` orchestrates discuss → plan → deepen? → pre-flight → returns report
- [ ] `/todo` skill: create, close, done, validate, list — all functional, IDs sequential
- [ ] CARL rule forbids Write direct to `todos/` (A17)
- [ ] `CLAUDE.md.template` < 200 lines; Supermemory references replaced by AgentDB; SPARC workflow documented

### Track B

- [ ] VPS: Qdrant + embedding service + API running via docker-compose
- [ ] API: 5 endpoints (store, search, list, delete, reindex) functional
- [ ] MCP thin client: 5 tools (agentdb_store, agentdb_search, agentdb_list, agentdb_delete, agentdb_debug)
- [ ] `agentdb_search` returns relevant results (score > 0.6 on known queries)
- [ ] `agentdb_debug` shows raw scores for query diagnosis
- [ ] `agentdb_store` writes local file THEN syncs VPS (same call, not separate hook)
- [ ] VPS failure: local file written, error logged, no exception thrown
- [ ] `/lesson`, `/ce:compound`, `/project-bootstrap` use AgentDB
- [ ] Cross-project namespace: classification=cross-project pushes to both project + global collections
- [ ] Migration script `scripts/migrate-supermemory.sh` migrates docs/solutions/ → .agentdb/entries/
- [ ] Supermemory MCP removed after 2-week coexistence period

## Success Metrics

- **Pre-flight compliance**: Check 18 shows 0 `[!!]` warnings in typical sessions (no skipped pre-flights)
- **Semantic memory quality**: agentdb_search returns > 0.6 score on 80%+ of known-relevant queries (vs. Supermemory noise baseline)
- **Decision capture**: DECISIONS.md grows organically during execution sessions (ADR rule working)
- **Agent discipline**: Check 19 session count ≤ 15 for typical feature work

## Risk Analysis

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Claude ignores swarm-patterns.md | High | Medium | Defense in depth: rule + CARL + hook + embedded in SPARC |
| Agent 5 makes pre-flight too slow | Medium | Low | Agent 5 sequential + fast (~30s); skip if plan trivial |
| SPARC too heavy for medium tasks | Medium | Medium | Explicit phase skip + /gsd:fast for trivials |
| VPS AgentDB down | Low | Medium | Fallback: keyword search on .agentdb/entries/ (git-tracked) |
| Bad embedding model | Low | High | Top-tier model (nomic-embed-text-v1.5); replaceable without API change |
| Colleagues don't adopt SPARC | Medium | Low | SPARC optional; real gains are in pre-flight (enforced) and AgentDB (transparent) |
| Supermemory migration loses data | Low | High | 2-week coexistence + entries git-tracked + rollback possible |
| pre-agent.sh hook slows workflow | Low | Low | exit 0 in < 1s, log only, no blocking |
| Codex not installed for a colleague | Medium | Medium | Silent skip — pre-flight and SPARC work without Codex |
| Codex review gate drains usage limits | Medium | High | Review gate OFF by default, manual activation only |

## Resource Estimates

| Phase | Effort | Prerequisite |
|-------|--------|-------------|
| Phase 1 (contract) | 0.5 session | None |
| Phase 2 B1 (VPS) | 1 session | VPS + Docker access |
| Phase 2 B2-B3 (MCP client) | 1 session | B1 |
| Phase 2 B4-B6 (skills+namespace) | 1 session | B2-B3 |
| Phase 2 B7 (deprecation) | 0.5 session | B5 + 2 weeks coexistence |
| Phase 3 A1-A2 | 1 session | Phase 1 |
| Phase 3 A3, A11, A12 | 1 session | A1, A2, A10 |
| Phase 3 A4-A8, A10, A13 | 1 session | A1-A3 |
| Phase 3 A14 | 0.5 session | A2, A13 |
| Phase 3 A16-A17 | 0.5 session | Independent |
| Phase Final A18 | 0.5 session | All Track A + B5 |
| **Total Track A** | **~5 sessions** | |
| **Total Track B** | **~3 sessions** | |

## Sources & References

### Origin

- **Origin document:** [docs/plans/2026-03-31-feat-ruflo-concepts-integration-plan.md](docs/plans/2026-03-31-feat-ruflo-concepts-integration-plan.md)
  - Key decisions carried forward: no ruflo dependencies, SPARC independent from GSD wrapper, AgentDB replaces Supermemory, Codex non-blocking
- **Architecture reference:** [docs/architecture/workflow-architecture.md](docs/architecture/workflow-architecture.md) — target state after implementation

### Internal References

- Current pre-flight: [.claude/skills/pre-flight/SKILL.md](.claude/skills/pre-flight/SKILL.md) (4 agents → 5 with A2)
- Current session-gate: [.claude/skills/session-gate/SKILL.md](.claude/skills/session-gate/SKILL.md) (17 checks → 19 with A5+A8)
- Current execution-quality: [.claude/rules/execution-quality.md](.claude/rules/execution-quality.md) (42 lines → ~57 with A6)
- Current tool-routing: [.claude/rules/tool-routing.md](.claude/rules/tool-routing.md) (unchanged by this plan)
- Session-start hook: [.claude/hooks/session-start.sh](.claude/hooks/session-start.sh) (modified by A8 to reset agent-log.txt)
