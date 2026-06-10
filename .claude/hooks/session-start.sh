#!/bin/bash
# Session start hook: inject compact MEMORY summary into context.
# Fires on startup and compact only (see settings.json SessionStart).
# Stdout text becomes additionalContext for Claude.
# Always exits 0.

trap 'exit 0' EXIT

# Read source from stdin JSON (must come first — used to gate startup-only logic)
SOURCE=$(read -t 2 STDIN_DATA 2>/dev/null && echo "$STDIN_DATA" | python3 -c "import json,sys; print(json.load(sys.stdin).get('source','unknown'))" 2>/dev/null || echo "unknown")

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
MEMORY_FILE="${PROJECT_ROOT}/memory/MEMORY.md"

# Reset agent spawn log on startup only (for session-gate Check 19)
if [ "$SOURCE" = "startup" ]; then
    mkdir -p "${PROJECT_ROOT}/.claude/workspace" 2>/dev/null
    > "${PROJECT_ROOT}/.claude/workspace/agent-log.txt" 2>/dev/null
fi

# ChromaDB health check and auto-start
if command -v docker >/dev/null 2>&1; then
    CHROMA_PORT="${CHROMA_PORT:-8000}"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${CHROMA_PORT}/api/v2/heartbeat" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" != "200" ]; then
        docker compose -f "${PROJECT_ROOT}/docker-compose.chromadb.yml" up -d 2>/dev/null
        HTTP_CODE="000"
        for i in 1 2 3 4 5; do
            sleep 0.5
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${CHROMA_PORT}/api/v2/heartbeat" 2>/dev/null || echo "000")
            [ "$HTTP_CODE" = "200" ] && break
        done
        if [ "$HTTP_CODE" != "200" ]; then
            echo "ChromaDB not reachable. Check Docker Desktop is running."
        fi
    fi
    if [ "$HTTP_CODE" = "200" ]; then
        REGISTRY="${PROJECT_ROOT}/config/chromadb-registry.json"
        if [ -f "$REGISTRY" ]; then
            python3 -c "
import json, sys
from datetime import datetime, timezone, timedelta
reg = json.load(open(sys.argv[1]))
collections = list(reg.get('collections', {}).keys())
stale = []
now = datetime.now(timezone.utc)
for name, col in reg.get('collections', {}).items():
    ls = col.get('last_sync')
    if ls:
        dt = datetime.fromisoformat(ls.replace('Z', '+00:00'))
        if (now - dt) > timedelta(hours=24):
            stale.append(name)
    else:
        stale.append(name)
print(f'ChromaDB: {len(collections)} collections active: {\", \".join(collections)}')
if stale:
    print(f'Stale collections (>24h): {\", \".join(stale)}. Run /knowledge-sync to refresh.')
" "$REGISTRY" 2>/dev/null
        fi

        # --- Auto incremental sync on startup (Option A) ---
        # Uses chroma-mcp's uv tool env (chromadb pre-installed — no cold start)
        # Runs only on 'startup' source (not compact) to keep resume fast
        # Skipped if another sync is running (lock file)
        if [ "$SOURCE" = "startup" ]; then
            CHROMA_PY="${HOME}/.local/share/uv/tools/chroma-mcp/bin/python"
            SYNC_SCRIPT="${PROJECT_ROOT}/scripts/knowledge-sync.py"
            SYNC_LOCK="/tmp/loupe-knowledge-sync.lock"
            SYNC_LOG="${PROJECT_ROOT}/.claude/workspace/knowledge-sync.log"
            mkdir -p "${PROJECT_ROOT}/.claude/workspace" 2>/dev/null
            if [ -x "$CHROMA_PY" ] && [ -f "$SYNC_SCRIPT" ]; then
                # Acquire lock (stale lock > 60s is cleared)
                if [ -f "$SYNC_LOCK" ]; then
                    LOCK_AGE=$(($(date +%s) - $(stat -f "%m" "$SYNC_LOCK" 2>/dev/null || stat -c "%Y" "$SYNC_LOCK" 2>/dev/null || echo 0)))
                    [ "$LOCK_AGE" -gt 60 ] && rm -f "$SYNC_LOCK"
                fi
                if [ ! -f "$SYNC_LOCK" ]; then
                    echo "$$" > "$SYNC_LOCK"
                    # Run sync — 20s soft cap via background + wait (timeout is GNU-only, not on macOS by default)
                    SYNC_TMP=$(mktemp -t loupe-sync.XXXXXX 2>/dev/null || echo "/tmp/loupe-sync-$$.out")
                    (cd "$PROJECT_ROOT" && "$CHROMA_PY" "$SYNC_SCRIPT" >"$SYNC_TMP" 2>>"$SYNC_LOG") &
                    SYNC_PID=$!
                    SYNC_WAITED=0
                    while kill -0 "$SYNC_PID" 2>/dev/null; do
                        [ "$SYNC_WAITED" -ge 20 ] && kill "$SYNC_PID" 2>/dev/null && break
                        sleep 1
                        SYNC_WAITED=$((SYNC_WAITED + 1))
                    done
                    wait "$SYNC_PID" 2>/dev/null
                    SYNC_CODE=$?
                    SYNC_OUT=$(cat "$SYNC_TMP" 2>/dev/null)
                    rm -f "$SYNC_TMP" "$SYNC_LOCK"
                    # Extract per-collection line from the "=== Sync complete ===" section
                    SYNC_DELTA=$(echo "$SYNC_OUT" | awk '/=== Sync complete ===/{flag=1;next} flag' | awk -F'[ :|]+' '$3+0 > 0 {printf "%s:+%s ", $2, $3}')
                    if [ -n "$SYNC_DELTA" ]; then
                        echo "ChromaDB auto-sync: ${SYNC_DELTA}"
                    elif [ "$SYNC_CODE" -ne 0 ]; then
                        echo "ChromaDB auto-sync: skipped (exit=${SYNC_CODE}, see .claude/workspace/knowledge-sync.log)"
                    fi
                fi
            fi
        fi
    fi
fi

# --- Infra component upgrade check (warn-only, never block) ---
if [ "$SOURCE" = "startup" ]; then
    INFRA_SCRIPT="${PROJECT_ROOT}/scripts/upstream-watch/check-infra-drift.sh"
    if [ -x "$INFRA_SCRIPT" ]; then
        INFRA_TMP=$(mktemp -t loupe-infra.XXXXXX 2>/dev/null || echo "/tmp/loupe-infra-$$.out")
        ("$INFRA_SCRIPT" --quiet > "$INFRA_TMP" 2>&1) &
        INFRA_PID=$!
        INFRA_WAITED=0
        while kill -0 "$INFRA_PID" 2>/dev/null; do
            [ "$INFRA_WAITED" -ge 15 ] && kill "$INFRA_PID" 2>/dev/null && break
            sleep 1
            INFRA_WAITED=$((INFRA_WAITED + 1))
        done
        wait "$INFRA_PID" 2>/dev/null
        INFRA_OUT=$(cat "$INFRA_TMP" 2>/dev/null)
        rm -f "$INFRA_TMP"
        if [ -n "$INFRA_OUT" ]; then
            echo "$INFRA_OUT"
            echo ""
        fi
    fi
fi
# --- end infra upgrade check ---

# --- Upstream drift auto-resolve (warn-only, never block) ---
if [ "$SOURCE" = "startup" ]; then
    AUTO_RESOLVE_SCRIPT="${PROJECT_ROOT}/scripts/upstream-watch/auto-resolve.sh"
    if [ -x "$AUTO_RESOLVE_SCRIPT" ]; then
        AUTO_RESOLVE_STDOUT=$(mktemp -t loupe-upstream-out.XXXXXX 2>/dev/null || echo "/tmp/loupe-upstream-out-$$.log")
        AUTO_RESOLVE_STDERR=$(mktemp -t loupe-upstream-err.XXXXXX 2>/dev/null || echo "/tmp/loupe-upstream-err-$$.log")
        ("$AUTO_RESOLVE_SCRIPT" > "$AUTO_RESOLVE_STDOUT" 2> "$AUTO_RESOLVE_STDERR") &
        AUTO_RESOLVE_PID=$!
        AUTO_RESOLVE_WAITED=0
        while kill -0 "$AUTO_RESOLVE_PID" 2>/dev/null; do
            [ "$AUTO_RESOLVE_WAITED" -ge 30 ] && kill "$AUTO_RESOLVE_PID" 2>/dev/null && break
            sleep 1
            AUTO_RESOLVE_WAITED=$((AUTO_RESOLVE_WAITED + 1))
        done
        wait "$AUTO_RESOLVE_PID" 2>/dev/null
        AUTO_RESOLVE_OUT=$(cat "$AUTO_RESOLVE_STDOUT" 2>/dev/null)
        AUTO_RESOLVE_ERR=$(cat "$AUTO_RESOLVE_STDERR" 2>/dev/null)
        rm -f "$AUTO_RESOLVE_STDOUT" "$AUTO_RESOLVE_STDERR"
        if [ -n "$AUTO_RESOLVE_ERR" ]; then
            printf "%s\n" "$AUTO_RESOLVE_ERR" >&2
        fi
        if [ -n "$AUTO_RESOLVE_OUT" ]; then
            echo "$AUTO_RESOLVE_OUT"
            echo ""
        fi
    fi
fi
# --- end upstream drift auto-resolve ---

# --- Stale todo check (pending todos on completed phases) ---
if [ "$SOURCE" = "startup" ]; then
    TODOS_DIR="${PROJECT_ROOT}/.planning/todos/pending"
    ROADMAP="${PROJECT_ROOT}/.planning/ROADMAP.md"
    if [ -d "$TODOS_DIR" ] && [ -f "$ROADMAP" ]; then
        STALE_COUNT=$(python3 -c "
import re, os, sys
roadmap = open(sys.argv[1]).read()
completed = set()
for m in re.finditer(r'^\- \[x\] \*\*Phase (\d+(?:\.\d+)?)', roadmap, re.MULTILINE):
    completed.add(m.group(1))
    # Also add zero-padded variant
    parts = m.group(1).split('.')
    completed.add(parts[0].zfill(2) + ('.' + parts[1] if len(parts) > 1 else ''))
stale = 0
for f in os.listdir(sys.argv[2]):
    if not f.endswith('.md'): continue
    try:
        content = open(os.path.join(sys.argv[2], f)).read(500)
        pm = re.search(r'^phase:\s*[\"'\'']*([^\"'\''\\n]+)', content, re.MULTILINE)
        if pm and pm.group(1).strip('\" ') in completed:
            stale += 1
    except: pass
print(stale)
" "$ROADMAP" "$TODOS_DIR" 2>/dev/null || echo "0")
        if [ "$STALE_COUNT" -gt 0 ]; then
            echo "⚠ ${STALE_COUNT} stale todo(s) on completed phases. Run /todo stale to triage."
        fi
    fi
fi
# --- end stale todo check ---

# --- Phase context from state.yml (OPT-02, per D-02) ---
STATE_YML="${PROJECT_ROOT}/.planning/state.yml"
ACTIVE_PHASE=""
ACTIVE_STATUS=""
ACTIVE_NEXT=""
ACTIVE_BLOCKERS=""

if [ -f "$STATE_YML" ]; then
    STATE_JSON=$(python3 -c "
import yaml, json, sys
try:
    d = yaml.safe_load(open(sys.argv[1]))
    print(json.dumps(d))
except Exception:
    print('{}')
" "$STATE_YML" 2>/dev/null || echo "{}")
    ACTIVE_PHASE=$(echo "$STATE_JSON" | jq -r '.phase // ""' 2>/dev/null || true)
    ACTIVE_STATUS=$(echo "$STATE_JSON" | jq -r '.status // ""' 2>/dev/null || true)
    ACTIVE_NEXT=$(echo "$STATE_JSON" | jq -r '.next_step // ""' 2>/dev/null || true)
    ACTIVE_BLOCKERS=$(echo "$STATE_JSON" | jq -r '(.blockers // []) | join(", ")' 2>/dev/null || true)

    # Emit state summary
    if [ -n "$ACTIVE_PHASE" ]; then
        echo "=== Phase Position (from state.yml) ==="
        echo "Phase: ${ACTIVE_PHASE} | Status: ${ACTIVE_STATUS} | Next: ${ACTIVE_NEXT}"
        [ -n "$ACTIVE_BLOCKERS" ] && echo "Blockers: ${ACTIVE_BLOCKERS}"
        echo ""
    fi
fi

# --- ChromaDB phase context injection (OPT-02, per D-02) ---
# Per D-02: ChromaDB query happens in session-start ONLY (not pre-compact).
# Per RESEARCH.md Pitfall 1: use GET with where filter, NOT query_texts.
# Per Pitfall 3: look up collection ID by name, NEVER hardcode UUIDs.
if [ -n "$ACTIVE_PHASE" ] && [ "${HTTP_CODE:-000}" = "200" ]; then
    CHROMA_BASE="http://localhost:${CHROMA_PORT:-8000}/api/v2/tenants/default_tenant/databases/default_database"

    # Lookup planning collection ID by name (IDs change after /knowledge-sync --full)
    PLANNING_CID=$(curl -s "${CHROMA_BASE}/collections" 2>/dev/null \
        | python3 -c "
import sys, json
try:
    cols = json.load(sys.stdin)
    print(next((c['id'] for c in cols if c['name'] == 'planning'), ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

    if [ -n "$PLANNING_CID" ]; then
        # Query context docs for this phase via where filter (not semantic query)
        PHASE_CONTEXT=$(curl -s -X POST "${CHROMA_BASE}/collections/${PLANNING_CID}/get" \
            -H "Content-Type: application/json" \
            -d "{\"where\": {\"phase\": \"${ACTIVE_PHASE}\", \"kind\": \"context\"}, \"limit\": 5, \"include\": [\"documents\", \"metadatas\"]}" \
            2>/dev/null)

        # Extract and format top decisions/risks (max 5 items, 300 chars each)
        CONTEXT_LINES=$(echo "$PHASE_CONTEXT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    docs = d.get('documents', []) or []
    metas = d.get('metadatas', []) or []
    seen = 0
    for i, doc in enumerate(docs):
        if not doc or seen >= 5:
            break
        kind = metas[i].get('kind', 'doc') if i < len(metas) and metas[i] else 'doc'
        snippet = doc[:300].replace('\n', ' ').strip()
        if snippet:
            print(f'  [{kind}] {snippet}')
            seen += 1
except Exception:
    pass
" 2>/dev/null || true)

        if [ -n "$CONTEXT_LINES" ]; then
            echo "=== Phase ${ACTIVE_PHASE} Context (ChromaDB auto-query) ==="
            echo "$CONTEXT_LINES"
            echo ""
        fi
    fi
fi

# --- Graphify watch auto-start (startup only) ---
# Launches graphify.watch in background if: graphify installed, graph.json exists, no watch already running.
# Uses fsevents (macOS) — ~0% CPU idle, 1-3s AST rebuild on code changes, zero LLM.
# Docs changes are flagged only (needs_update) — not auto-extracted.
if [ "$SOURCE" = "startup" ]; then
    GRAPHIFY_BIN=$(which graphify 2>/dev/null)
    GRAPHIFY_GRAPH="${PROJECT_ROOT}/graphify-out/graph.json"
    GRAPHIFY_PYTHON_FILE="${PROJECT_ROOT}/graphify-out/.graphify_python"
    if [ -n "$GRAPHIFY_BIN" ] && [ -f "$GRAPHIFY_GRAPH" ]; then
        # Check if watch already running
        if ! pgrep -f "graphify.watch" >/dev/null 2>&1; then
            GRAPHIFY_PY="python3"
            [ -f "$GRAPHIFY_PYTHON_FILE" ] && GRAPHIFY_PY="$(cat "$GRAPHIFY_PYTHON_FILE")"
            mkdir -p "${PROJECT_ROOT}/.claude/workspace" 2>/dev/null
            (
                cd "$PROJECT_ROOT" && nohup "$GRAPHIFY_PY" -c "
from graphify.watch import watch
from pathlib import Path
watch(Path('.'), debounce=3.0)
" >> "${PROJECT_ROOT}/.claude/workspace/graphify-watch.log" 2>&1 &
            ) </dev/null >/dev/null 2>&1
            echo "Graphify watch: started (PID background, AST auto-rebuild on code changes)"
        fi
    fi
fi
# --- end graphify watch ---

# Emit a compact MEMORY.md summary if it exists and is non-empty
if [ -s "$MEMORY_FILE" ]; then
    echo "=== MEMORY.md (compact auto-injected summary) ==="
    python3 - "$MEMORY_FILE" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text()
lines = text.splitlines()

def extract_value(pattern: str) -> str | None:
    match = re.search(pattern, text, re.MULTILINE)
    return match.group(1).strip() if match else None

def collect_after(marker: str, pattern: str, limit: int) -> list[str]:
    items = []
    seen = False
    for line in lines:
        if marker in line:
            seen = True
            continue
        if not seen:
            continue
        if line.startswith("## ") and marker not in line:
            break
        if re.match(pattern, line):
            items.append(line.strip())
            if len(items) >= limit:
                break
    return items

status = extract_value(r'^\*\*Statut :\*\*\s*(.+)$')
last_session = extract_value(r'^\*\*Derniere session :\*\*\s*(.+)$')
current_phase = extract_value(r'^\*\*Phase actuelle :\*\*\s*(.+)$')
next_steps = collect_after("**Prochaine etape :**", r'^\d+\.\s', 3)
recent_work = collect_after("## Ce qui a ete fait", r'^###\s', 2)
blockers = collect_after("## Blocages et questions ouvertes", r'^- \[ \]', 3)

if status:
    print(f"Status: {status}")
if last_session:
    print(f"Last session: {last_session}")
if current_phase:
    print(f"Current phase: {current_phase}")
if next_steps:
    print("Next steps:")
    for item in next_steps:
        print(item)
if recent_work:
    print("Recent work:")
    for item in recent_work:
        print(f"- {item.removeprefix('### ').strip()}")
if blockers:
    print("Open blockers:")
    for item in blockers:
        print(item)
print("Full details remain available in memory/MEMORY.md if needed.")
PY
    echo ""
fi

# Loupe GSD cherry-picks self-healing check (runs silently, announces only on action/error)
# Reapplies 3 fixes from GSD 1.35.0 if they go missing after an npm update.
# Source: ~/.claude/gsd-local-patches/LOUPE-CHERRY-PICKS-2026-04-14.md
if [ "$SOURCE" = "startup" ] && [ -x ~/.claude/gsd-local-patches/reapply-loupe-cherry-picks.py ]; then
    python3 ~/.claude/gsd-local-patches/reapply-loupe-cherry-picks.py 2>&1 || true
fi

# Add contextual note after compaction
if [ "$SOURCE" = "compact" ]; then
    echo "[Note: Session resumed after compaction - MEMORY.md re-injected above]"
fi
