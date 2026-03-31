# Phase 1: swarm-patterns.md - Context

**Gathered:** 2026-03-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Create `.claude/rules/swarm-patterns.md` — a single file under 80 lines that documents all multi-agent conventions: 8 agent roles, 3 topology patterns, 3-tier model routing table, and SPARC phase-to-model routing table. This file auto-loads into all subagents via the `.claude/rules/` mechanism.

</domain>

<decisions>
## Implementation Decisions

### Agent roles (8 roles, SWARM-01)
All 8 roles documented in a table with: role name, responsibility, model tier, and bias/behavior:

| Rôle | Responsabilité | Model tier | Biais |
|------|---------------|------------|-------|
| `architect` | Design système, APIs, boundaries | Sonnet/Opus | Propose la meilleure solution |
| `critic` | Challenge, edge cases, over-engineering | Sonnet/Opus | Cherche activement les problèmes |
| `coder` | Implémentation, TDD | Sonnet | Best practices |
| `reviewer` | Code review structurée | Sonnet/Opus | Qualité + sécurité |
| `tester` | Tests, edge cases, couverture | Sonnet | Couverture exhaustive |
| `security-auditor` | OWASP, auth, data exposure | Sonnet/Opus | Paranoid |
| `spec-writer` | Requirements, AC mesurables | Sonnet | Clarté + traçabilité |
| `logic-planner` | Pseudocode, logique, TDD anchors | Sonnet | Structure |

### Topology patterns (3 patterns, SWARM-02)
Document 3 topology patterns, each as a named block with rules:

- **Pattern 1 — Hierarchical**: Claude = lead, subagents = workers. Lead reads outputs and synthesizes. Workers never call each other (context flooding).
- **Pattern 2 — Anti-drift**: Pass complete context in each agent prompt (subagents don't see parent context). Checkpoint after each agent: read output before spawning next. If agent returns < 3 lines or "unable to proceed" → stop chain, diagnose.
- **Pattern 3 — Shared namespace**: No magic shared memory between subagents. Convention: write outputs to `.claude/workspace/{task-id}-{agent}.md`. Subsequent agents read these files explicitly.

### 3-tier model routing (SWARM-03)
Documented as a table with tier, model, when-to-use, examples:

| Tier | Model | When | Examples |
|------|-------|------|----------|
| 1 | Haiku | Simple task, < 30% complexity | Research, formatting, grep, rename |
| 2 | Sonnet | Standard implementation (default) | Feature, bugfix, refactor, tests |
| 3 | Opus | Escalation: arbitration, security, costly decisions | Critical design, contradictions, bounded contexts |

### SPARC phase-to-model routing (SWARM-04)
Sonnet = default. Opus = escalation for arbitration and hard-to-reverse decisions. Static per phase with conditional Opus at Phase 5:

| Phase | Agent | Model | Reason |
|-------|-------|-------|--------|
| 1 Spec | spec-writer | Sonnet | Standard execution |
| 2 Pseudo | logic-planner | Sonnet | Standard execution |
| 3 Arch | architect | Opus | Structural decision |
| 3 Arch | critic | Opus | Challenge must match proposal tier |
| 4 Refine | implementation | Sonnet | Standard code |
| 5 Complete | standard review | Sonnet | Ordinary review |
| 5 Complete | critical review | Opus | If security, contradiction, or bounded context |

**Opus escalation triggers (applies to both routing tables):**
- Auth, security, permissions, or sensitive data
- Bounded contexts or API boundaries in scope
- Architect and critic contradict without clear resolution
- 2nd NO-GO on the same task
- Costly-to-reverse decision (schema, API contract, data model, orchestration)

### File budget
< 80 lines total. Tables are the primary format — they are the most token-dense format for this content. Minimal prose; every line earns its place.

### Claude's Discretion
- Section headers and internal ordering within the 80-line budget
- Whether to include an introductory line before tables or go straight to tables
- How to compress the Opus escalation conditions if needed (bullet list vs inline)

</decisions>

<specifics>
## Specific Ideas

- From the plan: "Opus partout alourdit le flow sans gain proportionnel. Sonnet couvre l'execution standard; Opus est reservé aux moments où la qualité d'arbitrage compte plus que la vitesse."
- Agent roles should be the primary reference for pre-flight (Agent 5 references `critic` role) and SPARC (Phase 3 uses `architect` + `critic`)
- The shared namespace convention (`.claude/workspace/{task-id}-{agent}.md`) must match what SPARC will use in Phase 3

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Source decisions
- `docs/plans/2026-03-31-feat-ruflo-concepts-integration-plan.md` §A1 — Full content spec for swarm-patterns.md (roles table, topology patterns, routing tables, escalation conditions)

### Requirements
- `.planning/REQUIREMENTS.md` — SWARM-01 through SWARM-05 (what must be true)

### Consuming skills (forward refs — these files don't exist yet)
- `.claude/skills/pre-flight/SKILL.md` — Will reference `critic` role (Phase 2)
- `.claude/skills/sparc/SKILL.md` — Will use architect + critic + routing table (Phase 3)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.claude/rules/` directory: already contains `execution-quality.md`, `tool-routing.md`, `flywheel-workflow.md` — same format, auto-loaded by all subagents. Pattern: plain markdown, no YAML frontmatter.

### Established Patterns
- Existing rules files use `##` sections and markdown tables. No frontmatter. Stick to the same format.
- `.claude/rules/execution-quality.md` is 43 lines — well under 80. Same target for swarm-patterns.md.

### Integration Points
- Phase 2 (pre-flight) will add `critic` agent referencing `swarm-patterns.md` by path
- Phase 3 (SPARC) will import role names and model routing from `swarm-patterns.md`

</code_context>

<deferred>
## Deferred Ideas

- A `use when` column in the role table (discussed but cut for line budget — roles + model tier is sufficient for Phase 1)
- Per-role subagent_type mapping (e.g., `architect` → `architecture-strategist`) — this is implicit from existing compound agents, not needed in the file

</deferred>

---

*Phase: 01-swarm-patterns*
*Context gathered: 2026-03-31 via discuss-phase (source: 2026-03-31-feat-ruflo-concepts-integration-plan.md)*
