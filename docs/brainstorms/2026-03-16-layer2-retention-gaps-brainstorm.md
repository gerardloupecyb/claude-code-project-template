---
date: 2026-03-16
topic: layer2-retention-gaps
---

# Layer 2 Retention Gaps — Decisions, Feedback, Cold Start, Staleness, Cross-Projet

## What We're Building

Five improvements to the template's Layer 2 (context per project) that address gaps NOT covered by the March 16 plan (context-mode improvements). These gaps are structural weaknesses in how the system retains decisions, learns from output quality, bootstraps new projects, detects stale content, and shares lessons across projects.

The March 16 plan handles tool routing, COT validation, anti-compaction hooks, and session-gate enhancements. This brainstorm covers the remaining gaps that prevent the template from truly "getting better over time."

## Why These Gaps Matter

The existing system is **reactive** (captures errors after they happen) but not **proactive** (doesn't evaluate output quality, doesn't surface past decisions, doesn't detect aging content). It also provides the least value at the start of a project (cold start) and doesn't automatically propagate learnings across projects.

**Priority order** (based on pain felt today):

1. **Gap C** — Decisions lost over time (most painful)
2. **Gap B** — No feedback loop on output quality
3. **Gap D** — Cold start / empty state
4. **Gap E** — Silent staleness
5. **Gap A** — Cross-project learning passive

## Key Decisions

### Gap C — Decisions That Get Lost Over Time

**Problem:** Decisions live in 3 disconnected places (MEMORY.md "Decisions actives" table, docs/plans/ plan files, git history). When MEMORY.md is cleaned up, old decisions disappear. Claude can't find them when revisiting a topic weeks later.

**Decision:** New `DECISIONS.md` file — lightweight ADR (Architecture Decision Record) format.

- **Format:** `DEC-NNN — Title` with Date, Context, Choice, Rejected alternatives, Status (ACTIVE/SUPERSEDED/REVOKED)
- **Cap:** ~30 active decisions. Superseded/revoked entries stay with updated status (git history has the full archive)
- **Consulted:** at planning time only (not every session — too heavy). Added to the Rule de consultation sequence: LESSONS.md (loaded) -> DECISIONS.md (read) -> recall Supermemory -> agent search docs/solutions/
- **MEMORY.md "Decisions actives"** becomes a pointer to the 3-5 most recent DECISIONS.md entries, not a standalone table
- **Capture trigger:** during closure protocol, any decision noted in MEMORY.md that isn't already in DECISIONS.md gets proposed for addition

**Rejected:** Enriching MEMORY.md with auto-archival to LESSONS.md. The quand/faire/parce que format doesn't capture "why X over Y" well — decisions and lessons are semantically different.

**Template changes required:**

| File | Action |
|------|--------|
| `DECISIONS.md.template` | NEW — ADR-light format with header and format spec |
| `CLAUDE.md.template` | MODIFY — add DECISIONS.md to file table, update Rule de consultation |
| `init-project.sh` | MODIFY — generate DECISIONS.md from template |
| `session-gate/SKILL.md` | MODIFY — add Check 13 (DECISIONS.md exists, START+END) |
| Closure protocol | MODIFY — add decision capture step |

---

### Gap B — No Feedback Loop on Output Quality

**Problem:** The system captures errors reactively (/lesson) but never evaluates whether plans, AC, or deliverables were good. Same mediocre patterns repeat without correction.

**Decision:** Mechanical quality score in the closure protocol (no new file).

After `/gsd:verify-work`, closure adds a quality check block to the SUMMARY.md:

```markdown
## Closure Quality Check
- AC coverage: X/Y AC satisfied on first pass (no rework)
- Deviations: N deviations logged during execution
- Review findings: N issues found by /ce:review (HIGH/MEDIUM)
- Verdict: CLEAN | ROUGH
```

**Verdict logic:**
- **CLEAN** = 0 deviations AND 0 HIGH review findings AND >= 80% AC first-pass
- **ROUGH** = anything else

**If ROUGH:** propose `/lesson` focused on "why the plan didn't hold" — captures the planning failure, not just the fix.

**Not doing (YAGNI):** Dual capture of success patterns. When enough CLEAN verdicts accumulate, the positive patterns will be visible in SUMMARY.md files and can be captured manually. No need to automate this yet.

**Template changes required:**

| File | Action |
|------|--------|
| `CLAUDE.md.template` | MODIFY — add quality check to closure protocol |
| `CLAUDE.md.template` | MODIFY — closure checklist step 6: quality score |

---

### Gap D — Cold Start / Empty State

**Problem:** New project = empty LESSONS.md, empty DECISIONS.md, zero project-specific CARL rules. The system provides the least value when you need it most (project start).

**Decision:** New `/project-bootstrap` skill — invoked manually after `init-project.sh`.

**What it does:**

1. Call `recall` on Supermemory with the CARL keywords of the new project
2. Filter results for `[lesson:*]` and `[skill:*]` tags
3. Inject the 5-10 most relevant lessons into LESSONS.md with `[heritage:source-project]` tag
4. Report what was injected and from which projects

**Heritage entry format:**

```markdown
### [heritage:STR] Rate limiting on third-party APIs
**Quand** integrating a third-party REST API with throttling
**Faire** implement exponential backoff from the first call
**Parce que** discovered on STR System — API cuts access for 60s after 429
_Date: 2026-02-15 | Source: STR System_
```

**Graceful degradation:**
- If Supermemory unavailable: skill reports "no cross-project lessons available" and exits cleanly
- If no relevant lessons found: same — project starts cold but accumulates normally
- Heritage entries count toward the LESSONS.md cap of 50 and migrate normally

**Not doing:** Pre-written universal lessons in the template. They'd be generic and quickly become noise. Real lessons from real projects are more valuable.

**Template changes required:**

| File | Action |
|------|--------|
| `.claude/skills/project-bootstrap/SKILL.md` | NEW — recall + inject skill |
| `init-project.sh` | MODIFY — add "run /project-bootstrap" to next steps output |
| `CLAUDE.md.template` | MODIFY — mention /project-bootstrap in workflows section |

---

### Gap E — Silent Staleness

**Problem:** Nothing detects when content ages and becomes misleading. Old decisions stay ACTIVE, old lessons go unquestioned, CARL rules may never trigger.

**Decision:** Two informational checks in `/session-gate start` (never blocking).

**Check 13 — Stale decisions (START, informational):**

Read `DECISIONS.md`, find entries with status ACTIVE whose date > 30 days.
`[--] 3 active decisions are > 30 days old — verify if still valid`

**Check 14 — LESSONS.md last entry age (START, informational):**

Find the most recent `_Date:` in LESSONS.md.
`[--] Last lesson captured 15 days ago`

Both checks are `[--]` (informational), never `[!!]` (blocking). The simple act of seeing the age is enough to trigger a review when relevant.

**Not doing:** CARL rule staleness detection. Would require analyzing transcripts to see which keywords trigger — too complex, too rare to matter. Deferred indefinitely.

**Template changes required:**

| File | Action |
|------|--------|
| `session-gate/SKILL.md` | MODIFY — add Checks 13-14 (informational) |

---

### Gap A — Cross-Project Learning Passive

**Problem:** Supermemory contains archived lessons but Claude only consults them at planning time (Rule de consultation), and often skips it.

**Decision:** Reinforce the existing mechanism rather than add new infrastructure. Three changes:

**1. New CARL domain template rule (RULE_8):**

```
{DOMAIN_UPPER}_RULE_8=PLANNING RECALL — Before any /gsd:plan-phase, /gsd:discuss-phase, or /ce:plan, run recall on Supermemory with the top 3 domain keywords. Skip only if Supermemory unavailable. This is NOT optional — it prevents rediscovering solved problems.
```

This transforms the CLAUDE.md instruction (easily ignored in a 505-line file) into a CARL rule (auto-injected, impossible to miss).

**2. Session-gate check (START, informational):**

If MEMORY.md "Prochaine etape" contains "plan" or "planif": `[--] Planning ahead — remember to recall Supermemory before starting`

**3. /project-bootstrap (Gap D)** handles the cold start case — cross-project lessons are already injected at project creation.

**Not doing:** Automatic injection of all Supermemory lessons at every session. Too much noise, too many tokens. Targeted recall at planning time remains the right moment.

**Template changes required:**

| File | Action |
|------|--------|
| `.carl/domain.template` | MODIFY — add RULE_8 (planning recall) |
| `session-gate/SKILL.md` | MODIFY — add planning reminder check |

---

## Integration with March 16 Plan

These 5 gaps are **additive** to the 10 changes in the March 16 plan. No conflicts.

| March 16 Plan | This Brainstorm | Relationship |
|---------------|----------------|--------------|
| Change 1: tool-routing.md | Gap A: CARL RULE_8 | Both add CARL rules — sequential numbering |
| Change 4: session-gate checks 9-10 | Gaps C/E: checks 13-14 | Additive checks, same skill |
| Change 5: CARL domain RULE_6/7 | Gap A: RULE_8 | Next sequential rule |
| Change 6: hooks | Gap D: /project-bootstrap | Independent — bootstrap is a skill, not a hook |
| Closure protocol (existing) | Gap B: quality score | Extends closure, doesn't replace |

**Recommended execution order:**
1. Execute March 16 plan first (foundation: hooks, routing, COT, session-gate 9-10)
2. Then implement these 5 gaps in priority order (C, B, D, E, A)

---

## Summary of New Template Artifacts

| Artifact | Type | Gap |
|----------|------|-----|
| `DECISIONS.md.template` | New file | C |
| `.claude/skills/project-bootstrap/SKILL.md` | New skill | D |
| Quality score in closure protocol | CLAUDE.md modification | B |
| Session-gate checks 13-14 | Skill modification | C, E |
| CARL domain RULE_8 | Template modification | A |
| Session-gate planning reminder | Skill modification | A |

## Open Questions

None — all approaches were validated during the brainstorming dialogue.

## Next Steps

-> `/ce:plan` to create implementation plan for all 5 gaps
-> Execute after the March 16 plan is implemented (dependency on session-gate having checks 9-10 first)
