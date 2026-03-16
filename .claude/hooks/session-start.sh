#!/bin/bash
# Session start hook: re-inject MEMORY.md and LESSONS.md into context.
# Fires on all 4 session events: startup, compact, resume, clear.
# Stdout text becomes additionalContext for Claude.
# Always exits 0.

trap 'exit 0' EXIT

# Read source from stdin JSON
SOURCE=$(read -t 2 STDIN_DATA 2>/dev/null && echo "$STDIN_DATA" | python3 -c "import json,sys; print(json.load(sys.stdin).get('source','unknown'))" 2>/dev/null || echo "unknown")

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
MEMORY_FILE="${PROJECT_ROOT}/memory/MEMORY.md"
LESSONS_FILE="${PROJECT_ROOT}/LESSONS.md"

# Emit MEMORY.md if it exists and is non-empty
if [ -s "$MEMORY_FILE" ]; then
    echo "=== MEMORY.md (auto-injected by SessionStart hook) ==="
    cat "$MEMORY_FILE"
    echo ""
fi

# Emit first 10 lesson entries from LESSONS.md (entry-count based)
if [ -s "$LESSONS_FILE" ]; then
    echo "=== LESSONS.md (first 10 entries, auto-injected) ==="
    python3 -c "
import sys

with open(sys.argv[1], 'r') as f:
    lines = f.readlines()

in_comment = False
entry_count = 0
header_printed = False

for line in lines:
    stripped = line.strip()

    # Track HTML comment blocks
    if '<!--' in stripped and '-->' not in stripped:
        in_comment = True
        continue
    if '-->' in stripped:
        in_comment = False
        continue
    if in_comment:
        continue

    # Count ### headings as entry boundaries
    if stripped.startswith('### ') and not stripped.startswith('### [template]'):
        entry_count += 1
        if entry_count > 10:
            break

    # Print everything until we hit 10 entries
    if entry_count <= 10:
        if not header_printed and stripped.startswith('#'):
            header_printed = True
        if header_printed:
            sys.stdout.write(line)
" "$LESSONS_FILE" 2>/dev/null || cat "$LESSONS_FILE"
    echo ""
fi

# Add contextual note based on source
case "$SOURCE" in
    compact)
        echo "[Note: Session resumed after compaction - MEMORY.md and LESSONS.md re-injected above]"
        ;;
    clear)
        echo "[Note: Context cleared - MEMORY.md and LESSONS.md re-injected for continuity]"
        ;;
    resume)
        echo "[Note: Session resumed - MEMORY.md and LESSONS.md re-injected above]"
        ;;
esac
