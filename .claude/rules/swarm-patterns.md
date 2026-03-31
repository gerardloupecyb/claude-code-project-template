# Swarm Patterns — Multi-Agent Conventions

Single source of truth for agent orchestration. Referenced by SPARC and pre-flight.

## Agent Roles

| Rôle | Responsabilité | Model tier | Biais |
|------|---------------|------------|-------|
| `architect` | Design système, APIs, boundaries | Opus (tier 3) | Propose la meilleure solution |
| `critic` | Challenge, edge cases, over-engineering | Opus (tier 3) | Cherche activement les problèmes |
| `coder` | Implémentation, TDD | Sonnet (tier 2) | Best practices |
| `reviewer` | Code review structurée | Sonnet/Opus | Qualité + sécurité |
| `tester` | Tests, edge cases, couverture | Sonnet (tier 2) | Couverture exhaustive |
| `security-auditor` | OWASP, auth, data exposure | Sonnet/Opus | Paranoid |
| `spec-writer` | Requirements, AC mesurables | Sonnet (tier 2) | Clarté + traçabilité |
| `logic-planner` | Pseudocode, logique, TDD anchors | Sonnet (tier 2) | Structure |

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

| Phase | Agent | Model |
|-------|-------|-------|
| 1 Spec | spec-writer | Sonnet |
| 2 Pseudo | logic-planner | Sonnet |
| 3 Arch | architect + critic | Opus |
| 4 Refine | implementation | Sonnet |
| 5 Complete — standard | reviewer | Sonnet |
| 5 Complete — security/contradiction | reviewer + critic | Opus |

Escalate to Opus when: auth/security, bounded contexts, architect↔critic contradiction unresolved,
2nd NO-GO on same task, decision costly to reverse (schema, API contract, data model).

## Limits

- Max simultaneous agents: 6-8 standard, 12 complex systems
- Each agent returns < 200 words summary (unless file output requested)
- Never spawn an agent without verifying the previous succeeded (except explicit parallel)
