#!/usr/bin/env bash
# lib/render_statusline.sh — single-line compact summary for Claude Code statusline
set -euo pipefail

# Format contract (D-14):
#   {emoji_prefix} {N} active {sep} {N} stale {sep} ⚠ {N} drift {sep} → {suggestion}
# Max 5 metrics. Ordering: active, stale, collisions, drift, next move.
# If a counter is 0, it is OMITTED (keeps the line compact under normal conditions).

pmo_render_statusline() {
  local emoji="${PMO_STATUSLINE_EMOJI:-📊}"
  local sep="${PMO_STATUSLINE_SEP:- · }"

  local active_count=0
  local stale_count=0
  local collision_count=0
  local drift_count=0
  local gate_gap_count=0

  [[ -f "$PMO_TMPDIR/active.tsv" ]]        && active_count=$(wc -l < "$PMO_TMPDIR/active.tsv"        | tr -d ' ')
  [[ -f "$PMO_TMPDIR/stagnation.tsv" ]]    && stale_count=$(wc -l < "$PMO_TMPDIR/stagnation.tsv"     | tr -d ' ')
  [[ -f "$PMO_TMPDIR/collisions.tsv" ]]    && collision_count=$(wc -l < "$PMO_TMPDIR/collisions.tsv" | tr -d ' ')
  [[ -f "$PMO_TMPDIR/gate_gaps.tsv" ]]     && gate_gap_count=$(wc -l < "$PMO_TMPDIR/gate_gaps.tsv"   | tr -d ' ')

  # state_drift.txt drift_count = 1 if non-empty AND does NOT start with "no reference"
  if [[ -s "$PMO_TMPDIR/state_drift.txt" ]]; then
    if ! grep -q "^no reference" "$PMO_TMPDIR/state_drift.txt"; then
      drift_count=1
    fi
  fi

  # Build metrics array, omitting zero-value metrics except "active"
  local parts=()
  parts+=("${emoji} ${active_count} active")
  [[ "$stale_count"     -gt 0 ]] && parts+=("${stale_count} stale")
  [[ "$collision_count" -gt 0 ]] && parts+=("⚠ ${collision_count} collision")
  [[ "$drift_count"     -gt 0 ]] && parts+=("⚠ drift")
  [[ "$gate_gap_count"  -gt 0 ]] && parts+=("${gate_gap_count} gate gap")

  # Cap at 5 (shouldn't trigger — we have exactly 5 metrics max above, but hard cap anyway)
  if [[ ${#parts[@]} -gt 5 ]]; then
    parts=("${parts[@]:0:5}")
  fi

  # Join with separator
  local line=""
  local i
  for i in "${!parts[@]}"; do
    if [[ $i -eq 0 ]]; then
      line="${parts[$i]}"
    else
      line="${line}${sep}${parts[$i]}"
    fi
  done

  # Optional: append next-move hint if advisory enabled and short enough
  if [[ "${PMO_ADVISORY_ENABLED:-true}" == "true" && -s "$PMO_TMPDIR/next_move.txt" ]]; then
    local hint
    hint=$(head -1 "$PMO_TMPDIR/next_move.txt")
    # Only append if it fits a heuristic soft limit (<= 60 chars hint)
    if [[ ${#hint} -le 60 ]]; then
      line="${line}${sep}→ ${hint}"
    fi
  fi

  printf '%s\n' "$line"
}
