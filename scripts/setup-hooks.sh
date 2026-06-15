#!/usr/bin/env bash
# setup-hooks.sh — Install versioned git hooks + verify tool availability
# Idempotent: safe to re-run. Run after clone or tool upgrade.
#
# Hooks configured (via core.hooksPath -> .githooks/):
#   pre-commit   — SAST security checks (gitleaks, semgrep, PSScriptAnalyzer,
#                  InjectionHunter) + governance guards. Blocks on findings.
#   post-commit  — Auto ChromaDB knowledge sync (detached background via
#                  scripts/knowledge-sync.py + chroma-mcp Python env).
#
# Why this is needed on every fresh clone:
#   core.hooksPath is per-repo config stored in .git/config — NOT cloned.
#   Without this, git uses .git/hooks/ (empty) and the versioned hooks
#   in .githooks/ are ignored.
#
# Usage: bash scripts/setup-hooks.sh

set -euo pipefail

FAIL=0

echo "=== SAST Setup ==="
echo ""

# ─── Health checks — verify tools are operational ──────────────────────────────

echo "Checking tools..."
echo -n "  gitleaks... "
if gitleaks version >/dev/null 2>&1; then
    echo "OK ($(gitleaks version 2>&1 | head -1))"
else
    echo "MISSING — brew install gitleaks"
    FAIL=1
fi

echo -n "  semgrep... "
if semgrep --version >/dev/null 2>&1; then
    echo "OK ($(semgrep --version 2>&1))"
else
    echo "MISSING — brew install semgrep"
    FAIL=1
fi

echo -n "  pwsh + PSScriptAnalyzer... "
if pwsh -Command 'Import-Module PSScriptAnalyzer -ErrorAction Stop; "OK"' 2>/dev/null | grep -q OK; then
    echo "OK"
else
    echo "MISSING — Install-Module PSScriptAnalyzer -Scope CurrentUser"
    FAIL=1
fi

echo -n "  pwsh + InjectionHunter... "
if pwsh -Command 'Import-Module InjectionHunter -ErrorAction Stop; "OK"' 2>/dev/null | grep -q OK; then
    echo "OK"
else
    echo "MISSING — Install-Module InjectionHunter -Scope CurrentUser"
    FAIL=1
fi

echo -n "  jq... "
if jq --version >/dev/null 2>&1; then
    echo "OK ($(jq --version 2>&1))"
else
    echo "MISSING — brew install jq"
    FAIL=1
fi

echo ""

if [ $FAIL -ne 0 ]; then
    echo "❌ Install missing tools and re-run."
    exit 1
fi

# ─── Configure git hooks path ─────────────────────────────────────────────────

echo -n "Configuring git hooks path... "
git config core.hooksPath .githooks
echo "OK (.githooks/)"

# ─── Verify hook is executable ─────────────────────────────────────────────────

if [ -f .githooks/pre-commit ]; then
    chmod +x .githooks/pre-commit
    echo "Pre-commit hook: installed and executable"
else
    echo "⚠️  Pre-commit hook not found at .githooks/pre-commit"
    echo "   Create it first, then re-run this script."
fi

if [ -f .githooks/post-commit ]; then
    chmod +x .githooks/post-commit
    echo "Post-commit hook: installed and executable (ChromaDB auto-sync)"
    # Sanity check: the post-commit hook needs the chroma-mcp Python env + sync script
    CHROMA_PY="${HOME}/.local/share/uv/tools/chroma-mcp/bin/python"
    if [ ! -x "$CHROMA_PY" ]; then
        echo "   ⚠️  ${CHROMA_PY} not found — run scripts/setup-chromadb.sh first"
        echo "      (post-commit will skip silently until chroma-mcp is installed)"
    fi
    if [ ! -f scripts/knowledge-sync.py ]; then
        echo "   ⚠️  scripts/knowledge-sync.py missing — post-commit will skip silently"
    fi
else
    echo "⚠️  Post-commit hook not found at .githooks/post-commit"
fi

# ─── Pre-warm Semgrep rule cache ───────────────────────────────────────────────

echo ""
echo "Pre-warming Semgrep rule cache (first run downloads rules, ~10-20s)..."
if semgrep --config p/security-audit --validate --metrics off 2>/dev/null; then
    echo "Semgrep cache: OK"
else
    echo "⚠️  Semgrep cache warm failed (rules may download on first commit)"
fi

echo ""
echo "Plan-checker helper: scripts/create-plan-checker-pass.sh"
echo "  Usage: bash scripts/create-plan-checker-pass.sh <phase-slug> [explicit-phase-path]"
echo "  Creates .planning/phases/<status>/<phase>/PLAN-CHECKER-PASS marker"
echo ""
echo "✅ Setup complete. Hook active for all future commits."
echo "   Bypass: git commit --no-verify"
