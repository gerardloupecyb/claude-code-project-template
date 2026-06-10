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
STATE_MD="${PROJECT_ROOT}/.planning/STATE.md"
STATE_YML="${PROJECT_ROOT}/.planning/state.yml"

# --- Write state.yml BEFORE memory-retention (write early, survive interruption) ---
# Per D-01: state.yml is the machine contract; MEMORY.md stays the human journal.
# Per D-02: pre-compact writes state.yml but does NOT query ChromaDB.
if [ -d "${PROJECT_ROOT}/.planning" ]; then
    # Extract phase from STATE.md frontmatter (more reliable than MEMORY.md for machine parsing)
    CURRENT_PHASE=""
    if [ -f "$STATE_MD" ]; then
        CURRENT_PHASE=$(python3 -c "
import yaml, sys, re
try:
    text = open(sys.argv[1]).read()
    parts = text.split('---', 2)
    if len(parts) >= 3:
        fm = yaml.safe_load(parts[1])
        st = fm.get('status', '')
        m = re.search(r'Phase\s+([\d.]+)', st)
        print(m.group(1) if m else '')
    else:
        print('')
except Exception:
    print('')
" "$STATE_MD" 2>/dev/null || echo "")
        [ -z "$CURRENT_PHASE" ] && [ -f "$STATE_MD" ] && \
            echo "⚠ pre-compact: could not extract phase from STATE.md — state.yml will use 'unknown'" >&2
    fi

    # Extract next_step from MEMORY.md
    NEXT_STEP_YML=$(grep -i "prochaine.*tape" "$MEMORY_FILE" 2>/dev/null | head -1 | sed 's/.*: *//' || true)

    # Write state.yml using python3 yaml (NEVER use yq — not installed per RESEARCH.md)
    python3 -c "
import yaml, sys
from datetime import date
d = {
    'schema_version': '1.0',
    'phase': sys.argv[1] if sys.argv[1] else 'unknown',
    'plan': 0,
    'status': 'executing',
    'blockers': [],
    'next_step': sys.argv[2] if sys.argv[2] else 'unknown',
    'last_session': date.today().isoformat(),
}
with open(sys.argv[3], 'w') as f:
    f.write('# .planning/state.yml - machine-readable hook contract\n')
    f.write('# Written by: pre-compact.sh | Read by: session-start.sh, pre-agent.sh\n')
    yaml.dump(d, f, default_flow_style=False, allow_unicode=True)
" "${CURRENT_PHASE:-unknown}" "${NEXT_STEP_YML:-unknown}" "$STATE_YML" 2>/dev/null || true

    # Stage state.yml alongside MEMORY.md
    git -C "$PROJECT_ROOT" add ".planning/state.yml" 2>/dev/null || true
fi

# --- Flush sync queue safety net (OPT-04, per D-04) ---
SYNC_QUEUE="${PROJECT_ROOT}/.claude/.sync-queue"
if [ -f "$SYNC_QUEUE" ]; then
    QUEUED_COUNT=$(wc -l < "$SYNC_QUEUE" 2>/dev/null | tr -d ' ')
    if [ "${QUEUED_COUNT:-0}" -gt 0 ]; then
        echo "[pre-compact] ${QUEUED_COUNT} file(s) in sync queue — run /knowledge-sync after resumption" >&2
    fi
    # Don't delete the queue here — let session-start or explicit /knowledge-sync handle it
    # Just warn so the user knows
fi

# Enforce MEMORY.md retention before writing the snapshot.
"${PROJECT_ROOT}/.claude/hooks/memory-retention.sh" 2>/dev/null || true

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

# Stage only — auto-commit removed (todo 104, incident bd0b214 wrong-branch).
# Commit path is /commit-push exclusively; pre-compact must not touch lineage.
if git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$PROJECT_ROOT" add "memory/MEMORY.md" 2>/dev/null || true
    [ -f "$LESSONS_FILE" ] && git -C "$PROJECT_ROOT" add "LESSONS.md" 2>/dev/null || true
fi
