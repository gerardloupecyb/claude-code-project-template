# Execution Flow — Steps 0-2 Detail

> Loaded by `/execute-phase-auto` Steps 0-2. Covers the gate check, the
> `/gsd:execute-phase` call, and danger hard-stop behavior.

## Step 0 — Gate check

The skill refuses to execute a phase that has not been prepared. Two artifacts
must both exist for the phase folder `.planning/phases/**/{N}-*/`:

1. **`PLAN-CHECKER-PASS` marker** — proves the plan-checker ran (see
   `.claude/rules/verification-discipline.md` § Evidence Requirements,
   "Ready to execute"). Locate it via `Glob` under the phase folder.
2. **Pre-flight verdict GO or CONDITIONAL GO** — read the phase pre-flight
   artifact (`*PREFLIGHT*` / `{N}-*` pre-flight output). The verdict must be
   `GO` or `CONDITIONAL GO`. `NO-GO` or a missing verdict fails the gate.

### Gate outcomes

| Condition | Action |
|-----------|--------|
| Both artifacts present, verdict GO / CONDITIONAL GO | Proceed to Step 1 |
| `PLAN-CHECKER-PASS` missing | **Refuse.** Tell the user the phase is not gated and route them to `/prepare-phase {N}` |
| Pre-flight verdict NO-GO or absent | **Refuse.** Route to `/prepare-phase {N}` |

Never execute without the gate — in either mode. The gate is not skippable by
`--autonomous`. If an exemption genuinely applies (`plan_checker_enabled: false`
documented in the phase, or an explicit `--skip-verify` recorded), state the
exemption explicitly and cite where it is documented before proceeding.

## Step 1 — Danger classification

Run the scan and produce the danger map. Full mechanics, signal lists, and the
output format live in `references/danger-classification.md`. Interactive mode
confirms the map with the user; autonomous mode presents it and proceeds.

## Step 2 — Autonomous execution

Call the upstream GSD command unchanged:

```
/gsd:execute-phase {N}
```

This skill does **not** modify `/gsd:execute-phase` — it wraps it. The GSD
command keeps its own wave-based parallelization, checkpoints, and state
updates. This orchestrator adds the danger discipline on top.

### Hard-stop behavior at danger boundaries

A **danger boundary** is the point where execution reaches a plan (or a wave
step) classified `danger=yes` in Step 1.

At every danger boundary, regardless of mode:

1. **Hard-stop** — pause before the dangerous action executes.
2. **Surface the decision** — state plainly: which plan, which dangerous
   action, what the irreversible/external effect is, and the specific danger
   trigger from the danger map.
3. **Wait for the human** — do not proceed until the user explicitly approves,
   amends, or aborts. No timeout, no default-yes.
4. On approval → execute that plan/step, then continue. On abort → stop the
   chain cleanly and report what completed.

Non-dangerous plans run continuously without any prompt — that is the point of
the skill: autonomy everywhere it is safe, solicitation only where it is not.

### Interactive vs autonomous — Steps 0-2

| Aspect | Interactive | Autonomous |
|--------|-------------|------------|
| Step 0 gate check | Same — refuse if ungated | Same — refuse if ungated |
| Step 1 danger map | User confirms / amends the map | Presented for record, proceed |
| Step 2 non-dangerous plans | Run without prompt | Run without prompt |
| Step 2 danger boundary | Hard-stop + solicit human | Hard-stop + solicit human (identical) |
| GSD checkpoint prompts | Surfaced to the user | Surfaced to the user (a GSD checkpoint is not auto-answered) |

The only behavioral difference between modes in Steps 0-2 is the Step 1 map
confirmation. Danger hard-stops are identical — `--autonomous` buys no
shortcut through danger.

## Error handling

If `/gsd:execute-phase` errors on a wave, stop the chain and diagnose for the
user. Do not auto-retry the wave — surface the failure, its likely cause, and
let the user decide. Re-running a wave is the user's call.
