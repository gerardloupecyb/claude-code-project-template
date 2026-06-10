#!/bin/bash
# Pre-tool-use hook: block mutating MCP calls on prod without skill lock
# Separate from pre-tool-use.sh (which handles file edits/commands).
# This hook reasons by tool_name pattern, not file_path.
# See .claude/rules/skill-gate.md and .claude/rules/governance.md.

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LOCKS_DIR="${PROJECT_ROOT}/.skill-locks"

# Worktree fix: .skill-locks/ is gitignored so it won't exist in linked worktrees.
# Resolve locks from the main worktree instead.
COMMON_GIT=$(cd "$PROJECT_ROOT" && git rev-parse --git-common-dir 2>/dev/null)
if [ -n "$COMMON_GIT" ] && [ "$COMMON_GIT" != ".git" ]; then
  LOCKS_DIR="$(dirname "$COMMON_GIT")/.skill-locks"
fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")

# Mutation verbs — if the tool_name contains one of these, it's a write operation
MUTATION_VERBS='create|update|delete|remove|send|upsert|patch|add-tags|remove-tags|edit'
# Read verbs — never blocked
# get, list, search, fetch, retrieve, describe, check

block_mcp() {
  local domain="$1"
  local lock_file="${LOCKS_DIR}/${domain}"
  if [ ! -f "$lock_file" ]; then
    echo "⛔ MCP GATE BLOCKED — ${domain} prod mutation without skill lock"
    echo ""
    echo "Tool: ${TOOL_NAME}"
    echo ""
    case "$domain" in
      n8n)
        echo "Required: load n8n skill + mkdir -p .skill-locks && touch .skill-locks/n8n"
        echo "Dev-first rule (CARL RULE_15): use n8n-dev-mcp for changes, n8n-mcp for prod verification only."
        ;;
      ghl)
        echo "Required: load ghl-architect + mkdir -p .skill-locks && touch .skill-locks/ghl"
        ;;
    esac
    echo ""
    echo "See .claude/rules/skill-gate.md for full instructions."
    exit 2
  fi
}

# --- n8n prod mutations (n8n-mcp only, NOT n8n-dev-mcp) ---
if echo "$TOOL_NAME" | grep -q '^mcp__n8n-mcp__'; then
  if echo "$TOOL_NAME" | grep -qiE "$MUTATION_VERBS"; then
    block_mcp "n8n"
  fi
fi

# --- GHL prod mutations (both tenants) ---
if echo "$TOOL_NAME" | grep -qE '^mcp__prod-ghl-(mcp|care-mcp)__'; then
  if echo "$TOOL_NAME" | grep -qiE "$MUTATION_VERBS"; then
    block_mcp "ghl"
  fi
fi

exit 0
