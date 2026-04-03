# Phase 5: Execution Quality + DDD - Context

**Gathered:** 2026-04-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Architectural decisions are auto-tracked and cross-domain boundaries are visible before modification. Most requirements already satisfied from Track A — this phase closes 2 remaining gaps.

</domain>

<decisions>
## Implementation Decisions

### Gap analysis (6/8 requirements already done)
- **D-01:** ADR-01 (Decision Tracking section) — DONE at execution-quality.md:60
- **D-02:** ADR-02 (Skip heuristic) — DONE at execution-quality.md:74
- **D-03:** DDD-01 (contexts.md.template) — DONE at docs/architecture/contexts.md.template
- **D-04:** DDD-02 (Pre-flight references contexts.md) — DONE at pre-flight/SKILL.md:118
- **D-05:** DDD-03 (SPARC references contexts.md) — DONE at sparc/SKILL.md:63
- **D-06:** DDD-05 (Agents ignore unfilled placeholders) — DONE at pre-flight/SKILL.md:118

### Gap 1: ADR-03 — execution-quality.md must be < 80 lines (currently 100)
- **D-07:** Trim by compressing prose into tighter formatting, not by removing content sections
- **D-08:** The "Reviewer Agents" section is the best candidate for compression — it's the longest section with the most prose relative to information density
- **D-09:** Keep all section headers and tables intact — they are referenced by other files
- **D-10:** Do NOT extract sections to separate files — that breaks the auto-load via .claude/rules/ mechanism

### Gap 2: DDD-04 — contexts.md check in execution-quality.md
- **D-11:** Add the check in the "Reference Layer Awareness" table — it already has the pattern of routing to reference files by task type
- **D-12:** New row: "Cross-domain change" → "docs/architecture/contexts.md" → "Check bounded contexts before modifying code that crosses domain boundaries"
- **D-13:** Add a skip heuristic: "If contexts.md contains only placeholders (unfilled template), skip this check"

### Claude's Discretion
- Exact prose compression strategy for reaching <80 lines
- Whether to tighten other sections opportunistically while trimming

</decisions>

<specifics>
## Specific Ideas

- Codex recommends keeping reviewer agents as soft triggers ("suggest, not block") — the existing section already says "Post-Phase, Optional" which matches this guidance
- The Reference Layer Awareness table is the natural home for DDD-04 — it follows the same pattern as other routing entries

</specifics>

<canonical_refs>
## Canonical References

### Execution quality file
- `.claude/rules/execution-quality.md` — The file being modified (100 lines, target <80)

### DDD context template
- `docs/architecture/contexts.md.template` — Already exists, referenced by SPARC and pre-flight

### Cross-references (already wired)
- `.claude/skills/sparc/SKILL.md` §line 63 — SPARC Phase 3 references contexts.md
- `.claude/skills/pre-flight/SKILL.md` §line 118 — Pre-flight Agent 5 references contexts.md with placeholder skip

</canonical_refs>

<code_context>
## Existing Code Insights

### Current execution-quality.md structure (100 lines)
- Lines 1-3: Header + applicability
- Lines 5-6: Precedence note
- Lines 8-28: System-Wide Test Check (5-question table + skip heuristic)
- Lines 30-40: Post-Deploy Monitoring
- Lines 42-58: Reference Layer Awareness (table + skip) ← DDD-04 goes here
- Lines 60-75: Decision Tracking (table + skip)
- Lines 77-87: Commit Quality Heuristics
- Lines 89-100: Simplify As You Go + Reviewer Agents

### Integration Points
- Reference Layer Awareness table: add contexts.md row
- Reviewer Agents section: compress to gain most lines

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-execution-quality-ddd*
*Context gathered: 2026-04-03*
