#!/usr/bin/env bash
# pmo.sh — /pmo portfolio pulse entry point.
#
# Reads .claude/skills/pmo/config.yaml, scans phase directories, computes
# the 7 MVP signals (D-06 through D-12), renders a markdown pulse to stdout.
#
# Deterministic, read-only, no LLM, no network. See SKILL.md for contract.
set -euo pipefail

# Resolve skill dir from this script's location.
PMO_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PMO_SKILL_DIR="$(cd "$PMO_SCRIPT_DIR/.." && pwd)"
export PMO_SKILL_DIR

# Defaults — overridable by CLI flags below.
PMO_MODE="markdown"
PMO_CLI_STALE_DAYS=""
PMO_NO_ADVICE="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --statusline) PMO_MODE="statusline"; shift ;;
    --stale-days) PMO_CLI_STALE_DAYS="$2"; shift 2 ;;
    --no-advice)  PMO_NO_ADVICE="true"; shift ;;
    -h|--help)
      cat <<EOF
/pmo — Portfolio Pulse
Usage:
  pmo.sh                    # stdout markdown pulse (default)
  pmo.sh --statusline       # single-line compact summary (Plan 03)
  pmo.sh --stale-days N     # override stagnation threshold (default from config)
  pmo.sh --no-advice        # suppress "Next recommended move" line
EOF
      exit 0 ;;
    *) echo "pmo: unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Source libraries.
# shellcheck disable=SC1091
source "$PMO_SCRIPT_DIR/lib/config.sh"
# shellcheck disable=SC1091
source "$PMO_SCRIPT_DIR/lib/phases.sh"
# shellcheck disable=SC1091
source "$PMO_SCRIPT_DIR/lib/signals.sh"
# shellcheck disable=SC1091
source "$PMO_SCRIPT_DIR/lib/render_markdown.sh"

pmo_load_config

# CLI overrides applied after config load.
if [[ -n "$PMO_CLI_STALE_DAYS" ]]; then
  PMO_STALE_DAYS="$PMO_CLI_STALE_DAYS"
  export PMO_STALE_DAYS
fi
if [[ "$PMO_NO_ADVICE" == "true" ]]; then
  PMO_ADVISORY_ENABLED="false"
  export PMO_ADVISORY_ENABLED
fi

# Per-run tmp dir for signal output files. Cleaned on exit.
PMO_TMPDIR="$(mktemp -d -t pmo.XXXXXX)"
export PMO_TMPDIR
trap 'rm -rf "$PMO_TMPDIR"' EXIT

# Compute all signals. Order matters: stagnation needs active;
# next_move needs stagnation + blocking_deps + gate_gaps.
pmo_signal_active
pmo_signal_stagnation
pmo_signal_collisions
pmo_signal_state_drift
pmo_signal_blocking_deps
pmo_signal_gate_gaps
pmo_signal_next_move

case "$PMO_MODE" in
  markdown)
    pmo_render_markdown
    ;;
  statusline)
    # shellcheck disable=SC1091
    source "$PMO_SCRIPT_DIR/lib/render_statusline.sh"
    pmo_render_statusline
    ;;
esac
