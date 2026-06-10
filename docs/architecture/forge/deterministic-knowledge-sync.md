---
forge_pattern: "deterministic-knowledge-sync"
category: "knowledge-management"
reusability: "high"
maturity: "implemented"
authored: "2026-04-12"
implementation_phase: "graphify integration"
---

# FORGE Pattern: Deterministic Knowledge Sync

## Problem

Knowledge graphs and semantic indexes ({{RAG_BACKEND}}, graphify, vector stores) require synchronization with the codebase. The naive approach runs LLM extraction on every change — expensive, slow, and non-deterministic. If sync requires manual intervention, the graph drifts and loses value. If it depends on LLM tokens, it becomes a cost center that scales with commit frequency.

The pattern `deterministic-knowledge-sync` solves this by splitting sync into two tiers: a **deterministic tier** (zero LLM, zero cost, fully automated) that handles ~80% of relationships, and an **optional semantic tier** (LLM, ad-hoc) for the remaining ~20% of deep cross-document relationships.

## When to use this pattern

- Any project with a knowledge graph or semantic index that must stay current
- Projects where developers commit frequently (10+ commits/day) and can't afford LLM cost per commit
- Agentic environments where the graph is consumed by AI agents at session start — staleness directly impacts output quality

## When NOT to use this pattern

- Projects with < 50 files where full re-indexing is cheap (just rebuild from scratch each time)
- Read-only knowledge bases that don't change (no sync needed)
- Environments where LLM cost per commit is acceptable (< $0.01/commit)

## Generic architecture

### Two-tier sync model

```
                      DETERMINISTIC TIER (automatic, 0 LLM)
                ┌───────────────────────────────────────────┐
                │                                           │
  Code change → │  AST extraction (tree-sitter)             │ → graph.json
                │  Nodes: functions, classes, modules        │
                │  Edges: imports, calls, inheritance        │
                │                                           │
  Doc change →  │  Structural extraction (regex)            │ → graph.json
                │  Nodes: headings, file-level entries       │
                │  Edges: markdown links, cross-references   │
                │                                           │
                └───────────────────────────────────────────┘
                              triggered by:
                    post-commit hook + fsevents watch


                      SEMANTIC TIER (manual, LLM tokens)
                ┌───────────────────────────────────────────┐
                │                                           │
  /graphify     │  LLM semantic extraction                  │ → graph.json
  --update      │  Nodes: concepts, decisions, rationale     │
                │  Edges: semantically_similar_to,           │
                │         rationale_for, shared_data_with    │
                │                                           │
                └───────────────────────────────────────────┘
                              triggered by:
                    manual invocation (optional enrichment)
```

### Trigger points (defense in depth)

| Trigger | Scope | Latency | Cost |
|---|---|---|---|
| **Watch (fsevents)** | Real-time file saves | 1-3s | 0 |
| **Post-commit hook** | Every git commit | 1-5s async | 0 |
| **Session-start hook** | Launches watch if not running | ~0s | 0 |
| **Skill integration** | Architecture-kit, closure protocol | In workflow | 0 (structural) or LLM (semantic) |
| **Manual /graphify --update** | Deep semantic enrichment | 30-120s | LLM tokens |

Four automatic triggers ensure no single point of failure. If watch dies, post-commit catches it. If post-commit is skipped (rebase, cherry-pick), session-start relaunches watch.

### What each tier extracts

| Source type | Deterministic tier | Semantic tier (optional) |
|---|---|---|
| Code (.py, .ps1, .js, etc.) | Functions, classes, imports, call chains (tree-sitter AST) | Cross-file coupling, shared data patterns, architectural groupings |
| Docs (.md) | Headings as nodes, markdown links as edges, frontmatter metadata | Conceptual relationships, decision rationale, cross-doc semantic similarity |
| Images | Nothing | Vision-based content extraction |

**Coverage estimate**: deterministic tier captures ~80% of structural relationships. The remaining ~20% (semantic similarity, rationale edges, inferred couplings) requires LLM.

## Implementation checklist

For any project adopting this pattern:

1. **Post-commit hook**: detect changed files by extension, run AST (code) + structural regex (docs), merge into existing graph, re-cluster
2. **Watch process**: launch at session start via hook, use OS-native file watching (fsevents macOS, inotify Linux), debounce to avoid per-keystroke rebuilds
3. **Session-start hook**: check if watch is running (`pgrep`), launch if not, skip if graph doesn't exist yet (first build is manual)
4. **Sensitive file exclusion**: `.env`, credentials files, and volatile files (MEMORY.md, LESSONS.md) should be excluded from the doc extraction
5. **Skill integration**: wire graph sync into any skill that creates or modifies indexed documents (architecture-kit, knowledge-sync, etc.)
6. **Semantic tier**: keep available as manual command for optional deep enrichment, but never make it required for the graph to be useful

## {{PROJECT}} implementation

| Component | File | Role |
|---|---|---|
| Post-commit hook | `.githooks/post-commit` | AST (code) + structural (docs) on each commit |
| Watch | `session-start.sh` → `graphify.watch` | Real-time AST rebuild via fsevents |
| Session auto-start | `.claude/hooks/session-start.sh` | Launches watch if not running |
| Architecture-kit | `.claude/skills/architecture-kit/SKILL.md` Step 6 | Syncs new arch artefacts |
| Closure protocol | `.claude/rules/workflow-guide.md` Step 7b | Syncs modified arch docs |
| Semantic enrichment | `/graphify --update` | Manual, optional |

## Design decisions

| Decision | Rationale | Alternative rejected |
|---|---|---|
| Deterministic first, LLM optional | Zero cost automation covers 80% of value — LLM enrichment is diminishing returns | LLM-first (expensive at scale, non-deterministic, blocks on API latency) |
| Post-commit + watch (dual) | Defense in depth — watch catches saves, post-commit catches commits | Post-commit only (misses unsaved work during session), watch only (dies between sessions) |
| Session-start auto-launch watch | Zero manual intervention across sessions | Manual watch launch (forgotten = stale graph) |
| Exclude sensitive docs | MEMORY.md, LESSONS.md, services-and-access.md change frequently and contain sensitive data | Index everything (security risk + noise) |
| Debounce watch (3s) | Prevents rebuild per keystroke when agent writes 10 files in sequence | No debounce (wastes CPU on intermediate states) |

## Complementary patterns

- `supply-chain-audit-triad` — gates what enters the repo; this pattern keeps the knowledge graph current with what's already in
- `upstream-source-watcher` — monitors external law/framework changes; this pattern monitors internal code/doc changes
- `artifact-staleness-watcher` — detects stale docs by timestamp; this pattern keeps the graph structurally synchronized
