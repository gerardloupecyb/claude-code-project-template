#!/usr/bin/env bash
# lib/render_markdown.sh — render signals to stdout markdown.
#
# Reads per-signal files under $PMO_TMPDIR. The signal functions in
# signals.sh guarantee every file exists (even if empty), so the 5 Findings
# subsections always render (empty ones show "_None._").
set -euo pipefail

pmo_render_markdown() {
  local now_iso
  now_iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  echo "# Portfolio Pulse — $now_iso"
  echo
  echo "## Active Phases"
  echo
  if [[ -s "$PMO_TMPDIR/active.tsv" ]]; then
    echo "| # | Phase | Last commit | Age (days) |"
    echo "|---|---|---|---|"
    awk -F'\t' -v t="$PMO_STALE_DAYS" '{
      flag = ($4 != "999999" && $4 >= t) ? " ⚠" : ""
      printf "| %s | %s | %s | %s%s |\n", $1, $2, $3, $4, flag
    }' "$PMO_TMPDIR/active.tsv"
  else
    echo "_No active phases._"
  fi
  echo
  echo "## Findings"
  echo
  echo "### Phase Number Collisions"
  if [[ -s "$PMO_TMPDIR/collisions.tsv" ]]; then
    awk -F'\t' '{
      s = ""
      for (i = 2; i <= NF; i++) s = (i == 2) ? $i : s ", " $i
      printf "- **Phase %s** collision: %s\n", $1, s
    }' "$PMO_TMPDIR/collisions.tsv"
  else
    echo "_None._"
  fi
  echo
  echo "### STATE.md Drift"
  if [[ -s "$PMO_TMPDIR/state_drift.txt" ]]; then
    sed 's/^/- /' "$PMO_TMPDIR/state_drift.txt"
  else
    echo "_None._"
  fi
  echo
  echo "### Stagnation (> $PMO_STALE_DAYS days)"
  if [[ -s "$PMO_TMPDIR/stagnation.tsv" ]]; then
    awk -F'\t' '{ printf "- **%s** — %s days since last commit (last: %s)\n", $2, $4, $3 }' "$PMO_TMPDIR/stagnation.tsv"
  else
    echo "_None._"
  fi
  echo
  echo "### Blocking Dependencies"
  if [[ -s "$PMO_TMPDIR/blocking_deps.tsv" ]]; then
    awk -F'\t' '{ printf "- **%s** (Phase %s) — missing: %s\n", $2, $1, $3 }' "$PMO_TMPDIR/blocking_deps.tsv"
  else
    echo "_None._"
  fi
  echo
  echo "### Plan-Checker Gate Gaps"
  if [[ -s "$PMO_TMPDIR/gate_gaps.tsv" ]]; then
    awk -F'\t' -v marker="$PMO_PLAN_CHECKER_MARKER" '{
      printf "- [%s] **%s** — missing %s marker\n", $1, $3, marker
    }' "$PMO_TMPDIR/gate_gaps.tsv"
  else
    echo "_None._"
  fi
  echo
  echo "## Next Recommended Move"
  if [[ -s "$PMO_TMPDIR/next_move.txt" ]]; then
    sed 's/^/- /' "$PMO_TMPDIR/next_move.txt"
  else
    echo "_(advisory suppressed)_"
  fi
}
