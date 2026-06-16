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

# Args: [project-dir] (positional, back-compat) and/or --project-dir DIR --class ordinary|cross-vendor
PROJ="."; CLASS="ordinary"
while [ $# -gt 0 ]; do
    case "$1" in
        --class)       CLASS="$2"; shift 2 ;;
        --project-dir) PROJ="$2"; shift 2 ;;
        --*)           echo "check-setup: unknown option '$1'" >&2; exit 2 ;;
        *)             PROJ="$1"; shift ;;
    esac
done
case "$CLASS" in ordinary|cross-vendor) ;; *) echo "check-setup: --class must be ordinary|cross-vendor" >&2; exit 2 ;; esac
FC="$PROJ/.claude/forge.config.json"
GC="$PROJ/.claude/gate.config.json"
RED=0; BLOCK=0
pass()    { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail()    { printf '  \033[31mFAIL\033[0m %s\n' "$1"; RED=1; }
degrade() { printf '  \033[33mDEGRADE\033[0m %s\n' "$1"; }   # visible, non-blocking (single-vendor degrade)
absent()  { printf '  ABSENT  %s\n' "$1"; }                  # declared but not present (informational)

echo "FORGE setup check — ${PROJ}"

command -v jq >/dev/null 2>&1 || { echo "  jq required" >&2; exit 2; }

# (i) project_name — NEVER waivable
pn=""; [ -f "$FC" ] && pn=$(jq -r '.project_name // ""' "$FC" 2>/dev/null || echo "")
if [ -n "$pn" ]; then pass "project_name set (\"$pn\")"; else fail "project_name EMPTY — never waivable (fill .claude/forge.config.json)"; fi

# (ii) protected_domains configured OR affirmed-none (positive flag)
pdc=0; pda="false"
if [ -f "$GC" ]; then
    pdc=$(jq '(.protected_domains // []) | if type=="array" then length else 0 end' "$GC" 2>/dev/null || echo 0)
    pda=$(jq -r '._no_protected_domains_affirmed // false' "$GC" 2>/dev/null || echo false)
fi
if [ "${pdc:-0}" -gt 0 ]; then pass "protected_domains configured (${pdc})"
elif [ "$pda" = "true" ]; then pass "protected_domains empty, affirmed (_no_protected_domains_affirmed: true)"
else fail "protected_domains empty AND not affirmed (set domains OR _no_protected_domains_affirmed: true in gate.config.json)"; fi

# (iii) compliance_frameworks configured OR affirmed-none (positive flag)
cfc=0; cfa="false"
if [ -f "$FC" ]; then
    cfc=$(jq '(.compliance_frameworks // []) | if type=="array" then length else 0 end' "$FC" 2>/dev/null || echo 0)
    cfa=$(jq -r '._no_compliance_frameworks_affirmed // false' "$FC" 2>/dev/null || echo false)
fi
if [ "${cfc:-0}" -gt 0 ]; then pass "compliance_frameworks configured (${cfc})"
elif [ "$cfa" = "true" ]; then pass "compliance_frameworks empty, affirmed (_no_compliance_frameworks_affirmed: true)"
else fail "compliance_frameworks empty AND not affirmed (set frameworks OR _no_compliance_frameworks_affirmed: true in forge.config.json)"; fi

# (iv) settings.json placed (gate wired)
# Validate the gate-firing hook is REGISTERED (not just that the file exists — a bare `{}`
# passes existence but wires no hook → the gate never fires), the file is valid JSON, and
# carries no residual {{token}} (an unresolved {{GATED_MCP_PREFIXES}} matcher → inert prod-MCP gate).
SJ="$PROJ/.claude/settings.json"
if [ ! -f "$SJ" ]; then fail "settings.json MISSING (run forge-init to place it)"
elif ! jq -e . "$SJ" >/dev/null 2>&1; then fail "settings.json is not valid JSON"
elif ! jq -e '[.hooks.PreToolUse[]?.hooks[]?.command // ""] | any(test("pre-tool-use\\.sh"))' "$SJ" >/dev/null 2>&1; then
    fail "settings.json present but the PreToolUse pre-tool-use.sh hook is NOT registered — the gate will not fire (a bare {} passes file-existence but wires nothing)"
elif grep -q '{{[A-Za-z0-9_]' "$SJ"; then
    fail "settings.json has an unresolved {{token}} (e.g. {{GATED_MCP_PREFIXES}} in a matcher → inert prod-MCP gate) — re-run forge-init"
else pass "settings.json present + pre-tool-use.sh hook registered + no residual {{token}}"; fi

# (v) githooks installed
hp=$(git -C "$PROJ" config --get core.hooksPath 2>/dev/null || echo "")
if [ "$hp" = ".githooks" ]; then pass "core.hooksPath = .githooks (gate installed)"; else fail "core.hooksPath != .githooks (run scripts/setup-hooks.sh)"; fi

# ── (vi) executor / routing / MCP — class-aware, never silent (AC-5-6) ────────
# Reports the declared cross-vendor voices + their availability. CLASS distinction:
#   ordinary phase      + a family has no available voice → DEGRADE (visible, non-blocking)
#   cross-vendor class  + a family has no available voice → BLOCK (no waiver, RED)
# Declined-install and unknown/no-installer executors are ALWAYS surfaced RED.
_exec_available() {  # $1=transport $2=project-dir
    case "$1" in
        codex-cli)  command -v codex  >/dev/null 2>&1 ;;
        gemini-cli) command -v gemini >/dev/null 2>&1 ;;
        deepseek)   command -v deepseek >/dev/null 2>&1 || [ -x "$HOME/.claude/scripts/deepseek-exec.sh" ] ;;
        openrouter) [ -f "$2/.mcp.json" ] && jq -e '.mcpServers.openrouter' "$2/.mcp.json" >/dev/null 2>&1 ;;
        *) return 2 ;;
    esac
}
_exec_has_installer() {  # $1=transport
    case "$1" in codex-cli|gemini-cli|deepseek|openrouter) return 0 ;; *) return 1 ;; esac
}

echo ""
echo "Executor / routing / MCP (class: ${CLASS}):"
if [ -f "$FC" ] && jq -e '.model_router.cross_vendor_voices' "$FC" >/dev/null 2>&1; then
    declined="$(jq -r '(.model_router.executors_declined // []) | join(" ")' "$FC" 2>/dev/null || echo "")"
    for fam in openai google; do
        voices="$(jq -r --arg f "$fam" '(.model_router.cross_vendor_voices[$f] // []) | .[]' "$FC" 2>/dev/null)"
        [ -z "$voices" ] && continue
        fam_avail=0
        while IFS= read -r v; do
            [ -z "$v" ] && continue
            if printf '%s\n' $declined | grep -qx "$v"; then fail "executor ${v} (${fam}): NOT-PROVISIONED (install declined)"; continue; fi
            if ! _exec_has_installer "$v"; then fail "executor ${v} (${fam}): unknown executor — no installer for ${v}"; continue; fi
            if _exec_available "$v" "$PROJ"; then pass "executor ${v} (${fam}): available"; fam_avail=1
            else absent "executor ${v} (${fam}): declared but not on PATH / not wired"; fi
        done <<< "$voices"
        if [ "$fam_avail" -eq 0 ]; then
            if [ "$CLASS" = "cross-vendor" ]; then
                printf '  \033[31mBLOCK\033[0m %s\n' "${fam} family has NO available voice — cross-vendor no-waiver BLOCK"; RED=1; BLOCK=1
            else
                degrade "${fam} family unavailable — single-vendor degrade (visible; ordinary phase may proceed)"
            fi
        fi
    done
else
    degrade "no model_router.cross_vendor_voices declared — run forge-setup-executors routing"
fi

echo ""
if [ "${BLOCK}" -eq 1 ]; then echo "VERDICT: RED (cross-vendor BLOCK)"; exit 1
elif [ "$RED" -eq 0 ]; then echo "VERDICT: GREEN"; exit 0
else echo "VERDICT: RED"; exit 1; fi
