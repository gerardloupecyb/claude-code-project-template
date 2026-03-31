# Execution Quality — ce-work patterns for all executors

APPLICABILITY: These rules apply when a task modifies application code or infrastructure.
Skip for docs-only, config-only, or YAML-only changes.

PRECEDENCE: These heuristics complement the GSD commit protocol. On conflict, GSD protocol wins.

## System-Wide Test Check

Before marking a code task done, answer these 5 questions:

| Question | Action |
|----------|--------|
| **What fires when this runs?** Callbacks, middleware, observers, event handlers — trace two levels out. | Read actual code for callbacks on models you touch, middleware in the chain, `after_*` hooks. |
| **Do tests exercise the real chain?** All-mocked tests prove logic in isolation, not interaction. | Write at least one integration test with real objects through the full chain. No mocks for interacting layers. |
| **Can failure leave orphaned state?** State persisted before an external call — what if it fails? Retry duplicates? | Trace the failure path. Test that failure cleans up or retry is idempotent. |
| **What other interfaces expose this?** Mixins, DSLs, alternative entry points. | Grep for the method in related classes. If parity needed, add it now. |
| **Do error strategies align across layers?** Retry middleware + app fallback + framework handling — conflicts? | List error classes at each layer. Verify rescue list matches what lower layers raise. |

**Skip heuristic:** Leaf-node changes with no callbacks, no state persistence, no parallel interfaces — answer is "nothing fires, skip" in 10 seconds.

## Post-Deploy Monitoring

For any change touching production runtime code, document in SUMMARY.md or commit message:

- **Logs/search terms:** what to grep for
- **Metrics/dashboards:** what to watch
- **Expected healthy signal:** what normal looks like
- **Failure signal + rollback trigger:** when to act

If no runtime impact: add one line — `No monitoring needed: [reason]`

## Commit Quality Heuristics

| Commit when... | Don't commit when... |
|----------------|---------------------|
| Logical unit complete (model, service, component) | Small part of a larger unit |
| Tests pass + meaningful progress | Tests failing |
| About to switch contexts (backend to frontend) | Purely scaffolding with no behavior |
| About to attempt risky/uncertain changes | Would need a "WIP" commit message |

**Heuristic:** "Can I write a commit message that describes a complete, valuable change? If yes, commit. If the message would be 'WIP', wait."

## Decision Tracking

When making an architectural decision during execution (choice of pattern, library,
data model, API design, or rejection of an alternative), propose a DECISIONS.md
entry BEFORE continuing implementation:

| Field | Content |
|-------|---------|
| Decision | What was decided |
| Alternatives | What was considered and rejected |
| Rationale | Why this choice |
| Scope | What this affects |
| Date | Today |

Skip for trivial decisions (variable naming, formatting, imports).
Only track decisions a colleague joining next week would need to know.
