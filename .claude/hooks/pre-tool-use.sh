#!/bin/bash
# Pre-tool-use hook: enforce skill gate
# Blocks Write/Edit/MultiEdit/Bash on domain files if .skill-locks/{domain} marker is absent.
# See .claude/rules/skill-gate.md for domain routing and maintenance rules.
# Fires for every tool use. Exits 0 = allow, exits 2 = block with message.

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LOCKS_DIR="${PROJECT_ROOT}/.skill-locks"

# Worktree fix: .skill-locks/ is gitignored so it won't exist in linked worktrees.
# Resolve locks from the main worktree instead.
COMMON_GIT=$(cd "$PROJECT_ROOT" && git rev-parse --git-common-dir 2>/dev/null)
if [ -n "$COMMON_GIT" ] && [ "$COMMON_GIT" != ".git" ]; then
  LOCKS_DIR="$(dirname "$COMMON_GIT")/.skill-locks"
fi

# Read tool name and input from stdin JSON — parse tool_name first with jq, fall back to python3
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")

# Only check Write, Edit, MultiEdit, Bash (for az rest / runbook operations)
case "$TOOL_NAME" in
  Write|Edit|MultiEdit|Bash) ;;
  *) exit 0 ;;
esac

# Parse tool_input only for relevant tools (deferred to avoid cost on every tool use)
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}' 2>/dev/null || echo "$INPUT" | python3 -c "import json,sys; print(json.dumps(json.load(sys.stdin).get('tool_input',{})))" 2>/dev/null || echo "{}")

# Extract file path or command for domain detection
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // .command // ""' 2>/dev/null || echo "$TOOL_INPUT" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(d.get('file_path', d.get('command', '')))
" 2>/dev/null || echo "")

check_lock() {
  local domain="$1"
  local lock_file="${LOCKS_DIR}/${domain}"
  if [ ! -f "$lock_file" ]; then
    echo "⛔ SKILL GATE BLOCKED — domain: ${domain}"
    echo ""
    echo "You must invoke the required skill(s) and create the unlock marker before proceeding."
    echo ""
    case "$domain" in
      azure)
        echo "Required: azure-m365-architect + loupe-powershell-script-writer"
        echo "Unlock:   mkdir -p .skill-locks && touch .skill-locks/azure"
        ;;
      n8n)
        echo "Required: n8n skill (workflow-architect / node-expert / code-nodes)"
        echo "Unlock:   mkdir -p .skill-locks && touch .skill-locks/n8n"
        ;;
      ghl)
        echo "Required: ghl-architect"
        echo "Unlock:   mkdir -p .skill-locks && touch .skill-locks/ghl"
        ;;
    esac
    echo ""
    echo "See .claude/rules/skill-gate.md for full instructions."
    exit 2
  fi
}

# --- Domain detection ---

# Azure / M365 / PowerShell domain
# Only match PowerShell files and scripts that are actually PowerShell/Azure
# (not generic bash scripts like index-memory-to-agentdb.sh or setup-hooks.sh)
if echo "$FILE_PATH" | grep -qE '\.(ps1|psm1|psd1)$|runbooks/'; then
  check_lock "azure"
elif echo "$FILE_PATH" | grep -qE 'scripts/' && echo "$FILE_PATH" | grep -qE '\.(ps1|psm1|psd1)$'; then
  check_lock "azure"
fi

# Azure CLI / ARM operations (Bash commands touching AA, KV, Graph)
if [ "$TOOL_NAME" = "Bash" ]; then
  if echo "$FILE_PATH" | grep -qE 'az rest|az automation|az keyvault|Microsoft\.Automation|management\.azure\.com'; then
    check_lock "azure"
  fi
fi

# n8n domain
if echo "$FILE_PATH" | grep -qE 'n8n/|loupe-cascade|loupe-audit|loupe-onboarding|\.workflow\.json'; then
  check_lock "n8n"
fi

# GHL domain
if echo "$FILE_PATH" | grep -qE 'ghl/|highlevel|leadconnector'; then
  check_lock "ghl"
fi

# --- SCAG gate: block package installs without prior supply-chain audit ---
# Detects: pip/pip3/uv install|add, npm install|i, yarn/pnpm/bun add, claude mcp add
# Requires .skill-locks/scag-approved marker (created by /supply-chain-audit on APPROVE/CONDITIONAL).
# One-shot: marker is consumed (deleted) on first allowed install.
# See .claude/rules/supply-chain-audit.md and docs/architecture/forge/dependency-install-gate.md
if [ "$TOOL_NAME" = "Bash" ]; then
  if echo "$FILE_PATH" | grep -qE '\b(pip3?|uv)\s+(install|add)\b|\bnpm\s+(install|i)\b|\b(yarn|pnpm|bun)\s+add\b|\bclaude\s+mcp\s+add\b'; then
    SCAG_MARKER="${LOCKS_DIR}/scag-approved"
    if [ ! -f "$SCAG_MARKER" ]; then
      echo "⛔ SCAG GATE — package install blocked"
      echo ""
      echo "A supply-chain audit is required before installing external dependencies."
      echo ""
      echo "1. Clone/download the package to a temp dir"
      echo "2. Run: /supply-chain-audit /tmp/{pkg}-audit --package {name} --version {ver}"
      echo "3. On APPROVE or CONDITIONAL verdict:"
      echo "   mkdir -p .skill-locks && touch .skill-locks/scag-approved"
      echo "4. Re-run this install command"
      echo ""
      echo "Pre-approved (bypass SCAG): check .claude/allowlists/mcp-preapproved.json"
      echo "See .claude/rules/supply-chain-audit.md"
      exit 2
    fi
    # One-time approval: consume marker so next install requires a fresh audit
    rm -f "$SCAG_MARKER"
  fi
fi

# --- Lessons auto-surfacing (OPT-03, per D-03) ---
# Runs AFTER skill gate checks. Non-blocking: all in subshell with || true.
# Source 1: grep LESSONS.md hot cache for file stem or domain tag matches.
# Max 3 lines injected as additionalContext. Never blocks (no exit 2).
(
    LESSONS_FILE="${PROJECT_ROOT}/LESSONS.md"
    [ -f "$LESSONS_FILE" ] || exit 0

    # Only surface for Write/Edit/MultiEdit (already filtered above, but guard explicitly)
    case "$TOOL_NAME" in
        Write|Edit|MultiEdit) ;;
        *) exit 0 ;;
    esac

    # FILE_PATH already parsed above from tool_input
    [ -z "$FILE_PATH" ] && exit 0

    # Extract file stem (basename without extension)
    FILE_STEM=$(basename "$FILE_PATH" | sed 's/\.[^.]*$//')
    [ -z "$FILE_STEM" ] && exit 0

    # Skip self-reference
    case "$FILE_STEM" in
        LESSONS) exit 0 ;;
    esac

    # Determine domain tag from file path
    DOMAIN=""
    case "$FILE_PATH" in
        *.ps1|*.psm1|*.psd1)        DOMAIN="azure-automation|powershell|azure" ;;
        */runbooks/*)                DOMAIN="azure-automation" ;;
        */n8n/*|*workflow*.json)     DOMAIN="n8n" ;;
        */.planning/*|*.planning/*)  DOMAIN="process" ;;
        */ghl/*|*highlevel*)         DOMAIN="ghl" ;;
    esac

    MATCHES=""

    # Match 1: file stem in lesson text (exact match priority, per D-03)
    if [ -n "$FILE_STEM" ]; then
        MATCHES=$(grep -B 1 -A 2 "$FILE_STEM" "$LESSONS_FILE" 2>/dev/null \
            | grep "^\*\*Faire\*\*" | head -2 | sed 's/\*\*Faire\*\* //' | cut -c1-120 || true)
    fi

    # Match 2: domain tag (fallback if no file stem match, per D-03)
    if [ -z "$MATCHES" ] && [ -n "$DOMAIN" ]; then
        MATCHES=$(grep -E -A 3 "^### \[(${DOMAIN})\]" "$LESSONS_FILE" 2>/dev/null \
            | grep "^\*\*Faire\*\*" | head -3 | sed 's/\*\*Faire\*\* //' | cut -c1-120 || true)
    fi

    # Emit max 3 lines as additionalContext (stdout)
    if [ -n "$MATCHES" ]; then
        echo "=== Lessons Reminder (auto-surfaced) ==="
        echo "$MATCHES" | head -3
        echo ""
    fi
) 2>/dev/null || true

exit 0
