#!/usr/bin/env bash
# lib/signals.sh — 7 signal computation functions (D-06 through D-12).
#
# Each function writes a file under $PMO_TMPDIR. The renderer reads those
# files. Order matters: stagnation must run after active; next_move must run
# after stagnation + blocking_deps + gate_gaps.
#
# All functions assume config.sh + phases.sh have been sourced and
# pmo_load_config has been called.
set -euo pipefail

# Signal 1 (D-06): Active phases with last-commit ISO dates.
# Writes tab-separated rows to active.tsv:
#   phase_number<TAB>basename<TAB>last_commit_iso<TAB>days_since
pmo_signal_active() {
  local out="$PMO_TMPDIR/active.tsv"
  : > "$out"
  local dir base num iso days
  while IFS= read -r dir; do
    [[ -z "$dir" ]] && continue
    base=$(basename "$dir")
    num=$(pmo_extract_phase_number "$base")
    iso=$(pmo_last_commit_iso "$dir")
    days=$(pmo_days_since_iso "$iso")
    printf '%s\t%s\t%s\t%s\n' "$num" "$base" "$iso" "$days" >> "$out"
  done < <(pmo_list_phase_dirs active)
}

# Signal 2 (D-07): Stagnation — active phases older than PMO_STALE_DAYS.
# Reads active.tsv (must be called after pmo_signal_active).
pmo_signal_stagnation() {
  local out="$PMO_TMPDIR/stagnation.tsv"
  : > "$out"
  local threshold="${1:-$PMO_STALE_DAYS}"
  [[ -s "$PMO_TMPDIR/active.tsv" ]] || return 0
  awk -F'\t' -v t="$threshold" '$4 != "999999" && $4 >= t { print }' "$PMO_TMPDIR/active.tsv" > "$out" || true
}

# Signal 3 (D-08): Phase number collisions across all states.
# Writes collisions.tsv: number<TAB>state1:basename1<TAB>state2:basename2...
pmo_signal_collisions() {
  local out="$PMO_TMPDIR/collisions.tsv"
  local tmp="$PMO_TMPDIR/all_phases.tsv"
  : > "$tmp"
  : > "$out"
  local state dir base num
  for state in $PMO_PHASE_STATES; do
    while IFS= read -r dir; do
      [[ -z "$dir" ]] && continue
      base=$(basename "$dir")
      num=$(pmo_extract_phase_number "$base")
      [[ -z "$num" ]] && continue
      printf '%s\t%s\t%s\n' "$num" "$state" "$base" >> "$tmp"
    done < <(pmo_list_phase_dirs "$state")
  done
  # Group by number, keep only groups with >= 2 entries.
  [[ -s "$tmp" ]] || return 0
  sort "$tmp" | awk -F'\t' '
    { entry = $2 ":" $3
      if (by_num[$1] == "") by_num[$1] = entry
      else                  by_num[$1] = by_num[$1] "\t" entry
      count[$1]++ }
    END { for (n in count) if (count[n] >= 2) print n "\t" by_num[n] }
  ' > "$out"
}

# Signal 4 (D-09): STATE.md drift — compare claimed active phase vs filesystem.
# Writes state_drift.txt. Graceful degrade when STATE.md absent (D-19).
pmo_signal_state_drift() {
  local out="$PMO_TMPDIR/state_drift.txt"
  : > "$out"
  local state_file="$PMO_REPO_ROOT/$PMO_STATE_MD"
  if [[ ! -f "$state_file" ]]; then
    echo "no reference to compare (${PMO_STATE_MD} absent)" > "$out"
    return 0
  fi
  # Extract the first "phase: <num>" line (case-insensitive).
  # Matches "Phase: 24.1 (forge-...)" as well as YAML "phase: \"24.1\"".
  # Two-step: isolate the first matching line, then pull the first numeric
  # token (grep -oE is not greedy across separate matches — head -1 picks
  # the leftmost). Avoids the "trailing greedy .*" trap that made an
  # earlier sed-based version collapse "24.1" to just "1".
  # "*" (not "?") on the decimal group keeps "04.2.1.1" intact.
  local claimed
  claimed=$(grep -iE '^[[:space:]]*phase:' "$state_file" \
            | head -1 \
            | grep -oE '[0-9]+(\.[0-9]+)*' \
            | head -1)
  if [[ -z "$claimed" ]]; then
    echo "STATE.md has no parseable 'Phase: N' line" > "$out"
    return 0
  fi
  # Check if a directory under active/ has this number.
  local found=false
  local dir base num
  while IFS= read -r dir; do
    [[ -z "$dir" ]] && continue
    base=$(basename "$dir")
    num=$(pmo_extract_phase_number "$base")
    if [[ "$num" == "$claimed" ]]; then
      found=true
      break
    fi
  done < <(pmo_list_phase_dirs active)
  if ! $found; then
    echo "drift: STATE.md claims Phase $claimed active, but no matching directory under ${PMO_PHASES_DIR}/active/" > "$out"
  fi
}

# Signal 5 (D-10): Blocking dependencies — tolerant parser.
# For each planned phase, extract "Depends on Phase N" (tolerant match).
# Emit a finding when any declared dep is not present in complete/.
pmo_signal_blocking_deps() {
  local out="$PMO_TMPDIR/blocking_deps.tsv"
  : > "$out"
  # Build the set of complete phase numbers once.
  local complete_nums="$PMO_TMPDIR/complete_nums.txt"
  : > "$complete_nums"
  local dir base num
  while IFS= read -r dir; do
    [[ -z "$dir" ]] && continue
    base=$(basename "$dir")
    num=$(pmo_extract_phase_number "$base")
    [[ -n "$num" ]] && echo "$num" >> "$complete_nums"
  done < <(pmo_list_phase_dirs complete)

  while IFS= read -r dir; do
    [[ -z "$dir" ]] && continue
    base=$(basename "$dir")
    num=$(pmo_extract_phase_number "$base")
    local ctx_file
    ctx_file=$(find "$dir" -maxdepth 1 -name "$PMO_CONTEXT_MD_GLOB" -type f 2>/dev/null | head -1)
    [[ -z "$ctx_file" ]] && continue
    # Tolerant regex: capture every phase number appearing after a "depends on" clause.
    local deps
    deps=$(grep -oiE 'depends on[[:space:]:]+[^.]*phase[[:space:]]*[0-9]+(\.[0-9]+)?' "$ctx_file" 2>/dev/null \
           | sed -nE 's/.*[Pp]hase[[:space:]]*([0-9]+(\.[0-9]+)?).*/\1/p' \
           | sort -u || true)
    [[ -z "$deps" ]] && continue
    local missing=""
    local dep
    while IFS= read -r dep; do
      [[ -z "$dep" ]] && continue
      if ! grep -qxF "$dep" "$complete_nums"; then
        missing="${missing:+$missing,}$dep"
      fi
    done <<< "$deps"
    if [[ -n "$missing" ]]; then
      printf '%s\t%s\t%s\n' "$num" "$base" "$missing" >> "$out"
    fi
  done < <(pmo_list_phase_dirs planned)
}

# Signal 6 (D-11): Plan-checker gate gaps — any phase in planned/ or active/
# missing the PLAN-CHECKER-PASS marker.
pmo_signal_gate_gaps() {
  local out="$PMO_TMPDIR/gate_gaps.tsv"
  : > "$out"
  local state dir base num
  for state in active planned; do
    while IFS= read -r dir; do
      [[ -z "$dir" ]] && continue
      base=$(basename "$dir")
      num=$(pmo_extract_phase_number "$base")
      if [[ ! -f "$dir/$PMO_PLAN_CHECKER_MARKER" ]]; then
        printf '%s\t%s\t%s\n' "$state" "$num" "$base" >> "$out"
      fi
    done < <(pmo_list_phase_dirs "$state")
  done
}

# Signal 7 (D-12): Next recommended move (advisory).
# Deterministic rule:
#   If any stagnant active phase exists AND any planned phase has no missing
#   deps AND that planned phase has a PLAN-CHECKER-PASS marker → suggest it.
#   Otherwise emit a neutral observation.
pmo_signal_next_move() {
  local out="$PMO_TMPDIR/next_move.txt"
  : > "$out"
  [[ "$PMO_ADVISORY_ENABLED" != "true" ]] && return 0

  local stale_count=0
  if [[ -s "$PMO_TMPDIR/stagnation.tsv" ]]; then
    stale_count=$(wc -l < "$PMO_TMPDIR/stagnation.tsv" | tr -d ' ')
  fi

  local candidate=""
  local dir base num
  while IFS= read -r dir; do
    [[ -z "$dir" ]] && continue
    base=$(basename "$dir")
    num=$(pmo_extract_phase_number "$base")
    [[ -z "$num" ]] && continue
    # Skip phases with missing deps.
    if [[ -s "$PMO_TMPDIR/blocking_deps.tsv" ]] \
       && awk -F'\t' -v n="$num" '$1 == n { found=1 } END { exit !found }' "$PMO_TMPDIR/blocking_deps.tsv"; then
      continue
    fi
    if [[ -f "$dir/$PMO_PLAN_CHECKER_MARKER" ]]; then
      candidate="$base"
      break
    fi
  done < <(pmo_list_phase_dirs planned)

  if [[ "$stale_count" -gt 0 && -n "$candidate" ]]; then
    echo "$stale_count active phase(s) stagnant; $candidate is ready (no blocking deps, plan-checker PASS)." > "$out"
  elif [[ "$stale_count" -gt 0 ]]; then
    echo "$stale_count active phase(s) stagnant; no planned phase is simultaneously unblocked and plan-checker-verified." > "$out"
  else
    echo "No stagnation detected." > "$out"
  fi
}
