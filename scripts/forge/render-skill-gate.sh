#!/usr/bin/env bash
# render-skill-gate.sh — single-source renderer (AC-2-5, Plan 22-02)
#
# Renders the ENFORCED domain-routing table + the gated-MCP list in .claude/rules/skill-gate.md
# from .claude/gate.config.json — the SAME file the security hooks source (pre-tool-use.sh /
# pre-mcp-gate.sh). This collapses the old 3-way mirror (doc table / hook regex / settings matcher)
# to ONE source, so the doc can never drift from what the hook enforces.
#
# Idempotent: re-running produces byte-identical output (the AC-2-5 no-drift oracle re-runs this and
# asserts an empty git diff). Only the content BETWEEN the generated markers is touched; everything
# else in skill-gate.md (prose, selection guidance, path-scoped rules) is preserved verbatim.
#
# Usage: scripts/forge/render-skill-gate.sh [--check] [GATE_CONFIG] [SKILL_GATE_MD]
#   --check : render to a temp file and diff against the current file; exit 1 if they differ
#             (no write). Used by CI / the oracle. Without --check, writes in place.
set -uo pipefail

CHECK=0
if [ "${1:-}" = "--check" ]; then CHECK=1; shift; fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG="${1:-$REPO_ROOT/.claude/gate.config.json}"
SKILLGATE="${2:-$REPO_ROOT/.claude/rules/skill-gate.md}"

command -v jq >/dev/null 2>&1 || { echo "render-skill-gate: jq required" >&2; exit 2; }
[ -f "$CONFIG" ]    || { echo "render-skill-gate: config not found: $CONFIG" >&2; exit 2; }
jq -e . "$CONFIG" >/dev/null 2>&1 || { echo "render-skill-gate: invalid JSON: $CONFIG" >&2; exit 2; }
# Shape-validate via the shared chokepoint — REFUSE to render a malformed config. Otherwise a wrong-shape
# protected_domains would make the jq below emit a header-only (blank) table and the --check oracle would
# pass, masking the drift (review MEDIUM). This is a build tool, not a runtime gate: a bad config is fatal.
GATE_LIB="$REPO_ROOT/.claude/hooks/lib/gate-config.sh"
if [ -f "$GATE_LIB" ]; then
  . "$GATE_LIB"
  gate_config_shape_ok "$CONFIG" || { echo "render-skill-gate: config shape invalid — ${GATE_CONFIG_REASON}" >&2; exit 2; }
fi
[ -f "$SKILLGATE" ] || { echo "render-skill-gate: skill-gate.md not found: $SKILLGATE" >&2; exit 2; }
# All four markers must exist — else a deleted block would let the awk splice pass a corrupted file
# through unchanged and the --check oracle would miss the drift (review MEDIUM).
for _m in 'BEGIN GENERATED: domain-routing' 'END GENERATED: domain-routing' 'BEGIN GENERATED: mcp-gating' 'END GENERATED: mcp-gating'; do
  grep -qF "$_m" "$SKILLGATE" || { echo "render-skill-gate: marker missing ('$_m') in $SKILLGATE" >&2; exit 2; }
done

# --- Build the generated blocks from gate.config.json ---
DRF=$(mktemp); MCPF=$(mktemp); TMP=$(mktemp)
cleanup() { rm -f "$DRF" "$MCPF" "$TMP"; }
trap cleanup EXIT

{
  echo "| Domaine | Triggers (fichiers / commandes) | Skills requis | Marker (unlock) |"
  echo "|---|---|---|---|"
  jq -r '.protected_domains[] | "| \(.label // .name) | \(.triggers_doc // "") | `\(.required_skills)` | `\(.unlock)` |"' "$CONFIG"
} > "$DRF"

{
  echo "| Serveur MCP (préfixe) | Domaine (marker) | Mutation prod bloquée sans lock |"
  echo "|---|---|---|"
  jq -r '.gated_mcp[] | "| `\(.server_prefix)` | `\(.marker)` | oui (verbes de mutation) |"' "$CONFIG"
} > "$MCPF"

# --- Splice generated blocks between their markers; preserve everything else ---
awk -v drf="$DRF" -v mcpf="$MCPF" '
  function dumpfile(f,  line){ while ((getline line < f) > 0) print line; close(f) }
  /BEGIN GENERATED: domain-routing/ { print; dumpfile(drf); skip=1; next }
  /END GENERATED: domain-routing/   { skip=0; print; next }
  /BEGIN GENERATED: mcp-gating/     { print; dumpfile(mcpf); skip=1; next }
  /END GENERATED: mcp-gating/       { skip=0; print; next }
  skip { next }
  { print }
' "$SKILLGATE" > "$TMP"

if [ "$CHECK" -eq 1 ]; then
  if diff -u "$SKILLGATE" "$TMP" >/dev/null 2>&1; then
    echo "render-skill-gate --check: skill-gate.md is in sync with gate.config.json ✓"
    exit 0
  else
    echo "render-skill-gate --check: DRIFT — skill-gate.md generated region is stale vs gate.config.json" >&2
    diff -u "$SKILLGATE" "$TMP" >&2 || true
    exit 1
  fi
fi

cp "$TMP" "$SKILLGATE"
echo "render-skill-gate: $SKILLGATE updated from $CONFIG ✓"
