# Cognitive Patterns — Rationalization Prevention

Grounding discipline for agent claims. Complements `verification-discipline.md` (task completion) with knowledge-grounding checks (factual claims).

## The Grounding Rule

Before asserting facts about project architecture, patterns, services, past decisions, or compliance requirements: query {{RAG_BACKEND}}. Training data may be stale. MEMORY.md may be incomplete.

## Rationalization Table

| Rationalization | Reality | Required Action |
|----------------|---------|-----------------|
| "I already know the architecture" | Training data may not reflect recent changes | Query `reference` collection |
| "It's a simple pattern, no need to check" | Simple patterns have project-specific constraints in DECISIONS.md | Query `knowledge` with kind: decision |
| "The query will be slow" | {{RAG_BACKEND}} queries return in <100ms locally | Always query |
| "I read that file earlier in this session" | Files may have been modified by other tasks | Query for current indexed version |
| "This is common knowledge" | Common knowledge may conflict with project decisions | Query `knowledge` for past decisions |
| "{{RAG_BACKEND}} is down, I'll skip" | Acceptable fallback | Read the source file directly |
| "Tant qu'à y être, je corrige aussi ça" | Le diff hors-scope masque l'intention du changement et alourdit la review | Toucher seulement les lignes nécessaires ; signaler le problème hors-scope, ne pas le corriger sans demande |
| "It might be useful later — keep the wrapper" | If deleted, does complexity reappear across N callers ? If yes, the wrapper earns its keep (locality + leverage). If only 1 caller or none — it's a pass-through that obscures intent. **Guard** : wrappers that enforce a typed contract, auth boundary, test mock point, or single-source-of-truth invariant are **seams** (cf. `docs/references/source-of-truth-map.md` § Architecture Vocabulary), not pass-throughs — keep them even with 1 caller. | Apply the deletion test before keeping a wrapper "just in case". Pass-throughs go ; seams stay. |

## When to Query

| Situation | Collection | kind filter |
|-----------|------------|-------------|
| Claiming how a system component works | `reference` | `architecture` |
| Referencing a past decision | `knowledge` | `decision` or `lesson` |
| Checking compliance requirement | `governance-ops` | `standard` |
| Understanding current phase context | `planning` | `plan` or `context` |
| Asserting "we decided X in Phase N" | `knowledge` | `decision`, filter by `phase` |

## When NOT to Query

- Greenfield code with no architectural precedent
- Formatting, styling, cosmetic changes
- Git operations, file management
- {{RAG_BACKEND}} down AND relevant file already read in session

## Multi-Question Deep-Dive Discipline

When the user stays on the same topic across multiple turns of the same session:

1. **Turn 1: query broadly** — `chroma_query_documents` with `n_results=10` (instead of default 5). Pay the upfront cost once to capture the conceptual neighborhood.
2. **Turn 2+: do not re-query** unless the question opens a **new conceptual branch** (different concept, different phase, different system, different collection).
3. **Trust conversation history** — chunks retrieved in earlier turns remain in your context window. Cite them, reason from them, ask the user for direction — do not re-query the same semantic territory.
4. **When re-query IS justified**:
   - User explicitly asks for "fresh data" or "what changed since"
   - Conversation has been compacted (>20 turns or system signal)
   - Topic genuinely shifts to a new concept/phase/system
   - User commits a new doc that should appear in retrieval

| Anti-pattern | Correct behavior |
|---|---|
| Same topic, slight rephrasing → re-query | Re-read from conversation history |
| Follow-up question → new {{RAG_BACKEND}} query each time | Acknowledge history, query only on conceptual branch change |
| "Let me also check..." reflex | Stop. Check if you already have it. |
| Re-query to "be safe" / "double check" | Cite existing chunks; if uncertain, ask user |

### Provenance

Added 2026-04-23. A brainstorm (archived in `docs/brainstorms/rejected/`) proposed a `/corpus` skill to solve repeated-query fragmentation. Gemini adversarial review showed the root cause is behavioral, not architectural — broader Turn 1 + trust history beats any caching layer for a 1-ETP shop with {{RAG_BACKEND}} in legacy/no-sync status (Phase 27).

## Integration with Verification Discipline

This file handles **factual grounding** (is the claim correct?).
`verification-discipline.md` handles **task completion** (is the work done?).
Both must pass for architecture-sensitive tasks.
