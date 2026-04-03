# Phase 7: Template + Init - Context

**Gathered:** 2026-04-03
**Status:** Ready for planning

<domain>
## Phase Boundary

New projects initialized from the template get all Milestone 1 enrichments wired automatically. CLAUDE.md.template must be compressed from 505 to <200 lines. init-project.sh must copy all new artifacts.

</domain>

<decisions>
## Implementation Decisions

### Gap analysis (6/7 requirements pre-satisfied)
- **D-01:** TMPL-01 (SPARC, swarm, AgentDB refs) — DONE (24 refs in CLAUDE.md.template)
- **D-02:** TMPL-02 (SPARC flow documented) — DONE (lines 85, 103, 141)
- **D-04:** TMPL-04 (init copies contexts.md.template) — DONE (4 refs in init-project.sh)
- **D-05:** TMPL-05 (init copies pre-agent.sh) — DONE (3 refs in init-project.sh)
- **D-06:** TMPL-06 (init wires settings.json) — DONE (copies settings.json at line 181)
- **D-07:** TMPL-07 (init adds .claude/workspace/ to .gitignore) — DONE (2 refs in init-project.sh)

### Gap: TMPL-03 — CLAUDE.md.template must be < 200 lines (currently 505)

#### What STAYS in CLAUDE.md.template (~80-100 lines)
- **D-08:** Project identity: stack, active tools, MCPs, skills (lines 1-32) — essential, keep
- **D-09:** Memory files table (lines 35-48) — trim prose below table, keep table
- **D-10:** 3 workflow entry points (lines 82-106) — keep as short path summaries
- **D-11:** Closure protocol (lines 114-135) — TRIM hard but do NOT remove entirely. execution-quality.md covers execution heuristics but does NOT fully replace the closure mechanics. Compress to ~10 lines max.
- **D-12:** Session start/end contract (Rules 1-2, lines 193-231) — trim to essentials (~10 lines). Hooks auto-inject MEMORY+LESSONS, so detailed steps are redundant. Keep the contract, not the procedure.
- **D-13:** Active domains table (lines 500-505) — keep
- **D-14:** Pointers to .claude/rules/ files for everything extracted — explicit "see X for detail" lines

#### What gets EXTRACTED (merge into existing rules/ files, do NOT create new files)
- **D-15:** Prefer merging into existing .claude/rules/ files over creating new ones. Only create a new rule file if the content has no clean existing home.
- **D-16:** Rules 3-4 (COT trigger matrix, context checkpoints, lines 234-276) → merge into existing tool-routing.md or create context-discipline.md only if no fit
- **D-17:** Rules 5-7 (AgentDB format, CARL enrichment, anti-patterns, lines 278-355) → merge into flywheel-workflow.md (already has the flywheel post-/ce:compound steps)
- **D-18:** Rule 8 (plan structure, AC format, boundaries, lines 358-395) → GSD planner handles this natively; extract to planning-discipline.md only if referenced by non-GSD tools
- **D-19:** Consultation + reference rules (lines 418-444) → already in execution-quality.md Reference Layer Awareness + tool-routing.md
- **D-20:** GSD ↔ Compound coordination table (lines 447-484) → extract to a coordination.md rule file (no existing home, large table)
- **D-21:** "What agents don't do" (lines 487-498) → already duplicated in Rules 5-7, remove from CLAUDE.md
- **D-22:** Frontmatter/classification/metadata (lines 160-189) → extract to planning-discipline.md or docs convention file

### Claude's Discretion
- Exact compression/extraction decisions within the framework above
- Whether a new rule file is needed or content fits in an existing one
- Final line count target (aim for 80-100, must be <200)

</decisions>

<specifics>
## Specific Ideas

- Codex correction: "compress and preserve operator-critical closure/session behavior" — don't delete closure, trim it
- Codex correction: "prefer merge into existing rule files before creating new ones" — avoid moving bloat around
- The 505 → <200 cut means removing ~60% of the file. The strategy is: identity + entry points + contracts stay, detailed procedures + reference tables get extracted to auto-loaded rules/ files

</specifics>

<canonical_refs>
## Canonical References

### Template files
- `CLAUDE.md.template` — The file being compressed (505 lines, target <200)
- `init-project.sh` — Project initialization script (already wires most Phase 1-6 artifacts)

### Existing rules files (extraction targets)
- `.claude/rules/execution-quality.md` — 77 lines, has Reference Layer + Decision Tracking
- `.claude/rules/flywheel-workflow.md` — Has post-/ce:compound steps (AgentDB/CARL rules could merge here)
- `.claude/rules/tool-routing.md` — Has tool routing table (COT rules could merge here)
- `.claude/rules/workflow-automation.md` — Has workflow transitions
- `.claude/rules/model-routing.md` — Has model delegation rules
- `.claude/rules/swarm-patterns.md` — Agent conventions

### Pre-satisfied artifacts
- `docs/architecture/contexts.md.template` — Copied by init-project.sh
- `.claude/hooks/pre-agent.sh` — Copied by init-project.sh
- `.claude/settings.json` — Copied by init-project.sh

</canonical_refs>

<code_context>
## Existing Code Insights

### CLAUDE.md.template current structure (505 lines)
- Lines 1-32: Identity (stack, tools, MCPs, skills) — 32 lines
- Lines 35-76: Memory files + separation — 42 lines
- Lines 80-158: Workflows + closure — 79 lines
- Lines 160-189: Distinctions, metadata, classification — 30 lines
- Lines 193-276: Rules 1-4 (session, COT) — 84 lines
- Lines 278-355: Rules 5-7 (AgentDB, CARL, anti-patterns) — 78 lines
- Lines 358-395: Rule 8 (plan structure) — 38 lines
- Lines 398-444: Lesson capture + consultation — 47 lines
- Lines 447-498: Coordination + anti-patterns — 52 lines
- Lines 500-505: Domains — 6 lines

### Integration Points
- init-project.sh: may need to copy new rule files created during extraction
- .claude/rules/*.md: extraction targets for merged content

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 07-template-init*
*Context gathered: 2026-04-03*
