#!/bin/bash
# post-knowledge-sync.sh — PostToolUse batched sync queue (OPT-04, D-B21+D-04)
# Appends modified file path to .claude/.sync-queue instead of immediate nudge.
# Emits a consolidated flush nudge when 10s idle detected between edits.
# Must exit in <50ms. Never blocks. Never calls MCP tools.
# Exits 0 always — ChromaDB down = silent skip.

trap 'exit 0' EXIT

INPUT=$(cat 2>/dev/null || true)
[ -z "$INPUT" ] && exit 0

command -v jq >/dev/null 2>&1 || exit 0

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")

case "$TOOL_NAME" in
  Write|Edit|MultiEdit) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // ""' 2>/dev/null || echo "")
[ -z "$FILE_PATH" ] && exit 0

# Normalize to relative path (macOS: /Users is symlinked to /private/Users — use realpath)
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$PROJECT_ROOT" ] && exit 0
PROJECT_ROOT=$(realpath "$PROJECT_ROOT" 2>/dev/null || echo "$PROJECT_ROOT")
FILE_PATH=$(realpath "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")
REL_PATH="${FILE_PATH#$PROJECT_ROOT/}"

# Guard against path traversal
case "$REL_PATH" in
  /*|*../*|..*) exit 0 ;;
esac

# Skip registry file itself (D-B2)
case "$REL_PATH" in
  config/chromadb-registry.json) exit 0 ;;
esac

# Match watched paths to collection
COLLECTION=""
case "$REL_PATH" in
  docs/codebase/*|docs/references/*) COLLECTION="reference" ;;
  LESSONS.md|DECISIONS.md|docs/solutions/*|\
  .planning/phases/*/*/*SUMMARY*) COLLECTION="knowledge" ;;
  .planning/phases/*/*/*|.planning/phases/*/*|memory/MEMORY.md) COLLECTION="planning" ;;
  docs/standards/*|docs/guides/*|docs/procedures/*|docs/registers/*|docs/risk/*|docs/playbooks/*) COLLECTION="governance-ops" ;;
  *) exit 0 ;;
esac

# --- Queue instead of immediate nudge (OPT-04, per D-04) ---
SYNC_QUEUE="${PROJECT_ROOT}/.claude/.sync-queue"
mkdir -p "${PROJECT_ROOT}/.claude" 2>/dev/null

# Check if queue has been idle >10s (flush trigger per D-04)
FLUSH_NOW=false
if [ -f "$SYNC_QUEUE" ]; then
    QUEUE_MTIME=$(stat -f "%m" "$SYNC_QUEUE" 2>/dev/null || stat -c "%Y" "$SYNC_QUEUE" 2>/dev/null || echo "0")
    NOW=$(date +%s)
    DELTA=$(( NOW - QUEUE_MTIME ))
    if [ "$DELTA" -gt 10 ]; then
        FLUSH_NOW=true
    fi
fi

# If flush triggered, emit consolidated nudge and clear queue BEFORE adding new entry
if [ "$FLUSH_NOW" = "true" ] && [ -f "$SYNC_QUEUE" ]; then
    QUEUED_FILES=$(sort -u "$SYNC_QUEUE" 2>/dev/null)
    QUEUED_COUNT=$(echo "$QUEUED_FILES" | grep -c . 2>/dev/null | tr -d ' ' || echo "0")
    [ "$QUEUED_FILES" = "" ] && QUEUED_COUNT=0
    if [ "$QUEUED_COUNT" -gt 0 ]; then
        echo "=== Knowledge Sync Queue Flush ==="
        echo "${QUEUED_COUNT} file(s) modified since last sync. Run /knowledge-sync to update ChromaDB."
        echo "$QUEUED_FILES" | head -5 | while read -r f; do echo "  - $f"; done
        [ "$QUEUED_COUNT" -gt 5 ] && echo "  ... and $((QUEUED_COUNT - 5)) more"
        echo ""
    fi
    rm -f "$SYNC_QUEUE"
fi

# Append current file to queue (format: relative/path|collection)
echo "${REL_PATH}|${COLLECTION}" >> "$SYNC_QUEUE" 2>/dev/null

exit 0
