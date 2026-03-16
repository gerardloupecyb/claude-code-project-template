---
title: "feat: Context management improvements inspired by context-mode"
type: feat
status: active
date: 2026-03-16
deepened: 2026-03-16
deepened_v2: 2026-03-16
---

# feat: Context Management Improvements — Bash Routing, COT Validation, Anti-Compaction

## Enhancement Summary

**Deepened v2:** 2026-03-16
**Research agents used:** 7 parallel agents — context-manager skill, session-gate skill, CARL domain template, init-project.sh integration, CLAUDE.md budget, spec-flow analyzer, hook architecture research

### Key improvements from v2 deepening

1. **CARL numbering corrected** — Last active rule is RULE_5 (not RULE_7). New rules become **RULE_6 and RULE_7** (not 8/9). Alternative: move to GLOBAL domain since they're project-agnostic.
2. **Check 9 target fixed** — `PLAN.md` does not exist in the template. Plans live in `docs/plans/*-plan.md`. Check 9 must target `docs/plans/*-plan.md` via `git diff --name-only`, not a root `PLAN.md`.
3. **CLAUDE.md +10 line budget is NOT achievable** — Rule #4 replacement alone is +12 net lines. Solution: extract flywheel section (77 lines) to `.claude/rules/flywheel-workflow.md` to offset, bringing template closer to the 200-line target.
4. **Hook stdin contract fully specified** — PreCompact receives `{session_id, transcript_path, cwd, permission_mode, hook_event_name, trigger, custom_instructions}`. SessionStart receives `{session_id, transcript_path, cwd, permission_mode, hook_event_name, source, model}`.
5. **`set -euo pipefail` contradicts `exit 0`** — Resolved: use `trap 'exit 0' EXIT` with selective `|| true`, not `set -e`.
6. **SessionStart missing matchers** — Must add `resume` and `clear` matchers (4 total, not 2).
7. **COT precedence clarified** — Override > Skip > 2-of-5 triggers. Explicit hierarchy prevents nondeterministic behavior.
8. **settings.json vs settings.local.json** — Hooks go in `settings.json` (committed, shared). Permissions stay in `settings.local.json` (personal). init-project.sh creates a new `settings.json` for hooks.
9. **pre-compact.sh git scope** — Only `git add memory/MEMORY.md LESSONS.md`, never `git add .` to prevent staging partially-written files.
10. **MEMORY.md.template needs markers** — Add `<!-- pre-compact snapshot -->` markers in template for pre-compact.sh to replace content between.
11. **context-manager skill needs 5 updates** — Hook auto-injection replaces manual read, delegate to `/context-checkpoint`, add references to tool-routing.md and hooks.
12. **Hook scripts don't need `.template` suffix** — No `{{PLACEHOLDER}}` variables. Plain `.sh` files copied directly.

### New considerations discovered (v2)

- SessionStart `source` field has 4 values: `startup`, `resume`, `clear`, `compact` — plan originally only handled 2
- `PostCompact` event now exists in Claude Code (provides `compact_summary`), but SessionStart with `compact` matcher achieves same goal
- `CLAUDE_ENV_FILE` env var available in SessionStart for persisting env vars across sessions
- Hook default timeout is 600s (10 minutes); SessionEnd is 1.5s; multiple hooks per event run in parallel
- Exit code 2 = non-blocking with stderr shown; exit 1/3+ = stderr in verbose mode only
- Matcher is a **regex pattern** — `""` matches all, `"Edit|Write"` matches either, full regex supported
- Existing projects (Loupe Technologies, Healthcare Ads) have NO upgrade path — major gap requiring separate `upgrade-project.sh` or manual guide
- LESSONS.md entry counting: `### ` headings inside HTML comments would be false positives — count only outside `<!-- -->` blocks

---

## Overview

Incorporate the strongest patterns from [`mksglu/context-mode`](https://github.com/mksglu/context-mode) into the project template to address two chronic failure modes: **context window flooding** (raw tool output wasting tokens) and **chain-of-thought degradation** (no enforcement that reasoning was externalized before execution). These improvements require no new dependencies — they are instruction and skill-level changes only.

The reference repo achieves **98% context reduction** (315 KB raw → 5.4 KB consumed) by sandboxing tool output. While we will not install the full MCP server, we can adopt its instruction patterns, routing discipline, and anti-compaction snapshot structure into our existing template architecture.

> **Clarification from research:** The 98% reduction applies to native tool flooding (Bash, WebFetch, Read, Playwright). The primary flooding risk for this template is **MCP response flooding**, which bypasses context-mode's sandbox entirely. The real protections are: (1) routing rules with named anti-patterns, (2) MCP call discipline, and (3) PreCompact/SessionStart hooks for anti-compaction.

---

## Problem Statement / Motivation

### Current gaps (confirmed by repo research)

| Gap | Where | Impact |
|-----|--------|--------|
| No tool routing rules | `CLAUDE.md.template` | Claude defaults to Bash for analysis tasks; raw `git log`, `grep -r`, `cat large-file` flood context |
| Anti-patterns unnamed | `CLAUDE.md.template` | Forbidden patterns exist implicitly; no cost quantification |
| CLAUDE.md already 505 lines | `CLAUDE.md.template` | Anthropic confirms adherence degrades >200 lines — adding inline routing worsens this |
| No MCP discipline rules | `CLAUDE.md.template` | MCP hard cap is 25K tokens/response; `list_mail_messages` without `$top` = 30K–60K tokens |
| COT block has no validation | `session-gate/skill.md` | Rule #4 mandates `## Raisonnement` but nothing checks it was done |
| Blanket COT triggers | `CLAUDE.md.template` | Forcing COT on simple tasks causes overhead with no gain on Claude 4.6 |
| `/context-checkpoint` missing | skills/ | Rule #3 checkpoint procedure has no skill — depends on Claude's self-awareness |
| No anti-compaction hooks | `settings.json` | After compaction, Claude restarts cold — MEMORY.md not auto-reinjected |
| CARL domain has no routing rule | `.carl/domain.template` | Tool routing discipline not part of every project's baseline |
| LESSONS.md quality not checked | `session-gate/skill.md` | File existence passes check #8; a one-line stub would not be flagged |

---

## Proposed Solution (Option A — Local, No Dependencies)

Seven targeted changes, each independently deployable:

### Change 1 — New File `.claude/rules/tool-routing.md`: Routing Table + Anti-patterns

**Why not CLAUDE.md.template?** Anthropic's official docs state: "Files over 200 lines reduce adherence." CLAUDE.md.template is already 505 lines. Adding routing content would worsen this. Instead, use `.claude/rules/` path-scoped rule files — Claude Code loads these automatically for relevant paths. This is the recommended pattern for domain-specific rules.

Create `.claude/rules/tool-routing.md` with:

- **Bash whitelist** — safe commands that can run inline
- **Routing decision table** — `Situation | Correct Tool | Anti-pattern`
- **Token cost table** — quantified costs for named anti-patterns
- **Output constraint rules** — ≤ 500 words prose; artifacts to files
- **MCP discipline** — per-tool limit parameters (merged from Change 7)

**CLAUDE.md.template changes (minimal):** Add one line to the preamble: "Routing discipline: see `.claude/rules/tool-routing.md`." This keeps CLAUDE.md lean while ensuring the rules exist.

#### Research Insights (v2)

**Best placement in CLAUDE.md.template:** After line 13 (after CARL entry in "Outils actifs" section), add: `- Discipline outils : voir .claude/rules/tool-routing.md`

**CLAUDE.md line budget opportunity:** Extract the flywheel section (lines 352-428, 77 lines) to `.claude/rules/flywheel-workflow.md`. This alone brings CLAUDE.md from 505 to ~430 lines AND offsets all net additions from Changes 1-4. Other extraction candidates: Supermemory rule (lines 218-257, -38 lines), plan structure rule (lines 298-335, -36 lines).

**Files to create:**

- `.claude/rules/tool-routing.md` (plain file, no template placeholders needed)
- `.claude/rules/flywheel-workflow.md` (extracted from CLAUDE.md.template to reduce line count)
- Update `init-project.sh` to create `.claude/rules/` dir and copy both files
- Minimal reference added to `CLAUDE.md.template`

**Content for `.claude/rules/tool-routing.md`:**

```markdown
# Routing des outils — prévention du context flooding

IMPORTANT : Le context window se remplit vite et les performances se dégradent.
Chaque tool call a un coût. Toujours utiliser le bon outil.

## Table de routing

| Situation | Outil correct | Anti-pattern — NE PAS faire |
|-----------|--------------|----------------------------|
| Lire un fichier connu | `Read` (offset/limit si > 500 lignes) | `Bash(cat file)` |
| Chercher des fichiers par nom | `Glob` | `Bash(find . -name ...)` |
| Chercher du contenu dans le code | `Grep` | `Bash(grep -r / rg)` sans cap |
| Commandes git courtes (add, commit, status) | `Bash` direct | — |
| `git log` / `git diff` | `Bash(git log --oneline -20)` — TOUJOURS avec flag de cap | `git log` brut = 2K–10K tokens |
| Fetch de documentation web | `WebFetch` | `Bash(curl url)` = HTML brut ~12K tokens |
| Investigation multi-fichiers | `Agent` → retourne résumé ≤ 200 mots | Lire tous les fichiers en main session |
| MCP retournant > 20 lignes | Extraire champs utiles seulement | Ré-énoncer la réponse MCP complète |
| Playwright browser_snapshot | TOUJOURS passer `filename` param | Sans filename = ~135K tokens |

## Coûts de référence

| Anti-pattern | Coût token estimé |
|-------------|------------------|
| `browser_snapshot()` sans filename | ~135 000 tokens |
| `git log` brut sur repo mature | 2 000–10 000 tokens |
| `curl url` (retourne HTML) | ~12 500 tokens |
| `cat` fichier JSON 100KB | ~25 000 tokens |
| `list_mail_messages` sans `$top`/`$select` | 30 000–60 000 tokens |
| `quickbooks query` sans MAXRESULTS | jusqu'à 25 000 tokens |
| CLAUDE.md > 200 lignes | Dégradation d'adhérence — ne pas dépasser |

## Anti-patterns — NEVER

- Ne jamais lancer `git log`, `git diff`, `find`, `grep -r` sans flag de cap
- Ne jamais faire `Bash(curl url)` — utiliser `WebFetch`
- Ne jamais laisser un subagent retourner plus qu'un résumé de 200 mots
- Ne jamais faire `browser_snapshot()` sans `filename` param
- Réponses prose : max ~500 mots sauf demande explicite
- Plans, specs, blocs de code > 50 lignes → écrire dans un fichier, retourner le chemin

## Discipline MCP — limit parameters par outil

| Outil | Paramètre | Valeur recommandée |
|-------|-----------|-------------------|
| `mcp__ms365__list_mail_*` | `$top` + `$select` | `$top=20&$select=subject,from,receivedDateTime` |
| `mcp__quickbooks__query` | `MAXRESULTS` dans la requête SQL | `MAXRESULTS 25` |
| `mcp__airtable__list_records` | `maxRecords` | `20` exploration, `100` max export |
| `mcp__linear__list_issues` | `first` | `25` |
| `mcp__azure-mcp__*` | filtre par resource group | Obligatoire — jamais scope subscription entier |
| `mcp__n8n-mcp__n8n_list_workflows` | aucun natif | Déléguer à subagent avec résumé ≤ 10 lignes |
| `mcp__prod-ghl-mcp__contacts_get-contacts` | `limit` | `20` — jamais appel sans filtre |
| `mcp__google-analytics__run_report` | `limit` + date range | `limit=25`, date range ≤ 30 jours |

Si aucun paramètre de limite disponible → subagent obligatoire avec contrat de retour explicite :
"retourne une table avec colonnes [X, Y, Z], max 10 lignes"

## Ajout de nouveaux MCP — mise à jour obligatoire

Après chaque `claude mcp add <name>`, mettre à jour cette table :
1. Identifier le paramètre de limite natif du nouveau MCP (`limit`, `maxResults`, `first`, `$top`, etc.)
2. Ajouter une ligne dans la table ci-dessus avec la valeur recommandée
3. Si aucun paramètre natif → documenter "subagent obligatoire" dans la table
```

### Change 2 — `CLAUDE.md.template`: Strengthen Rule #4 (COT) with Refined Triggers

**Research finding:** Blanket COT on Claude 4.6 can increase latency 35–600% with marginal gain — the model already reasons internally. COT externalization helps most for multi-step agentic tasks with tool calls. Use a 2-of-5 condition threshold.

Update Rule #4 (currently at lines 195-215 of CLAUDE.md.template) with:

**Trigger: mandatory when 2 or more of these conditions are true:**

1. Change touches more than 1 file
2. Estimated implementation > 50 LOC
3. Task involves a decision between 2+ approaches
4. Change affects a shared interface (API, schema, event bus, CARL domain)
5. Destructive or irreversible operation (migration, delete, force-push)

**Single-condition override (always trigger regardless):**

- Chain of > 3 sequential tool calls
- Any Agent spawn for investigation
- Explicit user request for a plan

**Skip conditions (no COT needed):**

- Single-file fix < 50 LOC with identified root cause
- Pure formatting, renaming, or linting
- Tasks where user already provided the full plan

#### Research Insights (v2): COT Precedence

**Precedence order (resolves conflicts when multiple categories apply):**
1. **Override** (highest) — always trigger, period
2. **Skip** — if an override isn't active AND skip condition matches, no COT
3. **2-of-5 triggers** (default) — evaluate when neither override nor skip applies

Example: "Rename a variable across 8 files" — no override active, skip matches ("pure renaming"), so no COT despite touching 8 files. But "Rename a method that's part of the public API across 8 files" — override doesn't match, skip doesn't match (it's not pure renaming, it's API surface), 2-of-5 triggers (multi-file + shared interface) → COT required.

**Mechanical format (greppable via `grep -q "<plan>"`):**

```xml
<plan>
  <problem>One-sentence statement of what changes and why</problem>
  <files>[list of files that will be touched]</files>
  <approach>2–3 sentences on the strategy chosen</approach>
  <rejected>[Alternative considered and discarded, with reason]</rejected>
  <risks>What could break or regress</risks>
</plan>
```

**Validation (for session-gate Check 9):** `grep -q "<plan>" docs/plans/*-plan.md` — targets actual plan files, not a nonexistent root `PLAN.md`.

#### Research Insights (v2): Line Budget

Current Rule #4 is 21 lines (195-215). The replacement with trigger conditions + precedence + format is ~25 lines. Net delta: **+4 lines** (manageable if flywheel extraction from Change 1 offsets it).

**Files to modify:**

- `CLAUDE.md.template` — Rule #4 trigger conditions + format update (lines 195-215)

### Change 3 — New Skill: `/context-checkpoint`

Create `.claude/skills/context-checkpoint/SKILL.md`. This skill automates the Rule #3 checkpoint procedure:

**Trigger:** User types `/context-checkpoint` only. ~~Claude detects context nearing threshold~~ removed — Claude cannot measure context consumption percentage; no API exists for this. The skill is manual-only.

#### Research Insights (v2): Detection Limitation

Claude Code does not expose context window usage to the model. The `~60-70%` threshold in Rule #3 relies on behavioral cues (repetition, imprecision) not measurable metrics. The skill cannot auto-trigger. Instead, Rule #3's signal description ("Claude annonce 'Contexte à [X]%'") should be softened to "Claude annonce 'Contexte potentiellement saturé — checkpoint recommandé'" without claiming a specific percentage.

**Procedure (automated, ≤ 5 tool calls):**

1. Write ≤ 200-word summary to MEMORY.md "Ce qui a été fait"
2. List decisions taken (bullet points)
3. Identify next task (single actionable item in "Prochaine étape")
4. Propose `/lesson` if a non-trivial fix occurred
5. Run `/session-gate end` for validation
6. Print: "Checkpoint saved. Ouvre une nouvelle session avec: `Read MEMORY.md → puis énonce ta prochaine tâche`"

#### Research Insights (v2): Relationship with context-manager

The context-manager skill (`.claude/skills/context-manager/SKILL.md`) is a lightweight pointer skill (58 lines). After this change, context-manager's "Sessions longues" section should **delegate** to `/context-checkpoint`:
- Current: "checkpoint dans MEMORY.md → nouvelle session"
- Updated: "lancer `/context-checkpoint` (automatise le checkpoint). Voir CLAUDE.md Règle #3."

This makes context-manager the **awareness layer** and context-checkpoint the **execution layer**.

**Files to create:**
- `.claude/skills/context-checkpoint/SKILL.md`
- Update `CLAUDE.md.template` Rule #3 to reference this skill (line ~192)
- Update `init-project.sh` to install the skill
- Update `.claude/skills/context-manager/SKILL.md` to delegate to `/context-checkpoint`

### Change 4 — Enhanced `session-gate/skill.md`: COT + LESSONS Quality

Add two new checks to the `end` mode. Update invocation table from "All 8" to "All 10" and section heading from "The 8 Checks" to "The 10 Checks".

**Check 9 — COT presence in modified plan files (END):**

Run `git diff --name-only HEAD` and check if any file matching `docs/plans/*-plan.md` was modified. If no plan file was modified, skip this check (not applicable).

If a plan file was modified, extract its path and run `grep -q "<plan>" <path>`.

- If `<plan>` tag found: `[ok] COT plan block present in <filename>`
- If `<plan>` tag NOT found: `[!!] <filename> modified but no <plan> block — add reasoning retroactively`

#### Research Insights (v2): Why Not PLAN.md

The template has no root `PLAN.md` file. Plans live in `docs/plans/` with dated naming. GSD creates phase plans in `.planning/`. Check 9 must use `docs/plans/*-plan.md` pattern, not a hardcoded `PLAN.md` path. For GSD plans in `.planning/`, a separate check could target `.planning/*-PLAN.md` but is out of scope here.

**Edge case: `<plan>` in documentation examples.** The plan document itself may contain `<plan>` as a template example. Mitigation: grep for `<plan>` followed by `<problem>` within 5 lines (`grep -Pzo '<plan>\s*\n\s*<problem>' <path>`). If this is too complex, accept the low false-positive rate from template examples.

**Check 10 — LESSONS.md quality (END) — informational:**

If Check 8 passed (LESSONS.md exists and is non-empty), count `### ` headings outside HTML comment blocks. Each lesson entry uses `### ` heading format.

- If count >= 3: `[--] LESSONS.md has N lesson entries`
- If count < 3: `[--] LESSONS.md has only N entries (< 3) — consider running /lesson`

This check is always informational (`[--]`), never blocking. Skip if Check 8 failed.

**Files to modify:**
- `.claude/skills/session-gate/skill.md` — add Checks 9-10, update invocation table and section heading

### Change 5 — `.carl/domain.template`: Tool Routing + MCP Discipline Rules

#### Research Insights (v2): Corrected Numbering

The domain template has active RULE_0 through RULE_5. RULE_6/7/8 are **commented-out placeholders** for project-specific rules. The plan originally proposed RULE_8/9 which would skip RULE_6/7.

**Corrected:** Add as **RULE_6** and **RULE_7** (next sequential after last active):

```
RULE_6: TOOL_ROUTING — Use Glob (file search) and Grep (content search) over Bash(find/grep). Reserve Bash for: git, mkdir, rm, mv, npm install, pip install, echo, printf. For large files, unknown-size output, or web content: use Agent or dedicated tools — never raw Bash. See .claude/rules/tool-routing.md.

RULE_7: MCP_DISCIPLINE — NEVER call list_*/query MCP tools without explicit limit/filter. Hardcoded limits: ms365 list_mail ($top=20,+$select), quickbooks query (MAXRESULTS 25), airtable list_records (maxRecords:20), azure resources (scope by resource group). For lists where result count unknown or > 30 records: delegate to subagent with explicit return contract (max 10 rows, named columns).
```

**Alternative considered:** Move these to the GLOBAL domain (`.carl/global`) since they're project-agnostic. Decided against: GLOBAL already has GLOBAL_RULE_10 (native tools) which overlaps with RULE_6. Keeping them in the domain template gives project-specific customization ability (e.g., a project could relax RULE_7 if its MCPs are low-volume).

Replace the commented-out RULE_6/7/8 placeholders with these active rules. Add new RULE_8 placeholder for project-specific use:

```
# {{CARL_DOMAIN_UPPER}}_RULE_8=
```

**Files to modify:**
- `.carl/domain.template`

### Change 6 — Native Anti-Compaction Hooks (Option A)

Add shell hooks to `.claude/settings.json` — zero dependencies, no MCP server required.

**Correct settings.json format (verified against Claude Code docs + hook architecture research):**

```json
{
  "hooks": {
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/pre-compact.sh"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/session-start.sh"
          }
        ]
      },
      {
        "matcher": "compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/session-start.sh"
          }
        ]
      },
      {
        "matcher": "resume",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/session-start.sh"
          }
        ]
      },
      {
        "matcher": "clear",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/session-start.sh"
          }
        ]
      }
    ]
  }
}
```

#### Research Insights (v2): Verified Hook Architecture

| Fact | Status | Source |
|------|--------|--------|
| `$CLAUDE_PROJECT_DIR` is canonical env var | **Confirmed** | Claude Code docs |
| PreCompact stdin format | **Verified** — `{session_id, transcript_path, cwd, permission_mode, hook_event_name, trigger, custom_instructions}` | Hook architecture research |
| SessionStart stdin format | **Verified** — `{session_id, transcript_path, cwd, permission_mode, hook_event_name, source, model}` | Hook architecture research |
| SessionStart `source` values | **4 total**: `startup`, `resume`, `clear`, `compact` | Claude Code docs — plan originally had only 2 |
| PreCompact cannot block compaction | **Confirmed** regardless of exit code | Official docs |
| Plain text stdout = additionalContext | **Confirmed** for SessionStart | Claude Code docs |
| Default hook timeout | 600 seconds | Claude Code docs |
| Multiple hooks per event | Run in parallel | Claude Code docs |
| `CLAUDE_ENV_FILE` | Available in SessionStart for persisting env vars | Hook architecture research |
| `PostCompact` event | Now exists (provides `compact_summary`), but SessionStart `compact` matcher achieves same goal | GitHub #14258 |

**Error handling resolution:** The plan originally specified both `set -euo pipefail` and "always exit 0" — these are contradictory. Resolution:

```bash
#!/bin/bash
# DO NOT use set -euo pipefail — it contradicts exit 0 requirement
trap 'exit 0' EXIT  # Guarantee exit 0 regardless of errors
```

Use selective `|| true` on individual fallible commands. The `trap` guarantees exit 0 even on unexpected errors.

**`pre-compact.sh` responsibilities:**

- Drain stdin with timeout (receives JSON, parse with `python3 -c 'import json,sys; ...' || true`)
- Extract "Prochaine étape" from MEMORY.md
- Extract last 3 git commits + dirty files
- Write ≤ 200-word snapshot block between `<!-- pre-compact snapshot -->` markers in MEMORY.md
- If markers don't exist, create them (first-run handling)
- On second+ compaction, **replace** previous snapshot (not append)
- `git add memory/MEMORY.md LESSONS.md` — **NEVER `git add .`** (prevents staging partially-written files from active agent edits)
- `git commit -m "pre-compact snapshot" || true` (silent on failure: read-only FS, locked index, detached HEAD, not a git repo)
- Always exit 0 — never blocks compaction (guaranteed by `trap`)
- Total budget: < 2 seconds

**`session-start.sh` responsibilities:**

- Read `source` field from stdin JSON with timeout (`python3 || true`)
- Construct paths: `MEMORY_FILE="$CLAUDE_PROJECT_DIR/memory/MEMORY.md"`, `LESSONS_FILE="$CLAUDE_PROJECT_DIR/LESSONS.md"`
- If `$MEMORY_FILE` exists and non-empty: print it to stdout (plain text = `additionalContext`)
- If `$LESSONS_FILE` exists: print first 10 `### ` blocks (~80 lines, entry-count based not line-count based)
- For `source == compact`: add note "Session resumed after compaction — re-read MEMORY.md above"
- For `source == clear`: add note "Context cleared — MEMORY.md re-injected"
- Silent if files don't exist (no noise on fresh projects)
- Silent if not a git repo (graceful degradation)
- Always exit 0 (guaranteed by `trap`)

#### Files to create

- `.claude/hooks/pre-compact.sh` (plain file, not `.template` — no placeholders needed)
- `.claude/hooks/session-start.sh` (plain file)
- Update `init-project.sh` to:
  - `mkdir -p "${PROJECT_DIR}/.claude/hooks"`
  - Copy hook scripts to `.claude/hooks/`
  - Run `chmod +x .claude/hooks/*.sh`
  - Deep-merge hook config into `.claude/settings.json` via `python3` (dedup by matcher)
  - Create `.claude/settings.json` for hooks (new file — currently no settings.json in template)
- Update `CLAUDE.md.template` Rule #1 (line ~142): "Le hook SessionStart injecte automatiquement MEMORY.md et LESSONS.md au démarrage, après compaction, resume et /clear. Lecture manuelle = fallback si hook absent."

### Change 7 — MCP Discipline (Merged into Change 1)

Already incorporated into `.claude/rules/tool-routing.md` above (MCP per-tool limits table). The CARL `RULE_7` is in Change 5.

### Change 8 (NEW) — Update `context-manager/SKILL.md`

Discovered during v2 deepening: the context-manager skill needs 5 updates to stay aligned.

| Section | Current | Updated | Reason |
|---------|---------|---------|--------|
| Démarrage de session | Manual read of MEMORY.md + LESSONS.md | Note that SessionStart hook handles auto-injection; manual read is fallback | Change 6 makes manual read secondary |
| Sessions longues | "checkpoint dans MEMORY.md → nouvelle session" | Delegate to `/context-checkpoint` skill | Change 3 automates this |
| References | Lists Rules #1-#7 only | Add: `.claude/rules/tool-routing.md`, `.claude/hooks/session-start.sh`, `.claude/hooks/pre-compact.sh`, update range to #1-#8 | Changes 1, 6 |
| Quand ce skill est utile | Generic "rappeler que les règles existent" | Add: "Pour le routing d'outils, voir `.claude/rules/tool-routing.md`. Pour les checkpoints, utiliser `/context-checkpoint`." | Direct users to correct resource |

**Files to modify:**
- `.claude/skills/context-manager/SKILL.md`

### Change 9 (NEW) — Add `<!-- pre-compact snapshot -->` markers to `MEMORY.md.template`

Discovered during v2 deepening: pre-compact.sh writes between snapshot markers, but MEMORY.md.template has none.

Add at the end of MEMORY.md.template:

```markdown
<!-- pre-compact snapshot -->
<!-- /pre-compact snapshot -->
```

This provides clean first-run behavior and allows pre-compact.sh to replace (not append) on subsequent compactions.

**Files to modify:**
- `MEMORY.md.template`

### Change 10 (NEW) — Update CARL GLOBAL_RULE_9 for MCP discipline auto-update

Extend the existing MCP installation rule in `.carl/global` to include a step for updating `tool-routing.md` after each `claude mcp add`.

**Current GLOBAL_RULE_9:**
```
MCP INSTALLATION: When asked to install/add an MCP server: 1) Source .env 2) Check key 3) Run claude mcp add 4) Verify with claude mcp list 5) Never hardcode keys
```

**Updated GLOBAL_RULE_9 — add step 6:**
```
6) Update .claude/rules/tool-routing.md "Discipline MCP" table: identify the new MCP's native limit parameter (limit, maxResults, first, $top, etc.) and add a row. If no native limit → add row with "subagent obligatoire".
```

This ensures new MCP servers are automatically covered by the discipline rules without relying on the catch-all subagent fallback.

**Files to modify:**
- `.carl/global` (in team-claude-blueprint repo, propagates to all projects)

---

## Technical Considerations

### CLAUDE.md 200-line budget — the key architectural decision

Anthropic's official docs state explicitly: files over 200 lines reduce adherence. CLAUDE.md.template is currently 505 lines — already over budget. Every new addition either displaces existing content or further degrades adherence.

**Decision:** Route all new content through `.claude/rules/` (path-scoped files) and skills, not CLAUDE.md. CLAUDE.md becomes a high-level index with references. This matches how Anthropic recommends structuring large instruction sets.

#### Research Insights (v2): Line Budget Math

| Change | Current lines | Proposed lines | Net delta |
|--------|--------------|----------------|-----------|
| Rule #4 replacement (lines 195-215) | 21 | ~25 | **+4** |
| Rule #1 SessionStart hook note | 0 | +1 | **+1** |
| Rule #3 `/context-checkpoint` reference | 0 | +1 | **+1** |
| Tool-routing.md reference (1 line) | 0 | +1 | **+1** |
| **Subtotal additions** | | | **+7** |
| Flywheel extraction (lines 352-428) | 77 | 1 (reference line) | **-76** |
| **Net change** | | | **-69** |

By extracting the flywheel to `.claude/rules/flywheel-workflow.md`, CLAUDE.md goes from 505 to ~436 lines — significantly closer to the 200-line target. Further extraction candidates for future work:
- Supermemory rule (lines 218-257): -38 lines
- Plan structure rule (lines 298-335): -36 lines
- GSD/Compound coordination (lines 447-483): -35 lines

### COT on Claude 4.6 — not blanket, targeted

Research finding: Claude 4.6 has internal extended thinking. Forcing COT prompting on simple tasks causes 35–600% latency increase with marginal or negative quality delta. The model already reasons internally. External COT is valuable specifically for **agentic multi-step tasks with sequential tool calls** (Anthropic think-tool study: 54% improvement on τ-Bench) — not for simple generation.

The updated Rule #4 uses a 2-of-5 condition gate with explicit precedence (Override > Skip > Triggers) to avoid triggering COT overhead on trivial tasks while preventing nondeterministic behavior on edge cases.

### What we're NOT adopting (and why)

| context-mode feature | Reason for deferral |
|---------------------|---------------------|
| MCP sandbox tools (`ctx_execute`, `ctx_batch_execute`, etc.) | MCP responses bypass sandbox anyway — no gain for primary flooding risk |
| SQLite session database | Too much infrastructure for a template |
| BM25 FTS5 search index | Requires MCP server |
| VPS-hosted context-mode server | Option B — see Roadmap section |

### Risk: settings.json hook conflicts

#### Research Insights (v2): settings.json vs settings.local.json

- `settings.json` = project-level, committed to git, shared with team
- `settings.local.json` = machine-local, gitignored, user-specific (permissions)
- Template currently has only `settings.local.json` (for its own dev permissions)
- **Decision:** Hooks go in `settings.json` (shared). init-project.sh creates a NEW `.claude/settings.json` with only the hooks section. Existing `settings.local.json` remains untouched.
- Deep-merge via `python3` with dedup by matcher prevents duplicates on re-run (defensive, though init-project.sh already blocks re-run via directory check)

---

## System-Wide Impact

- **CLAUDE.md.template**: net **-69 lines** (flywheel extraction + rule updates); all new routing content in `.claude/rules/`
- **Session-gate end mode**: 10 checks (was 8). Check 9 now greppable (`grep -q "<plan>"`); Check 10 advisory only
- **SessionStart hook**: MEMORY.md reinject automatic on **all 4 session events** (startup, compact, resume, clear) — Rule #1 manual read becomes fallback
- **PreCompact hook**: First automatic safety net before context loss — writes snapshot with git commit of MEMORY.md only
- **context-manager skill**: Updated references, delegates to `/context-checkpoint` for long sessions
- **CARL domain template**: RULE_6 (tool routing) + RULE_7 (MCP discipline), RULE_8 placeholder for project-specific use
- **Backwards compatibility**: Additive for new projects. Existing projects need manual migration (see gap below).
- **init-project.sh**: installs context-checkpoint skill, copies hooks + rules, creates settings.json, creates `.claude/rules/` and `.claude/hooks/`

---

## Known Gap: Existing Project Migration

**Status:** Not in scope for Option A. Requires separate plan.

Two active projects (Loupe Technologies, Healthcare Ads) were created from earlier template versions and will not benefit from any of these changes without manual intervention.

**Options for future:**
1. Create `upgrade-project.sh` script that safely adds hooks, rules, skills without overwriting customized files
2. Document a manual migration checklist
3. Accept that only new projects benefit (risk: the pain points this plan solves affect current projects daily)

---

## Acceptance Criteria

- [ ] `.claude/rules/tool-routing.md` exists with routing table, token costs, and MCP per-tool limits
- [ ] `.claude/rules/flywheel-workflow.md` extracted from CLAUDE.md.template
- [ ] `CLAUDE.md.template` references `.claude/rules/tool-routing.md` (1 line, preamble)
- [ ] `CLAUDE.md.template` references `.claude/rules/flywheel-workflow.md` (1 line, replaces 77-line flywheel section)
- [ ] `CLAUDE.md.template` Rule #4 uses 2-of-5 trigger conditions, precedence order, and `<plan>` XML format
- [ ] `CLAUDE.md.template` Rule #1 notes SessionStart hook handles auto-inject on all 4 events
- [ ] `CLAUDE.md.template` Rule #3 references `/context-checkpoint` with softened threshold language
- [ ] `CLAUDE.md.template` net change is negative (fewer lines than before, not more)
- [ ] `/context-checkpoint` skill executes Rule #3 checkpoint in ≤ 5 tool calls, manual-only trigger
- [ ] `session-gate/skill.md` updated: 10 checks, invocation table, section heading
- [ ] `session-gate/skill.md` Check 9 targets `docs/plans/*-plan.md` (not root `PLAN.md`)
- [ ] `session-gate/skill.md` Check 10 counts `### ` headings outside HTML comments, advisory `[--]`
- [ ] `.carl/domain.template` includes RULE_6 (tool routing) and RULE_7 (MCP discipline), RULE_8 placeholder
- [ ] `.claude/settings.json` includes PreCompact + 4 SessionStart matchers with `$CLAUDE_PROJECT_DIR` paths
- [ ] `pre-compact.sh` uses `trap 'exit 0' EXIT`, `python3 || true`, scopes git to MEMORY.md + LESSONS.md only
- [ ] `session-start.sh` emits MEMORY.md + first 10 LESSONS entries, handles all 4 source values
- [ ] `MEMORY.md.template` includes `<!-- pre-compact snapshot -->` markers
- [ ] `context-manager/SKILL.md` updated with 5 reference changes
- [ ] `init-project.sh` installs checkpoint skill, copies hooks + rules, creates settings.json, runs chmod +x
- [ ] Validated by generating a test project (`bash init-project.sh test-project test td`) and verifying all hooks fire on startup

---

## Success Metrics

- CLAUDE.md.template **net line reduction** (fewer lines, not more)
- `session-start.sh` fires on all 4 events (`startup`, `compact`, `resume`, `clear`) — verified via `/hooks` command
- `pre-compact.sh` writes snapshot between markers and exits within 2 seconds — verified with timing test
- COT blocks present in plans for multi-file tasks (verifiable via `grep -q "<plan>" docs/plans/*-plan.md`)
- No MCP list calls without limit parameters — verifiable by review of any session transcript
- LESSONS.md entries grow session-over-session (Check 10 advisory nudge)

---

## Dependencies & Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| `python3` not available in hook environment | Low | macOS 10.13+ has system python3; fallback to `awk`/`sed` subset |
| `$CLAUDE_PROJECT_DIR` not set in hook context | Low | Fallback: `PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"` |
| settings.json deep-merge creates malformed JSON | Low | python3 `json.load/dump` is deterministic; dedup by matcher prevents duplicates |
| CLAUDE.md.template flywheel extraction breaks existing projects | Medium | Existing projects have generated (non-template) files — only new projects affected |
| Check 9 false positive from `<plan>` in documentation examples | Low | Accept low rate; could add `<problem>` proximity check if needed |
| COT 2-of-5 condition 2 ("estimated > 50 LOC") is subjective | Medium | Claude pre-implementation estimates are unreliable at 2-4x. Mitigated by: 4 other non-subjective conditions exist; overrides catch the most critical cases regardless |
| Pre-compact git commit races with active agent file writes | Low | Only stages `memory/MEMORY.md` and `LESSONS.md` — never `git add .`. Commit is `|| true` on failure |
| `trap 'exit 0' EXIT` masks real errors in hook development | Low | During development, temporarily remove trap to see errors. In production, exit 0 is mandatory |
| Context-checkpoint cannot auto-detect context saturation | Known limitation | Skill is manual-only. Rule #3 softened to behavioral cues, not percentages |
| Existing projects get no benefits | High | Documented as known gap. Future: `upgrade-project.sh` or manual migration guide |
| SessionStart hook fires on `clear` but user may not expect context re-injection | Low | Note in output: "Context cleared — MEMORY.md re-injected for continuity" |
| LESSONS.md counting false positive from `###` in HTML comments | Low | Count only headings outside `<!-- -->` blocks |

---

## Implementation Order

Execute in this order to minimize rework:

1. **Change 9** — MEMORY.md.template snapshot markers (1 line, no dependencies)
2. **Change 5** — CARL domain.template RULE_6 + RULE_7 (purely additive)
3. **Change 1** — `.claude/rules/tool-routing.md` + flywheel extraction + minimal CLAUDE.md references (foundation)
4. **Change 2** — CLAUDE.md.template Rule #4 COT trigger conditions + `<plan>` format + precedence
5. **Change 3** — New `/context-checkpoint` skill (references Rule #3)
6. **Change 8** — Update context-manager SKILL.md (references Changes 1, 3, 6)
7. **Change 4** — session-gate Checks 9 + 10 (uses `<plan>` format from Change 2)
8. **Change 6** — Hook scripts + settings.json creation + init-project.sh update (most complex, depends on all above)
9. **Validation** — Test project generation, verify all 4 SessionStart matchers fire, check CARL rules, confirm CLAUDE.md line count decreased

---

## Roadmap — Option B (Future VPS)

**VPS-hosted context-mode MCP server** — deferred, not in scope for this plan.

When ready to implement:

- Deploy context-mode MCP server on VPS with HTTP/SSE transport
- Verify network transport support (stdio-only would require SSH tunnel)
- Configure Claude Code to connect via `claude mcp add context-mode --transport sse http://vps:port`
- Replace hook scripts with context-mode's full hook suite (PostToolUse event capture, PreCompact → SQLite)
- Unlock 6 sandbox tools: `ctx_execute`, `ctx_batch_execute`, `ctx_index`, `ctx_search`, `ctx_fetch_and_index`, `ctx_execute_file`
- **Realistic gain for this setup**: moderate — primary flooding source is MCP responses, which Option B sandbox tools do NOT intercept (MCP responses bypass the sandbox)
- **When it IS worth it**: if Playwright automation is heavy (browser_snapshot flooding is the biggest single win: 135K → ~430 bytes)
- **Prerequisite:** Option A must be implemented first — VPS adds to the hooks/rules infrastructure, it does not replace it

---

## Sources & References

### External References

- **context-mode repo**: [github.com/mksglu/context-mode](https://github.com/mksglu/context-mode) — primary inspiration (may be unavailable; patterns validated against official docs)
- **Claude Code Hooks reference**: [code.claude.com/docs/en/hooks](https://code.claude.com/docs/en/hooks) — authoritative source for all hook formats
- **Claude Code Hooks guide**: [code.claude.com/docs/en/hooks-guide](https://code.claude.com/docs/en/hooks-guide) — workflow examples
- **Claude Code Hooks blog**: [claude.com/blog/how-to-configure-hooks](https://claude.com/blog/how-to-configure-hooks) — configuration patterns
- **Claude Code Session Hooks**: [claudefa.st/blog/tools/hooks/session-lifecycle-hooks](https://claudefa.st/blog/tools/hooks/session-lifecycle-hooks) — auto-load context
- **Claude Code Hooks Complete Guide**: [claudefa.st/blog/tools/hooks/hooks-guide](https://claudefa.st/blog/tools/hooks/hooks-guide) — all 12 lifecycle events
- **MCP Tool Search** (85% input reduction): [atcyrus.com](https://www.atcyrus.com/stories/mcp-tool-search-claude-code-context-pollution-guide)
- **MCP 25K token cap + Sonar breach**: [x.com/simas_ch](https://x.com/simas_ch/status/1952081786416079210)
- **Writing Effective MCP Tools**: [modelcontextprotocol.info](https://modelcontextprotocol.info/docs/tutorials/writing-effective-tools/)
- **Anthropic think-tool study** (54% improvement): [anthropic.com/engineering/claude-think-tool](https://www.anthropic.com/engineering/claude-think-tool)
- **COT on Claude 4.6** (Wharton): [gail.wharton.upenn.edu](https://gail.wharton.upenn.edu/research-and-insights/tech-report-chain-of-thought/)
- **Agentic Coding Handbook** (Tweag): [tweag.github.io](https://tweag.github.io/agentic-coding-handbook/PRJ_INSTRUCTIONS/)
- **Claude Code Best Practices**: [code.claude.com/docs/en/best-practices](https://code.claude.com/docs/en/best-practices)
- **Hook env variables bug**: [github.com/anthropics/claude-code/issues/9567](https://github.com/anthropics/claude-code/issues/9567)
- **PreCompact transcript_path issue**: [github.com/anthropics/claude-code/issues/13668](https://github.com/anthropics/claude-code/issues/13668)
- **PostCompact event request**: [github.com/anthropics/claude-code/issues/14258](https://github.com/anthropics/claude-code/issues/14258)

### Internal References

- `CLAUDE.md.template` — Rule #1 (lines 139-153), Rule #3 (lines 176-192), Rule #4 (lines 195-215), flywheel (lines 352-428)
- `.claude/skills/session-gate/skill.md` — current 8-check validation, invocation table (lines 15-19), section heading (line 38)
- `.claude/skills/context-manager/SKILL.md` — pointer skill (58 lines), references Rules #1-#7
- `.carl/domain.template` — RULE_0 through RULE_5 active, RULE_6/7/8 commented placeholders
- `init-project.sh` — skill install pattern (lines 66-91), no settings.json handling, no `.claude/rules/` section
- `MEMORY.md.template` — no snapshot markers (need to add)
- `.claude/settings.local.json` — template's own permissions (not copied to projects)
