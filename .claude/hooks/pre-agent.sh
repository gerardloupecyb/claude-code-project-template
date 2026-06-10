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

# --- Subagent context auto-enrichment (OPT-05, per D-05) ---
# Read state.yml and inject phase context into subagent additionalContext (stdout).
# Non-blocking: state.yml absent or unreadable = silent skip (exit 0).
STATE_YML="${PROJECT_ROOT}/.planning/state.yml"

if [ -f "$STATE_YML" ]; then
    # Parse state.yml via python3 yaml (yq NOT installed per RESEARCH.md)
    CONTEXT_BLOCK=$(python3 -c "
import yaml, sys
try:
    d = yaml.safe_load(open(sys.argv[1]))
    phase = d.get('phase', '')
    status = d.get('status', '')
    plan = d.get('plan', 0)
    next_step = d.get('next_step', '')
    blockers = d.get('blockers', [])

    if phase:
        print('## Context auto-injected')
        print(f'Active phase: {phase} (plan {plan}, status: {status})')
        if next_step:
            print(f'Next step: {next_step}')
        if blockers:
            print(f'Blockers: {\", \".join(str(b) for b in blockers)}')
        print('Source: .planning/state.yml — verify critical claims against source files.')
except Exception:
    pass
" "$STATE_YML" 2>/dev/null || true)

    # Emit to stdout (becomes additionalContext for subagent)
    # Keep under 200 words (swarm-patterns.md limit)
    if [ -n "$CONTEXT_BLOCK" ]; then
        echo ""
        echo "$CONTEXT_BLOCK"
        echo ""
    fi
fi
