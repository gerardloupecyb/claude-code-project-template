#!/bin/bash
# Pre-agent hook: log agent spawns for session-gate Check 19 audit.
# Fires on every Agent tool call via PreToolUse hook.
# Receives tool input JSON on stdin. Always exits 0 — never blocks.

trap 'exit 0' EXIT

TIMESTAMP=$(date +%Y-%m-%dT%H:%M:%S)
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LOG_FILE="${PROJECT_ROOT}/.claude/workspace/agent-log.txt"

# Ensure workspace dir exists
mkdir -p "${PROJECT_ROOT}/.claude/workspace" 2>/dev/null

# Parse description and subagent_type from stdin JSON (truncate desc to 60 chars)
INPUT=$(cat 2>/dev/null)
DESC=$(echo "$INPUT" | jq -r '.description // "unknown"' 2>/dev/null | cut -c1-60 || echo "unknown")
TYPE=$(echo "$INPUT" | jq -r '.subagent_type // "general"' 2>/dev/null || echo "general")

echo "${TIMESTAMP} | ${TYPE} | ${DESC}" >> "${LOG_FILE}" 2>/dev/null
