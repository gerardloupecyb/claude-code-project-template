#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Project Initializer
# Creates a new project from template with flywheel, CARL, and memory system.
# ============================================================================
#
# Usage:
#   ./init-project.sh "Mon Projet" monprojetworkflow "keyword1,keyword2,keyword3"
#
# Arguments:
#   $1 — Project name (display name, used in file headers)
#   $2 — CARL domain name (lowercase, no dashes, e.g. "monprojetworkflow")
#   $3 — CARL recall keywords (comma-separated, triggers domain loading)
#
# What it does:
#   1. Creates project directory with full structure
#   2. Copies context-manager skill (universal, no changes needed)
#   3. Generates CLAUDE.md, MEMORY.md, .carl/manifest, .carl/{domain} from templates
#   4. Replaces all {{PLACEHOLDERS}} with provided values
#   5. Creates docs/solutions/ and src/ subdirectories (empty, ready for use)
#
# After running:
#   - Fill in {{PLACEHOLDER}} values in CLAUDE.md and MEMORY.md
#   - Add project-specific CARL rules in .carl/{domain}
#   - Add project-specific skills in .claude/skills/
#   - Create docs/solutions/ subdirectories for your domains

TEMPLATE_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="${WORKSPACE_DIR:-$(dirname "$TEMPLATE_DIR")}"

if [ $# -lt 3 ]; then
    echo "Usage: $0 \"Project Name\" carl_domain \"keyword1,keyword2\""
    echo ""
    echo "Example:"
    echo "  $0 \"Mon SaaS\" saasworkflow \"saas,api,subscription,billing,stripe\""
    exit 1
fi

PROJECT_NAME="$1"
CARL_DOMAIN="$2"
RECALL_KEYWORDS="$3"
CARL_DOMAIN_UPPER=$(echo "$CARL_DOMAIN" | tr '[:lower:]' '[:upper:]')
PROJECT_DIR="${WORKSPACE}/${PROJECT_NAME}"
TODAY=$(date +%Y-%m-%d)

echo "═══════════════════════════════════════════"
echo "  Project Initializer"
echo "═══════════════════════════════════════════"
echo ""
echo "  Project:    ${PROJECT_NAME}"
echo "  Directory:  ${PROJECT_DIR}"
echo "  CARL:       ${CARL_DOMAIN} (${CARL_DOMAIN_UPPER})"
echo "  Keywords:   ${RECALL_KEYWORDS}"
echo ""

# Check if project already exists
if [ -d "$PROJECT_DIR" ]; then
    echo "ERROR: Directory already exists: ${PROJECT_DIR}"
    exit 1
fi

# Create directory structure
echo "→ Creating directory structure..."
mkdir -p "${PROJECT_DIR}/.claude/skills/context-manager"
mkdir -p "${PROJECT_DIR}/.claude/skills/pre-flight"
mkdir -p "${PROJECT_DIR}/.claude/skills/session-gate"
mkdir -p "${PROJECT_DIR}/.claude/skills/project-sync"
mkdir -p "${PROJECT_DIR}/.claude/skills/lesson"
mkdir -p "${PROJECT_DIR}/.claude/skills/context-checkpoint"
mkdir -p "${PROJECT_DIR}/.claude/skills/project-bootstrap"
mkdir -p "${PROJECT_DIR}/.claude/hooks"
mkdir -p "${PROJECT_DIR}/.claude/rules"
mkdir -p "${PROJECT_DIR}/.carl"
mkdir -p "${PROJECT_DIR}/.planning"
mkdir -p "${PROJECT_DIR}/docs/solutions"
mkdir -p "${PROJECT_DIR}/docs/plans"
mkdir -p "${PROJECT_DIR}/docs/brainstorms"
mkdir -p "${PROJECT_DIR}/memory"
mkdir -p "${PROJECT_DIR}/todos"
mkdir -p "${PROJECT_DIR}/src"

# Copy skills (universal, no modifications needed)
echo "→ Installing skills..."
cp "${TEMPLATE_DIR}/.claude/skills/context-manager/SKILL.md" \
   "${PROJECT_DIR}/.claude/skills/context-manager/SKILL.md"
cp "${TEMPLATE_DIR}/.claude/skills/pre-flight/SKILL.md" \
   "${PROJECT_DIR}/.claude/skills/pre-flight/SKILL.md"
cp "${TEMPLATE_DIR}/.claude/skills/session-gate/SKILL.md" \
   "${PROJECT_DIR}/.claude/skills/session-gate/SKILL.md"
cp "${TEMPLATE_DIR}/.claude/skills/project-sync/SKILL.md" \
   "${PROJECT_DIR}/.claude/skills/project-sync/SKILL.md"
cp "${TEMPLATE_DIR}/.claude/skills/lesson/SKILL.md" \
   "${PROJECT_DIR}/.claude/skills/lesson/SKILL.md"
cp "${TEMPLATE_DIR}/.claude/skills/context-checkpoint/SKILL.md" \
   "${PROJECT_DIR}/.claude/skills/context-checkpoint/SKILL.md"
cp "${TEMPLATE_DIR}/.claude/skills/project-bootstrap/SKILL.md" \
   "${PROJECT_DIR}/.claude/skills/project-bootstrap/SKILL.md"

# Copy hook scripts
echo "→ Installing hooks..."
cp "${TEMPLATE_DIR}/.claude/hooks/pre-compact.sh" \
   "${PROJECT_DIR}/.claude/hooks/pre-compact.sh"
cp "${TEMPLATE_DIR}/.claude/hooks/session-start.sh" \
   "${PROJECT_DIR}/.claude/hooks/session-start.sh"
chmod +x "${PROJECT_DIR}/.claude/hooks/"*.sh

# Copy rules
echo "→ Installing rules..."
cp "${TEMPLATE_DIR}/.claude/rules/tool-routing.md" \
   "${PROJECT_DIR}/.claude/rules/tool-routing.md"
cp "${TEMPLATE_DIR}/.claude/rules/flywheel-workflow.md" \
   "${PROJECT_DIR}/.claude/rules/flywheel-workflow.md"

# Create settings.json with hook configuration
echo "→ Creating .claude/settings.json..."
cp "${TEMPLATE_DIR}/.claude/settings.json" \
   "${PROJECT_DIR}/.claude/settings.json"

# Generate CLAUDE.md from template
echo "→ Generating CLAUDE.md..."
sed -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
    -e "s|{{CARL_DOMAIN}}|${CARL_DOMAIN}|g" \
    -e "s|{{DATE}}|${TODAY}|g" \
    "${TEMPLATE_DIR}/CLAUDE.md.template" > "${PROJECT_DIR}/CLAUDE.md"

# Generate MEMORY.md from template
echo "→ Generating MEMORY.md..."
sed -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
    -e "s|{{DATE}}|${TODAY}|g" \
    -e "s|{{PROJECT_PATH}}|${PROJECT_DIR}|g" \
    "${TEMPLATE_DIR}/memory/MEMORY.md.template" > "${PROJECT_DIR}/memory/MEMORY.md"

# Generate LESSONS.md from template
echo "→ Generating LESSONS.md..."
sed -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
    "${TEMPLATE_DIR}/LESSONS.md.template" > "${PROJECT_DIR}/LESSONS.md"

# Generate DECISIONS.md from template
echo "→ Generating DECISIONS.md..."
sed -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
    "${TEMPLATE_DIR}/DECISIONS.md.template" > "${PROJECT_DIR}/DECISIONS.md"

# Generate integrations.md from template
echo "→ Generating .claude/integrations.md..."
sed -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
    "${TEMPLATE_DIR}/.claude/integrations.md.template" > "${PROJECT_DIR}/.claude/integrations.md"

# Generate CARL manifest
echo "→ Generating .carl/manifest..."
sed -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
    -e "s|{{CARL_DOMAIN_UPPER}}|${CARL_DOMAIN_UPPER}|g" \
    -e "s|{{RECALL_KEYWORDS}}|${RECALL_KEYWORDS}|g" \
    "${TEMPLATE_DIR}/.carl/manifest.template" > "${PROJECT_DIR}/.carl/manifest"

# Generate CARL domain file
echo "→ Generating .carl/${CARL_DOMAIN}..."
SHORT_KEYWORDS=$(echo "$RECALL_KEYWORDS" | cut -d',' -f1-3)
sed -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
    -e "s|{{CARL_DOMAIN_UPPER}}|${CARL_DOMAIN_UPPER}|g" \
    -e "s|{{DOMAIN_DISPLAY_NAME}}|${PROJECT_NAME} Workflow|g" \
    -e "s|{{DOMAIN_DESCRIPTION}}|Rules for ${PROJECT_NAME} development.|g" \
    -e "s|{{DOMAIN_PURPOSE}}|They enforce the flywheel workflow and documentation discipline across sessions|g" \
    -e "s|{{RECALL_KEYWORDS_SHORT}}|${SHORT_KEYWORDS}|g" \
    -e "s|{{PROJECT_PATH}}|${PROJECT_DIR}|g" \
    "${TEMPLATE_DIR}/.carl/domain.template" > "${PROJECT_DIR}/.carl/${CARL_DOMAIN}"

# Add .gitkeep files for empty directories
touch "${PROJECT_DIR}/.planning/.gitkeep"
touch "${PROJECT_DIR}/docs/solutions/.gitkeep"
touch "${PROJECT_DIR}/docs/plans/.gitkeep"
touch "${PROJECT_DIR}/docs/brainstorms/.gitkeep"
touch "${PROJECT_DIR}/todos/.gitkeep"
touch "${PROJECT_DIR}/src/.gitkeep"

echo ""
echo "✓ Project initialized successfully!"
echo ""
echo "  Created:"
echo "    • CLAUDE.md              (edit: Stack, MCP, Skills, Domaines)"
echo "    • memory/MEMORY.md       (edit: Contexte, Stack, Liens)"
echo "    • LESSONS.md             (ready to use — capture via /lesson)"
echo "    • DECISIONS.md           (ready to use — ADR register for architectural decisions)"
echo "    • .claude/skills/         (7 skills: context-manager, pre-flight, session-gate,"
echo "                               project-sync, lesson, context-checkpoint, project-bootstrap)"
echo "    • .claude/hooks/          (pre-compact.sh + session-start.sh)"
echo "    • .claude/rules/          (tool-routing.md + flywheel-workflow.md)"
echo "    • .claude/settings.json   (hook configuration)"
echo "    • .claude/integrations.md (edit: set linear/gsd/supermemory true/false)"
echo "    • .carl/manifest         (ready to use)"
echo "    • .carl/${CARL_DOMAIN}   (add project-specific rules)"
echo "    • docs/ + todos/ + src/  (empty, ready)"
echo ""
echo "  Next steps:"
echo "    1. cd \"${PROJECT_DIR}\""
echo "    2. Replace remaining {{PLACEHOLDER}} values in CLAUDE.md and MEMORY.md"
echo "    3. Add project-specific CARL rules in .carl/${CARL_DOMAIN}"
echo "    4. Create docs/solutions/ subdirectories for your domains"
echo "    5. Add project-specific skills in .claude/skills/"
echo "    6. Run /project-bootstrap to inject cross-project lessons from Supermemory"
echo ""
