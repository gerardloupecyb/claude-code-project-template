#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Project Sync — Update existing project from template
# Syncs universal files (skills, rules, hooks, settings) without touching
# project-specific files (CLAUDE.md, MEMORY.md, LESSONS.md, DECISIONS.md, CARL).
# ============================================================================
#
# Usage:
#   ./sync-project.sh /path/to/project          # dry-run (default)
#   ./sync-project.sh /path/to/project --apply   # apply changes
#
# What it does:
#   1. Compares universal files between template and project
#   2. Reports: NEW (missing in project), MODIFIED (differs), OK (identical)
#   3. With --apply: copies new and modified universal files to project
#
# What it does NOT touch (project-specific):
#   - CLAUDE.md, memory/MEMORY.md, LESSONS.md, DECISIONS.md
#   - .claude/integrations.md
#   - .carl/* (manifest, domain files)
#   - docs/, todos/, src/ (project content)
#
# For CLAUDE.md template changes: shows a warning with diff guidance.

TEMPLATE_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ $# -lt 1 ]; then
    echo "Usage: $0 /path/to/project [--apply]"
    echo ""
    echo "  Default: dry-run (show what would change)"
    echo "  --apply: actually copy files"
    echo ""
    echo "Example:"
    echo "  $0 \"/Users/me/Claude code/MonProjet\""
    echo "  $0 \"/Users/me/Claude code/MonProjet\" --apply"
    exit 1
fi

PROJECT_DIR="$1"
MODE="${2:-dry-run}"

if [ ! -d "$PROJECT_DIR" ]; then
    echo "ERROR: Project directory not found: ${PROJECT_DIR}"
    exit 1
fi

if [ ! -f "$PROJECT_DIR/CLAUDE.md" ] && [ ! -f "$PROJECT_DIR/memory/MEMORY.md" ]; then
    echo "ERROR: ${PROJECT_DIR} does not look like a template project"
    echo "       (missing CLAUDE.md and memory/MEMORY.md)"
    exit 1
fi

echo "═══════════════════════════════════════════"
echo "  Project Sync"
echo "═══════════════════════════════════════════"
echo ""
echo "  Template:  ${TEMPLATE_DIR}"
echo "  Project:   ${PROJECT_DIR}"
echo "  Mode:      ${MODE}"
echo ""

# Counters
NEW=0
MODIFIED=0
OK=0
SKIPPED=0

# ── Compare a universal file ──────────────────────────────────────────────
# Usage: sync_file "relative/path/to/file"
sync_file() {
    local REL_PATH="$1"
    local SRC="${TEMPLATE_DIR}/${REL_PATH}"
    local DST="${PROJECT_DIR}/${REL_PATH}"

    if [ ! -f "$SRC" ]; then
        return
    fi

    if [ ! -f "$DST" ]; then
        echo "  [NEW]       ${REL_PATH}"
        NEW=$((NEW + 1))
        if [ "$MODE" = "--apply" ]; then
            mkdir -p "$(dirname "$DST")"
            cp "$SRC" "$DST"
            echo "              → copied"
        fi
    elif ! diff -q "$SRC" "$DST" > /dev/null 2>&1; then
        echo "  [MODIFIED]  ${REL_PATH}"
        MODIFIED=$((MODIFIED + 1))
        if [ "$MODE" = "--apply" ]; then
            cp "$SRC" "$DST"
            echo "              → updated"
        fi
    else
        OK=$((OK + 1))
    fi
}

# ── Universal files: skills ───────────────────────────────────────────────
echo "→ Skills"
for SKILL_DIR in "${TEMPLATE_DIR}"/.claude/skills/*/; do
    SKILL_NAME=$(basename "$SKILL_DIR")
    sync_file ".claude/skills/${SKILL_NAME}/SKILL.md"
done

# ── Universal files: rules ────────────────────────────────────────────────
echo "→ Rules"
for RULE_FILE in "${TEMPLATE_DIR}"/.claude/rules/*.md; do
    RULE_NAME=$(basename "$RULE_FILE")
    sync_file ".claude/rules/${RULE_NAME}"
done

# ── Universal files: hooks ────────────────────────────────────────────────
echo "→ Hooks"
for HOOK_FILE in "${TEMPLATE_DIR}"/.claude/hooks/*.sh; do
    HOOK_NAME=$(basename "$HOOK_FILE")
    sync_file ".claude/hooks/${HOOK_NAME}"
done
# Ensure hooks are executable after sync
if [ "$MODE" = "--apply" ] && [ -d "${PROJECT_DIR}/.claude/hooks" ]; then
    chmod +x "${PROJECT_DIR}/.claude/hooks/"*.sh 2>/dev/null || true
fi

# ── Universal files: settings.json ────────────────────────────────────────
echo "→ Settings"
sync_file ".claude/settings.json"

# ── Bootstrap missing reference files ──────────────────────────────────────
# These files are project-specific once they exist, but if they're missing
# entirely, we bootstrap them from the template (without placeholder substitution).
echo ""
echo "→ Reference files (bootstrap if missing)"

bootstrap_if_missing() {
    local TEMPLATE_FILE="$1"
    local TARGET_FILE="$2"
    local DISPLAY_NAME="$3"
    local SRC="${TEMPLATE_DIR}/${TEMPLATE_FILE}"
    local DST="${PROJECT_DIR}/${TARGET_FILE}"

    if [ ! -f "$SRC" ]; then
        return
    fi

    if [ ! -f "$DST" ]; then
        echo "  [MISSING]   ${DISPLAY_NAME} — will bootstrap from template"
        NEW=$((NEW + 1))
        if [ "$MODE" = "--apply" ]; then
            mkdir -p "$(dirname "$DST")"
            # Copy template, strip {{PLACEHOLDER}} markers but keep structure
            sed -e 's|{{PROJECT_NAME}}|TODO-set-project-name|g' \
                -e 's|{{DATE}}|'"$(date +%Y-%m-%d)"'|g' \
                -e 's|{{PROJECT_PATH}}|'"${PROJECT_DIR}"'|g' \
                "$SRC" > "$DST"
            echo "              → bootstrapped (edit placeholders if any)"
        fi
    else
        SKIPPED=$((SKIPPED + 1))
        echo "  [ok]        ${DISPLAY_NAME} (exists, not modified)"
    fi
}

bootstrap_if_missing "DECISIONS.md.template" "DECISIONS.md" "DECISIONS.md"
bootstrap_if_missing "LESSONS.md.template" "LESSONS.md" "LESSONS.md"

# ── Template-generated files: warn only ───────────────────────────────────
echo ""
echo "→ Template files (never synced — project-specific)"

check_template_drift() {
    local TEMPLATE_FILE="$1"
    local DISPLAY_NAME="$2"

    if [ -f "${TEMPLATE_DIR}/${TEMPLATE_FILE}" ]; then
        SKIPPED=$((SKIPPED + 1))
        echo "  [SKIP]      ${DISPLAY_NAME} (project-specific, manual review if needed)"
    fi
}

check_template_drift "CLAUDE.md.template" "CLAUDE.md"
check_template_drift "memory/MEMORY.md.template" "memory/MEMORY.md"
check_template_drift ".claude/integrations.md.template" ".claude/integrations.md"
check_template_drift ".carl/manifest.template" ".carl/manifest"
check_template_drift ".carl/domain.template" ".carl/{domain}"

# ── Summary ───────────────────────────────────────────────────────────────
echo ""
echo "─────────────────────────────────────────"
echo "  Summary:"
echo "    ${NEW} new file(s)"
echo "    ${MODIFIED} modified file(s)"
echo "    ${OK} up-to-date file(s)"
echo "    ${SKIPPED} skipped (project-specific)"
echo ""

if [ "$MODE" != "--apply" ] && [ $((NEW + MODIFIED)) -gt 0 ]; then
    echo "  Run with --apply to sync:"
    echo "    $0 \"${PROJECT_DIR}\" --apply"
    echo ""
fi

if [ "$MODE" = "--apply" ] && [ $((NEW + MODIFIED)) -gt 0 ]; then
    echo "  ✓ ${NEW} new + ${MODIFIED} modified file(s) synced."
    echo ""
    echo "  Note: CLAUDE.md was not updated (project-specific)."
    echo "  To check for template changes:"
    echo "    diff \"${TEMPLATE_DIR}/CLAUDE.md.template\" \"${PROJECT_DIR}/CLAUDE.md\""
    echo ""
fi

if [ $((NEW + MODIFIED)) -eq 0 ]; then
    echo "  ✓ Project is up to date with template."
    echo ""
fi
