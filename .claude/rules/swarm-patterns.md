# Swarm Patterns — Multi-Agent Conventions

Single source of truth for agent orchestration. Referenced by SPARC and pre-flight.

## Agent Roles

| Role | Responsabilite | Model tier | Biais |
|------|---------------|------------|-------|
| `architect` | Design systeme, APIs, boundaries | Sonnet/Opus | Propose la meilleure solution |
| `critic` | Challenge, edge cases, over-engineering | Sonnet/Opus | Cherche activement les problemes |
| `coder` | Implementation, TDD | Sonnet | Best practices |
| `reviewer` | Code review structuree | Sonnet/Opus | Qualite + securite |
| `tester` | Tests, edge cases, couverture | Sonnet | Couverture exhaustive |
| `security-auditor` | OWASP, auth, data exposure | Sonnet/Opus | Paranoid |
| `spec-writer` | Requirements, AC mesurables | Sonnet | Clarte + tracabilite |
| `logic-planner` | Pseudocode, logique, TDD anchors | Sonnet | Structure |

critic defaults to Sonnet; escalates to Opus per escalation triggers below.

## Topology and Anti-Drift

**Pattern 1 — Hierarchical**: Claude principal = lead, subagents = workers.
Lead reads outputs and synthesizes. Workers NEVER call each other (context flooding).

**Pattern 2 — Anti-drift**:
- Always pass full context in each agent prompt (subagents don't read parent context)
- Checkpoint after each agent: read output before spawning next
- Agent returns < 3 lines or "unable to proceed" → stop chain, diagnose

**Pattern 3 — Shared namespace**:
- No magic shared memory between subagents
- Convention: write outputs to `.claude/workspace/{task-id}-{agent}.md`
- Subsequent agents read those files explicitly

## Model Routing

| Tier | Model | When | Examples |
|------|-------|------|---------|
| 1 | Haiku | Simple task < 30% complexity | Search, formatting, grep, rename |
| 2 | Sonnet | Standard implementation (default) | Feature, bugfix, refactor, tests |
| 3 | Opus | Escalation: arbitration, security, costly decisions | Critical design, contradictions, bounded contexts |

**SPARC routing by phase:**

| Phase | Agent | Model | Reason |
|-------|-------|-------|--------|
| 1 Spec | spec-writer | Sonnet | Standard execution |
| 2 Pseudo | logic-planner | Sonnet | Standard execution |
| 3 Arch | architect | Opus | Structural decision |
| 3 Arch | critic | Opus | Challenge must match proposal tier |
| 4 Refine | implementation | Sonnet | Standard code |
| 5 Complete | reviewer | Sonnet | Ordinary review |
| 5 Complete | reviewer + critic | Opus | If security, contradiction, or bounded context |

**Escalate to Opus when:**
- Auth, security, permissions, or sensitive data
- Bounded contexts or API boundaries in scope
- Architect and critic contradict without clear resolution
- 2nd NO-GO on the same task
- Costly-to-reverse decision (schema, API contract, data model, orchestration)

## Limits

- Max simultaneous agents: 6-8 standard, 12 complex systems
- Each agent returns < 200 words summary (unless file output requested)
- Never spawn an agent without verifying the previous succeeded (except explicit parallel)
