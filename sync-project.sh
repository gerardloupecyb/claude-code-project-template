#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# sync-project.sh — update an existing FORGE project from the template (v1 SIMPLE)
# ============================================================================
# FORGE Phase 22 Plan 04, AC-4-3 (D-12). The set of syncable files is DRIVEN by
# the forge-extract-derived `.forge/sync-allowlist.json` — the SAME single source
# forge-init reads. A skill/rule/hook NOT in the allowlist is NEVER pushed (a domain
# skill — ghl/n8n/azure — can never reach a consumer). Behaviour:
#   - overwrite the allowlisted UNIVERSAL files (skills, rules, hooks, forge tooling)
#   - never touch project-specific / consumer-owned files (protected[] + CLAUDE.md +
#     the consumer-filled configs + settings.json) → reported [SKIP]
#   - write a forge-template-version (commit-SHA) drift marker on --apply
#   - NO 3-way merge (overwrite-on-apply, dry-run-reviewed) → 3-way deferred to 22.1
#
# Usage:
#   ./sync-project.sh /path/to/project           # dry-run (default)
#   ./sync-project.sh /path/to/project --apply    # apply
# ============================================================================

TEMPLATE_DIR="$(cd "$(dirname "$0")" && pwd)"
ALLOWLIST="${TEMPLATE_DIR}/.forge/sync-allowlist.json"
RESOLVER_LIB="${TEMPLATE_DIR}/.forge/forge-resolve.sh"
# shellcheck source=.forge/forge-resolve.sh
[ -f "$RESOLVER_LIB" ] && . "$RESOLVER_LIB"

if [ $# -lt 1 ]; then
    echo "Usage: $0 /path/to/project [--apply]" >&2
    exit 1
fi
PROJECT_DIR="$1"
MODE="${2:-dry-run}"

[ -d "$PROJECT_DIR" ] || { echo "ERROR: project directory not found: ${PROJECT_DIR}" >&2; exit 1; }
[ -f "$ALLOWLIST" ] || { echo "ERROR: derived allowlist missing: ${ALLOWLIST} (run forge-extract --apply)" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required to read the derived allowlist." >&2; exit 1; }
jq -e . "$ALLOWLIST" >/dev/null 2>&1 || { echo "ERROR: derived allowlist is not valid JSON." >&2; exit 1; }

echo "═══════════════════════════════════════════"
echo "  FORGE template sync (${MODE})"
echo "═══════════════════════════════════════════"
echo "  Template:  ${TEMPLATE_DIR}"
echo "  Project:   ${PROJECT_DIR}"
echo ""

NEW=0; MODIFIED=0; OK=0; SKIPPED=0
COPIED=()   # review batch ⑧: the files actually overwritten this --apply (re-resolve scope)

sync_file() {  # $1=relative path (overwrite-on-apply)
    local rel="$1" src="${TEMPLATE_DIR}/$1" dst="${PROJECT_DIR}/$1"
    [ -f "$src" ] || return 0
    if [ ! -f "$dst" ]; then
        echo "  [NEW]       ${rel}"; NEW=$((NEW+1))
        if [ "$MODE" = "--apply" ]; then mkdir -p "$(dirname "$dst")"; cp "$src" "$dst"; case "$rel" in *.sh) chmod +x "$dst" 2>/dev/null || true;; esac; COPIED+=("$dst"); fi
    elif ! diff -q "$src" "$dst" >/dev/null 2>&1; then
        echo "  [MODIFIED]  ${rel}"; MODIFIED=$((MODIFIED+1))
        if [ "$MODE" = "--apply" ]; then cp "$src" "$dst"; case "$rel" in *.sh) chmod +x "$dst" 2>/dev/null || true;; esac; COPIED+=("$dst"); fi
    else
        OK=$((OK+1))
    fi
    return 0
}

echo "→ Skills (allowlist-driven, full dir)"
while IFS= read -r skill; do
    [ -z "$skill" ] && continue
    sdir="${TEMPLATE_DIR}/.claude/skills/${skill}"
    [ -d "$sdir" ] || continue
    while IFS= read -r f; do sync_file "${f#${TEMPLATE_DIR}/}"; done < <(find "$sdir" -type f)
done < <(jq -r '.skills[]?' "$ALLOWLIST")

echo "→ Rules (allowlist-driven)"
while IFS= read -r rule; do [ -z "$rule" ] && continue; sync_file ".claude/rules/${rule}"; done < <(jq -r '.rules[]?' "$ALLOWLIST")

echo "→ Hooks (allowlist globs)"
while IFS= read -r glob; do
    [ -z "$glob" ] && continue
    shopt -s nullglob
    for f in "${TEMPLATE_DIR}"/${glob}; do [ -f "$f" ] && sync_file "${f#${TEMPLATE_DIR}/}"; done
    shopt -u nullglob
done < <(jq -r '.hooks_glob[]?' "$ALLOWLIST")

echo "→ Forge tooling (allowlist files[], universal only)"
while IFS= read -r relf; do
    [ -z "$relf" ] && continue
    # consumer-owned scattered files are NEVER overwritten on sync (they carry the
    # consumer's identity/config): CLAUDE.md + the sliced configs.
    case "$relf" in
        CLAUDE.md|*.config.json) echo "  [SKIP]      ${relf} (consumer-owned)"; SKIPPED=$((SKIPPED+1)); continue ;;
        *.json.template)         echo "  [SKIP]      ${relf} (init-only; consumer manages settings.json)"; SKIPPED=$((SKIPPED+1)); continue ;;
        *) sync_file "$relf" ;;
    esac
done < <(jq -r '.files[]?' "$ALLOWLIST")

echo "→ Protected / consumer-owned (never synced)"
while IFS= read -r pf; do [ -z "$pf" ] && continue; echo "  [SKIP]      ${pf}"; SKIPPED=$((SKIPPED+1)); done < <(jq -r '.protected[]?' "$ALLOWLIST")
for extra in ".claude/settings.json" ".claude/gate.config.json" ".claude/forge.config.json"; do
    [ -e "${PROJECT_DIR}/${extra}" ] && { echo "  [SKIP]      ${extra} (consumer-owned)"; SKIPPED=$((SKIPPED+1)); }
done

# ── forge-template-version drift marker (commit-SHA) ───────────────────────
TPL_SHA="$(git -C "$TEMPLATE_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
if [ "$MODE" = "--apply" ]; then
    mkdir -p "${PROJECT_DIR}/.forge"
    printf 'forge-template-version: %s\nsynced_from: %s\n' "$TPL_SHA" "$TEMPLATE_DIR" > "${PROJECT_DIR}/.forge/forge-template-version"
    echo ""
    echo "→ wrote .forge/forge-template-version (${TPL_SHA})"
    # re-resolve {{tokens}} the overwrite re-introduced, SCOPED to the files this sync actually
    # copied (review batch ⑧). A wholesale resolve_tree over $PROJECT_DIR would re-tokenize
    # consumer-OWNED [SKIP] files (CLAUDE.md / settings.json / a doc with a literal {{PROJECT}}
    # example) — undoing the [SKIP] protection. resolve_files touches only COPIED + runs the same
    # fail-closed validity + secret backstop. A failed re-resolve is fail-closed (non-zero exit).
    if [ "${#COPIED[@]}" -gt 0 ] && declare -F resolve_files >/dev/null 2>&1 && [ -f "${PROJECT_DIR}/.forge/answers.json" ]; then
        if resolve_files "$PROJECT_DIR" "${PROJECT_DIR}/.forge/answers.json" "${COPIED[@]}"; then
            echo "→ re-resolved {{tokens}} in the ${#COPIED[@]} synced file(s) from .forge/answers.json (consumer-owned files untouched)"
        else
            echo "  ERROR: re-resolution after sync failed (fail-closed) — review residual {{tokens}} / secret-shape above." >&2
            exit 5
        fi
    fi
fi

echo ""
echo "─────────────────────────────────────────"
echo "  ${NEW} new · ${MODIFIED} modified · ${OK} up-to-date · ${SKIPPED} skipped"
echo "  template version: ${TPL_SHA}"
if [ "$MODE" != "--apply" ] && [ $((NEW + MODIFIED)) -gt 0 ]; then
    echo ""
    echo "  Review the diff above, then apply:  $0 \"${PROJECT_DIR}\" --apply"
fi
echo ""
