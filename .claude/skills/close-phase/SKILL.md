---
name: close-phase
description: >
  Orchestrate the full closure protocol for a GSD phase post-execution.
  Runs verify-work, conditional {{project}}:review, writes phase-level SUMMARY,
  updates MEMORY.md, reconciles architecture artefacts, triages todos,
  proposes lesson/brainstorm-archival/commit-push,
  then migrates the phase folder from active/ to complete/.
  Invoke with /close-phase {N} or /close-phase {N} --partial.
  Triggers on: close-phase, close phase, closure protocol, fermer la phase.
---

# Close Phase — Closure Protocol Orchestrator

Runs the canonical closure sequence for a GSD phase after `/gsd:execute-phase` finishes.
Wrapper only — does NOT modify underlying skills (`/gsd:verify-work`, `/{{project}}:review`, `/lesson`, `/todo`, `/commit-push`).
Does NOT launch execution — assumes phase is already executed.

Source of truth for the closure protocol itself: `.claude/rules/workflow-guide.md` § Closure Protocol.

---

## Usage

- `/close-phase {N}` — interactive mode (default): full closure with soft gates
- `/close-phase {N} --partial` — mid-wave mode: log progress only, skip artifact writes + folder migration
- `/close-phase {N} --skip-review` — force skip Step 2 if review was already done manually
- `/close-phase {N} --dry-run` — print actions without executing, for audit

---

## Step 0 — Preflight Validation (auto)

```bash
PHASE_DIR=$(find .planning/phases/active -maxdepth 1 -type d -name "${N}-*" | head -1)
[ -z "$PHASE_DIR" ] && echo "Phase $N not in active/" && exit 1

# Use git -C to resolve branch from phase context, not operator cwd (BLOCK I)
PHASE_BRANCH=$(git -C "$PHASE_DIR" branch --show-current 2>/dev/null || git branch --show-current)
```

- Verify phase exists in `.planning/phases/active/`
- Verify working tree clean (warn if dirty, don't block)
- Warn if `$PHASE_BRANCH` doesn't match expected `gsd/phase-${N}-*` or `main`
- Initialize manifest file: `touch "$PHASE_DIR/.closure-manifest"` (gitignored, BLOCK G)

## Step 1 — Verify Work (auto, stop on fail)

```
/gsd:verify-work {N}
```

After completion, read `$PHASE_DIR/{N}-VERIFICATION.md` directly (do NOT parse stdout — verdict contract is the file content):

- File contains "VERDICT: PASS" → continue Step 2
- File contains "VERDICT: PARTIAL" → ask user "Address findings now or defer to SUMMARY? [now/defer]"
- File contains "VERDICT: FAIL" or file absent → STOP CHAIN, surface findings

In `--partial` mode: skip verify-work entirely (user is mid-wave, not asking for full verification).

## Step 2 — Review Trigger Evaluation (auto, conditional)

Skip entirely if `--skip-review` flag set.

```bash
DIFF_FILES=$(git diff main..HEAD --name-only | wc -l)
DIFF_PATHS_SENSITIVE=$(git diff main..HEAD --name-only | \
  grep -E '^(scripts/|\.claude/(rules|skills|hooks)/|config/.*\.json|\.mcp\.json)' | head -1)

if [ "$DIFF_FILES" -gt 3 ] || [ -n "$DIFF_PATHS_SENSITIVE" ]; then
  /{{project}}:review
  # Soft gate — no parsing of output, human judgment
  ask "/{{project}}:review complete. All P1 findings addressed or consciously deferred? [y/n]"
  [ "$answer" = "n" ] && STOP CHAIN
fi
```

No persona-based routing. No output contract parsing. User reads the report and makes the call.

## Step 3 — SUMMARY.md (auto)

In `--partial` mode: skip this step.

```
Target: $PHASE_DIR/{N}-SUMMARY.md  (phase-level, not per-plan)
```

If absent, write template covering: outcome, key decisions, deviations, open findings (if Step 2 deferred), follow-up todos.
If present, append a "Closure section" with the same fields (do not overwrite plan-level summaries `{N}-NN-SUMMARY.md`).

Add path to manifest: `echo "$PHASE_DIR/{N}-SUMMARY.md" >> "$PHASE_DIR/.closure-manifest"`

## Step 4 — MEMORY.md Update (auto)

```
Target: memory/MEMORY.md
```

- Append session entry under "Ce qui a été fait" with phase outcome
- If > 8 sessions: move oldest to `memory/archive-YYYY-MM.md`
- Use `git -C` to ensure correct repo context (BLOCK I)
- Add MEMORY.md + archive (if created) to manifest

In `--partial` mode: append wave progress entry with idempotency key `{phase}-{wave}` to avoid duplicates on re-invocation.

## Step 4b — Architecture Artefact Reconciliation (auto, conditional)

In `--partial` mode: skip this step.

The unit of architecture documentation is the durable **capability** the phase touched
(billing, cascade, ...), never the phase number. Determine the capability, then:

```bash
ARCH_RELEVANT=$(git diff main..HEAD --name-only | \
  grep -E '^({{WORKFLOW_ENGINE}}/workflows/|scripts/|infra/|src/)' | head -1)
```

- **Capability has an existing `docs/architecture/{slug}/` kit** → run
  `/architecture-kit {slug} --update` — reconciles artefacts with what was actually
  built (update mode reads this phase's SUMMARY for deviations).
- **Phase delivered a new capability with NO kit** → do NOT skip silently. Prompt:
  "Phase delivered capability `{X}` with no architecture kit. Generate one now?
  [y/defer]". On defer, log the gap to the SUMMARY follow-up todos.
- **Phase touched no architecture-bearing capability** (doc-only, refactor, tooling)
  → skip, no prompt.

Slug is a durable feature name, never a phase number — see
`.claude/skills/architecture-kit/SKILL.md` § Slug Discipline. Add modified artefacts to manifest.

## Step 5 — GOVERNANCE Index Update (auto, conditional)

```bash
GOV_DOCS_CHANGED=$(git diff main..HEAD --name-only | \
  grep -E '^docs/(standards|procedures|runbooks|references|architecture)/.*\.md$' | head -1)
```

If non-empty: prompt user "Governance docs changed. Verify `docs/GOVERNANCE.md` reflects new/superseded entries?"
- User confirms updated → add to manifest
- User defers → log warning, continue

Per `.claude/rules/governance-index-discipline.md`.

## Step 6 — /todo stale Triage (auto)

```
/todo stale --phase {N}
```

Auto-triage todos with `phase: {N}` frontmatter that are still pending. Stale ones get prompted for close/defer/move.

## Step 7 — Multi-Select End-of-Closure (1 question, user choice)

```
"Closure 90% complete. Select follow-up actions :
  [ ] Capture /lesson — non-trivial pattern emerged?
  [ ] Archive linked brainstorm — git mv to docs/brainstorms/archived/
  [x] /commit-push — commit all closure artifacts (default checked)
Confirm selection? [y/n/edit]"
```

Replaces 3 separate questions from v1 design.

For each selected item:
- `/lesson` → invoke skill, append to LESSONS.md
- Brainstorm archival → detect linked brainstorm via phase CONTEXT.md `origin:` field, `git mv` to `archived/` + frontmatter update
- `/commit-push` → see Step 8

## Step 8 — Branch-Aware Commit-Push (auto if selected in Step 7)

```bash
CURRENT_BRANCH=$(git -C "$PHASE_DIR" branch --show-current)

# Use --pathspec-from-file for robust manifest passing (BLOCK G refined)
if [ "$CURRENT_BRANCH" = "main" ]; then
  /commit-push --pathspec-from-file "$PHASE_DIR/.closure-manifest"
else
  ask "On branch $CURRENT_BRANCH. Merge strategy?
       [merge-no-ff / squash / push-sandbox-only / skip]"
  case "$strategy" in
    merge-no-ff)        git checkout main && git merge --no-ff "$CURRENT_BRANCH" && /commit-push ;;
    squash)             git checkout main && git merge --squash "$CURRENT_BRANCH" && /commit-push ;;
    push-sandbox-only)  git push origin "$CURRENT_BRANCH" ;;
    skip)               echo "No push. Closure artifacts committed locally only." ;;
  esac
fi
```

No structural decision baked in — operator chooses merge strategy per phase.

## Step 9 — Folder Migration (auto, canonical closure signal)

In `--partial` mode: skip this step.

```bash
git -C "$PHASE_DIR" mv "$PHASE_DIR" .planning/phases/complete/$(basename "$PHASE_DIR")
```

`active/ → complete/` migration is the canonical signal that the phase is fully closed. This is what Phase 12 and earlier closed phases did. No marker file needed — git history is the source of truth.

Add the move to manifest if not yet committed.

## Step 10 — Self-Feedback Draft (1 question, opt-in)

If any subagent or skill diverged from expected behavior during this run (subjective assessment by orchestrator), prompt:

```
"Observed deviation during closure:
  [draft entry for memory/agents-feedback.md § Closure orchestration]
Add to agents-feedback.md? [y/edit/skip]"
```

Draft-only. User confirms before write. Per `governance.md` enforcement table.

---

## Modes

| Mode | Skipped steps | Use case |
|------|---------------|----------|
| Default | none | Full phase closure |
| `--partial` | 3, 4b, 5, 9 | Mid-wave, log progress only, no folder migration |
| `--skip-review` | 2 | Review already done manually outside closure |
| `--dry-run` | all writes | Audit what would happen |

---

## Behavior Rules

- Each step waits for the previous to complete; stop chain on error
- All `git` commands use `git -C "$PHASE_DIR"` to resolve correct context in multi-worktree (BLOCK I)
- Path manifest persisted to disk file, not shell variable (BLOCK G)
- No parsing of `/{{project}}:review` output (BLOCK #5 round 1)
- No persona-based routing (BLOCK #3 round 1)
- No `/knowledge-sync` invocation — post-commit hook handles {{RAG_BACKEND}} sync (BLOCK J)
- No `/graphify` invocation — post-commit hook handles graph updates
- Step 8 (`/commit-push`) is always a user-confirmed action
- Step 10 self-feedback is draft-only, never auto-write
- `--partial` mode is idempotent: re-invocable as full close after final wave

## What This Skill Does NOT Do

- Launch `/gsd:execute-phase` (separate command — closure is post-execution only)
- Auto-fix `/{{project}}:review` findings (human judgment, soft gate only)
- Parse review output by persona or schema (no machine contract)
- Block any operation mechanically (enforcement hook is a separate, deferred component)
- Modify upstream GSD skills (wrapper-only)
- Touch other phases or worktrees

## Related Sources

- Closure protocol canonical: `.claude/rules/workflow-guide.md` § Closure Protocol
- Worktree discipline: `.claude/rules/parallel-worktree-discipline.md`
- Governance index obligation: `.claude/rules/governance-index-discipline.md`
- Verification iron law: `.claude/rules/verification-discipline.md`
- Wrapper pattern (sibling): `.claude/skills/prepare-phase/SKILL.md`

## Future Work (Phase B — deferred)

A `post-execute-phase-closure.sh` hook is designed to mechanically enforce closure invocation. Deferred until this skill is validated on 2-3 real phase closures. See `.claude/workspace/execute-phase-design-2026-05-12-v2.md` for the hook design + round-2 corrections (folder migration as signal, exempt-matrix corrections, SHA-bound markers, scope to current branch).
