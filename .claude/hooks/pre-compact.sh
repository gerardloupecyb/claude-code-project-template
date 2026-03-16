#!/bin/bash
# Pre-compact hook: snapshot MEMORY.md state before context compaction.
# Writes a summary between <!-- pre-compact snapshot --> markers.
# Always exits 0 — never blocks compaction.

trap 'exit 0' EXIT

# Drain stdin (receives JSON from Claude Code)
read -t 2 STDIN_DATA 2>/dev/null || true

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
MEMORY_FILE="${PROJECT_ROOT}/memory/MEMORY.md"
LESSONS_FILE="${PROJECT_ROOT}/LESSONS.md"

# Skip if MEMORY.md doesn't exist
[ -f "$MEMORY_FILE" ] || exit 0

# Extract "Prochaine etape" from MEMORY.md
NEXT_STEP=$(grep -i "prochaine.*tape" "$MEMORY_FILE" 2>/dev/null | head -1 | sed 's/.*: *//' || true)

# Get last 3 git commits (one-line format)
RECENT_COMMITS=""
if git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    RECENT_COMMITS=$(git -C "$PROJECT_ROOT" log --oneline -3 2>/dev/null || true)
    DIRTY_FILES=$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null | head -10 || true)
fi

# Build snapshot block
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
SNAPSHOT="<!-- pre-compact snapshot -->
**Snapshot pre-compaction** (${TIMESTAMP})

- **Prochaine etape:** ${NEXT_STEP:-non definie}
- **Derniers commits:**
$(echo "$RECENT_COMMITS" | sed 's/^/  - /' || true)
$([ -n "$DIRTY_FILES" ] && echo "- **Fichiers modifies:**" && echo "$DIRTY_FILES" | head -5 | sed 's/^/  - /' || true)
<!-- /pre-compact snapshot -->"

# Replace content between markers (or append if markers missing)
if grep -q '<!-- pre-compact snapshot -->' "$MEMORY_FILE" 2>/dev/null; then
    # Use python3 for reliable multi-line replacement
    python3 -c "
import re, sys
with open(sys.argv[1], 'r') as f:
    content = f.read()
pattern = r'<!-- pre-compact snapshot -->.*?<!-- /pre-compact snapshot -->'
replacement = sys.argv[2]
content = re.sub(pattern, replacement, content, flags=re.DOTALL)
with open(sys.argv[1], 'w') as f:
    f.write(content)
" "$MEMORY_FILE" "$SNAPSHOT" || true
else
    # Markers missing — append them
    printf '\n%s\n' "$SNAPSHOT" >> "$MEMORY_FILE" || true
fi

# Stage only MEMORY.md and LESSONS.md — NEVER git add .
if git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$PROJECT_ROOT" add "memory/MEMORY.md" 2>/dev/null || true
    [ -f "$LESSONS_FILE" ] && git -C "$PROJECT_ROOT" add "LESSONS.md" 2>/dev/null || true
    git -C "$PROJECT_ROOT" commit -m "pre-compact snapshot" 2>/dev/null || true
fi
