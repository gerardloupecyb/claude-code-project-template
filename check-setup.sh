#!/usr/bin/env bash
set -uo pipefail
# ============================================================================
# check-setup.sh — deterministic GREEN/RED FORGE readiness verdict (AC-4-2)
# ============================================================================
# D1/SF2/QP2 SENTINEL (positive per-concern affirmation): GREEN requires a flag
# PRESENT, never note-absence. A consumer who DELETES a sentinel note without
# affirming stays RED (delete-without-affirm bypass closed). There is NO single
# global flag that waives everything — affirmation is split per concern, and
# project_name is NEVER waivable.
#
# RED unless ALL hold:
#   (i)   forge.config project_name non-empty            — NEVER waivable
#   (ii)  gate.config protected_domains non-empty  OR  gate.config
#         _no_protected_domains_affirmed: true
#   (iii) forge.config compliance_frameworks non-empty  OR  forge.config
#         _no_compliance_frameworks_affirmed: true
#   (iv)  .claude/settings.json present (hooks registered for real)
#   (v)   git core.hooksPath == .githooks (the gate is installed)
#
# Idempotent: re-run after a hand-fix re-reads current state and flips GREEN with
# no questionnaire re-run.
#
# Usage: ./check-setup.sh [project-dir]   (default: current directory)
# ============================================================================

PROJ="${1:-.}"
FC="$PROJ/.claude/forge.config.json"
GC="$PROJ/.claude/gate.config.json"
RED=0
pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; RED=1; }

echo "FORGE setup check — ${PROJ}"

command -v jq >/dev/null 2>&1 || { echo "  jq required" >&2; exit 2; }

# (i) project_name — NEVER waivable
pn=""; [ -f "$FC" ] && pn=$(jq -r '.project_name // ""' "$FC" 2>/dev/null || echo "")
if [ -n "$pn" ]; then pass "project_name set (\"$pn\")"; else fail "project_name EMPTY — never waivable (fill .claude/forge.config.json)"; fi

# (ii) protected_domains configured OR affirmed-none (positive flag)
pdc=0; pda="false"
if [ -f "$GC" ]; then
    pdc=$(jq '(.protected_domains // []) | length' "$GC" 2>/dev/null || echo 0)
    pda=$(jq -r '._no_protected_domains_affirmed // false' "$GC" 2>/dev/null || echo false)
fi
if [ "${pdc:-0}" -gt 0 ]; then pass "protected_domains configured (${pdc})"
elif [ "$pda" = "true" ]; then pass "protected_domains empty, affirmed (_no_protected_domains_affirmed: true)"
else fail "protected_domains empty AND not affirmed (set domains OR _no_protected_domains_affirmed: true in gate.config.json)"; fi

# (iii) compliance_frameworks configured OR affirmed-none (positive flag)
cfc=0; cfa="false"
if [ -f "$FC" ]; then
    cfc=$(jq '(.compliance_frameworks // []) | length' "$FC" 2>/dev/null || echo 0)
    cfa=$(jq -r '._no_compliance_frameworks_affirmed // false' "$FC" 2>/dev/null || echo false)
fi
if [ "${cfc:-0}" -gt 0 ]; then pass "compliance_frameworks configured (${cfc})"
elif [ "$cfa" = "true" ]; then pass "compliance_frameworks empty, affirmed (_no_compliance_frameworks_affirmed: true)"
else fail "compliance_frameworks empty AND not affirmed (set frameworks OR _no_compliance_frameworks_affirmed: true in forge.config.json)"; fi

# (iv) settings.json placed (gate wired)
if [ -f "$PROJ/.claude/settings.json" ]; then pass "settings.json present (hooks registered)"; else fail "settings.json MISSING (run forge-init to place it)"; fi

# (v) githooks installed
hp=$(git -C "$PROJ" config --get core.hooksPath 2>/dev/null || echo "")
if [ "$hp" = ".githooks" ]; then pass "core.hooksPath = .githooks (gate installed)"; else fail "core.hooksPath != .githooks (run scripts/setup-hooks.sh)"; fi

echo ""
if [ "$RED" -eq 0 ]; then echo "VERDICT: GREEN"; exit 0; else echo "VERDICT: RED"; exit 1; fi
