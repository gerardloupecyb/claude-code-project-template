---
name: pmo
description: >
  Deterministic read-only portfolio pulse across all GSD phases.
  Synthesizes active phases, stagnation, phase number collisions, STATE.md drift,
  blocking dependencies, and plan-checker gate gaps from filesystem + git + CONTEXT.md.
  No LLM at runtime, no writes, no dispatch. Diagnostic-only — action remains the operator's decision.
  Triggers on: /pmo, pmo, portfolio pulse, portfolio status, pulse.
---

# /pmo — Portfolio Pulse

`/pmo` is the read-only diagnostic sibling of `gsd-manager`. It synthesizes a
concise portfolio pulse across every phase in `.planning/phases/{active,planned,complete}/`
by reading the filesystem, `git log`, and per-phase `CONTEXT.md` files. It is
deterministic, idempotent, and uses no LLM at runtime — the output depends only
on the current filesystem and git state.

## Scope

- **Read-only.** The skill never writes to project state, never dispatches a task, never runs a plan, never modifies any file.
- **Deterministic.** Pure filesystem + `git log` + per-phase `CONTEXT.md` parsing. No LLM reasoning at runtime, no network, no external services.
- **Diagnostic only.** Output is synthesized state and findings. Dispatch is the responsibility of `gsd-manager`.
- **FORGE-portable.** All project-specific paths live in `.claude/skills/pmo/config.yaml`. Porting to another GSD project requires only a config edit — zero code changes.

## Usage

### /pmo

Stdout markdown pulse. Invoke with `/pmo` or `/pmo --stale-days N` (default `N=7`).
Output is a single screen (≤ 40 lines on a 120×40 terminal) with three sections:

```
## Active phases
| Phase | Last commit | Stagnation |
|-------|-------------|------------|
| 24.2  | 2 days ago  | ok         |
| 1005  | 5 min ago   | ok         |
| 07    | 12 days ago | ⚠ stale    |

## Findings
- ⚠ Phase number collision: two `1000-*` directories in planned/
- ⚠ STATE.md drift: claims Phase 24.1 EXECUTING, but 24.1 is not in active/
- ⚠ Plan-checker gate gap: planned/07-mass-infrastructure/ missing PLAN-CHECKER-PASS

## Next recommended move
Phase 07 is stale and its dependencies are complete — consider resuming wave 1.
```

### /pmo --statusline

Single-line compact summary for Claude Code's native statusline. Example:

```
📊 5 active · 1 stale · ⚠ 2 drift · → Phase 24.2 wave 4
```

Contains at most 5 metrics. Runs at every Claude Code prompt — latency budget is strict.

### /pmo --no-advice

Suppress the "Next recommended move" line (D-12 opt-out). All other sections render normally.
Use when the advisory feels noisy or when the operator already knows what's next.

## Authoritative vs Drift-Detected Sources

**Authoritative** (trusted as truth):

- (a) Filesystem placement under `.planning/phases/{active,planned,complete}/`
- (b) `git log` per phase directory
- (c) `CONTEXT.md` within each phase directory

**Drift-detected** (read for comparison, never trusted as truth):

- `.planning/STATE.md`
- `memory/MEMORY.md`
- `.planning/ROADMAP.md`

If any drift-detected source is absent, the corresponding drift signal degrades gracefully
(reports "no reference to compare") instead of erroring. The skill still works.

## Signal Catalog (MVP)

1. **Active phases** — list every phase in `.planning/phases/active/` with the date of the last commit touching each directory.
2. **Stagnation** — flag any active phase with no commit touching its directory for more than `--stale-days N` (default 7).
3. **Phase number collisions** — flag any case where two or more phase directories across `active/`, `planned/`, or `complete/` share the same leading number.
4. **STATE.md drift** — compare `Current Position` / `Phase` / `Stopped at` in `.planning/STATE.md` against filesystem reality in `active/`; report disagreements as findings.
5. **Blocking dependencies** — parse `Depends on:` declarations in per-phase `CONTEXT.md` of phases in `planned/`; flag planned phases whose declared dependencies are not yet in `complete/`.
6. **Plan-checker gate gaps** — flag any phase in `planned/` or `active/` missing the `PLAN-CHECKER-PASS` marker required by `verification-discipline.md`.
7. **Next recommended move (advisory)** — one neutral textual suggestion per invocation, derived from deterministic rules. No dispatch, text only. Suppressible via `--no-advice`.

## Configuration and FORGE Portability

> All project-specific paths and thresholds live in `.claude/skills/pmo/config.yaml`. To port `/pmo` to another GSD-based project, copy the entire `.claude/skills/pmo/` directory and edit `config.yaml` only. No script edit, no SKILL.md edit. This is the FORGE portability contract.
>
> **Note on skill-dir convention:** Per `.claude/rules/governance.md` § "Convention d'artefacts skill", skill directories normally contain only `SKILL.md` and artefacts live under `config/`, `logs/`, etc. `/pmo` documents an intentional exception: `config.yaml` lives inside the skill dir because it IS the portability surface. Moving it to `config/` would couple the skill to the {{PROJECT}} project layout and defeat FORGE portability.

## Session Start Hook (Opt-In)

> `/pmo` does NOT install a session-start hook by default. To enable automatic pulse on every session start, paste the snippet below into `.claude/settings.json` under `hooks.SessionStart`:
> ```json
> { "type": "command", "command": "bash .claude/skills/pmo/scripts/pmo.sh --statusline" }
> ```
> The opt-in requirement is deliberate: the skill is useful without the hook, and operator control over session-start behavior is respected.

## Scope Boundaries — Explicitly Out

- HTML dashboard
- Linear sync
- Graph visualization of dependencies
- MEMORY.md drift detection
- Dispatch of next actions (owned by `gsd-manager`)
- LLM-powered advisory
- Auto-fix for detected drift
- Cross-repo portfolio view
- Todos-stale count (use `/todo stale` instead)

## Stabilization Before FORGE Extraction

> Per D-20 in the phase CONTEXT, `/pmo` stabilizes in {{PROJECT}} for at least two weeks of real use before FORGE extraction. If any `config.yaml`-only change proves insufficient to adapt during stabilization (i.e. a script edit is required for a legitimate portability concern), the FORGE portability claim is invalidated and must be fixed before extraction. Track any such incident in `docs/solutions/pmo-portability-notes.md` if/when it occurs.

<!-- No MCP Routing section: /pmo is a pure filesystem+git skill with zero MCP dependencies (governance.md exemption). -->
