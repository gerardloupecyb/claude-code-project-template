#!/bin/bash
# Pre-tool-use hook: block mutating MCP calls on prod without skill lock (DATA-DRIVEN — gate.config.json)
# Separate from pre-tool-use.sh (which handles file edits/commands).
# This hook reasons by tool_name pattern, not file_path.
# Gated servers + mutation verbs are read from gate.config.json `gated_mcp` / `mutation_verbs` — no inline literals.
# See .claude/rules/skill-gate.md and .claude/rules/governance.md.
#
# ALWAYS-ON (AC-2-2): the prod-MCP gate is keyed on `gated_mcp`, INDEPENDENT of protected_domains.
# FAIL-OPEN (AC-2-3): missing/malformed config -> allow (exit 0) but LOUDLY (stdout+stderr + audit append || true).
# NEVER-SILENTLY-UNGATE: a MUTATION that can't be enforced (gated_mcp empty, or matched entry has no marker)
# emits an OBSERVABLE stderr+audit warning before allowing — the EoP "silent disable" threat is never silent.

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LOCKS_DIR="${PROJECT_ROOT}/.skill-locks"
GATE_CONFIG="${PROJECT_ROOT}/.claude/gate.config.json"

# Worktree fix: .skill-locks/ is gitignored so it won't exist in linked worktrees.
# Resolve locks from the main worktree instead. (gate.config.json is TRACKED, present in each worktree.)
COMMON_GIT=$(cd "$PROJECT_ROOT" && git rev-parse --git-common-dir 2>/dev/null)
if [ -n "$COMMON_GIT" ] && [ "$COMMON_GIT" != ".git" ]; then
  LOCKS_DIR="$(dirname "$COMMON_GIT")/.skill-locks"
fi

# Shared gate-config chokepoint: ONE place validates file + JSON + shape/type + regex-compilability.
GATE_LIB="$(dirname "${BASH_SOURCE[0]}")/lib/gate-config.sh"
if [ -f "$GATE_LIB" ]; then
  . "$GATE_LIB"
else
  echo "⚠ MCP GATE FAIL-OPEN (pre-mcp-gate): gate-config lib missing ($GATE_LIB) — prod-MCP gate NOT enforced this call." >&2
  exit 0
fi

# Observable-but-allow: a mutation reached us but the config can't enforce a lock. Surface it (stderr+audit)
# so an emptied/misconfigured gated_mcp can never silently ungate prod mutations. Caller decides to exit 0.
warn_inert() {
  local reason="$1"
  printf '⚠ MCP GATE INERT (pre-mcp-gate): %s — prod-MCP MUTATION %s NOT gated this call. Check gate.config.json gated_mcp.\n' "$reason" "$TOOL_NAME" >&2
  { mkdir -p "$HOME/.claude" && printf '[%s] pre-mcp-gate inert: %s (%s)\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$reason" "$TOOL_NAME" >> "$HOME/.claude/gate-failopen.log"; } 2>/dev/null || true
}

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")

# Only MCP tool calls are relevant (the settings matcher already narrows this; guard explicitly)
case "$TOOL_NAME" in
  mcp__*) ;;
  *) exit 0 ;;
esac

# A2 RUNTIME FLOOR (Option-3 / AC-2-7). TRUST the write-time-validated config (validate-gate-config.sh runs
# in .githooks/pre-commit on the STAGED BLOB + CI). At runtime keep ONLY the minimal floor: present + valid
# JSON + array-type. Deep validation (regex-compilability, per-element, R3 vacuity) is WRITE-TIME ONLY —
# NOT re-run on every MCP call. Fail-OPEN OBSERVABLY (exit 0 = allow) on a floor miss.
gate_runtime_floor_ok "$GATE_CONFIG" || { gate_fail_open "pre-mcp-gate" "$GATE_CONFIG_REASON"; exit 0; }

# Generic mutation verbs from config, resolved through the ALWAYS-ON gate floor (AC-2-7 D2): an empty,
# vacuous (blank-after-trim / pure-non-word), or uncompilable mutation_verbs would silently UN-GATE prod
# mutations — the verb match under-fires, so every call is treated as a read and allowed. gate_resolve_alwayson
# falls back to the built-in default (the gate STAYS ON) with an OBSERVABLE gate_degraded note. NEVER silent.
MV_DEFAULT='create|update|delete|remove|send|upsert|patch|add-tags|remove-tags|edit'
MV_CFG=$(jq -r '.mutation_verbs // ""' "$GATE_CONFIG" 2>/dev/null)
gate_resolve_alwayson "$MV_CFG" "$MV_DEFAULT" "pre-mcp-gate" "mutation_verbs"
MUTATION_VERBS="$GATE_ALWAYSON_RE"

# Read ops are NEVER blocked — bail before any gate logic (and before any inert warning).
echo "$TOOL_NAME" | grep -qiE "$MUTATION_VERBS" || exit 0

# From here the call is a MUTATION on an mcp__ tool.
COUNT=$(jq -r '(.gated_mcp // []) | length' "$GATE_CONFIG" 2>/dev/null)
[ -n "$COUNT" ] || COUNT=0

# gated_mcp empty/absent: the gate has nothing to enforce. NOT silent — observable warn, then allow.
if [ "$COUNT" -eq 0 ]; then
  warn_inert "gated_mcp is empty/absent"
  exit 0
fi

# Find which gated_mcp entry this tool belongs to (by server_prefix). Index-iteration keeps multi-line
# `message` fields intact (a US-joined stream would break on the embedded newline in the n8n guidance).
MATCH_IDX=-1
i=0
while [ "$i" -lt "$COUNT" ]; do
  pfx=$(jq -r ".gated_mcp[$i].server_prefix // \"\"" "$GATE_CONFIG" 2>/dev/null)
  if [ -n "$pfx" ]; then
    case "$TOOL_NAME" in
      "$pfx"*) MATCH_IDX=$i; break ;;
    esac
  fi
  i=$((i + 1))
done

# Mutation on a server that is NOT in the gated set (e.g. stripe) -> correctly allowed, silently.
[ "$MATCH_IDX" -ge 0 ] || exit 0

m_marker=$(jq -r ".gated_mcp[$MATCH_IDX].marker // \"\"" "$GATE_CONFIG" 2>/dev/null)
m_msg=$(jq -r ".gated_mcp[$MATCH_IDX].message // \"\"" "$GATE_CONFIG" 2>/dev/null)

# Matched a gated server but the entry has no marker: cannot enforce a lock. NOT silent — observable warn.
if [ -z "$m_marker" ]; then
  warn_inert "gated_mcp[$MATCH_IDX] has no marker"
  exit 0
fi

if [ ! -f "${LOCKS_DIR}/${m_marker}" ]; then
  echo "⛔ MCP GATE BLOCKED — ${m_marker} prod mutation without skill lock"
  echo ""
  echo "Tool: ${TOOL_NAME}"
  echo ""
  printf '%s\n' "$m_msg"
  echo ""
  echo "See .claude/rules/skill-gate.md for full instructions."
  exit 2
fi

exit 0
