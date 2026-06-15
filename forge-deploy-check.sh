#!/usr/bin/env bash
set -uo pipefail
# ============================================================================
# forge-deploy-check.sh — deploy-time config completion + fail-closed deploy-block
# ============================================================================
# AC-5-7 (N1). Default action = the deploy-block CHECK. `fill` writes the sliced
# answers to their CORRECT files and re-renders the skill-gate.
#
#   D1 SENTINEL : BLOCK unless project_name is non-empty (NEVER waivable) AND each
#                 empty array (compliance_frameworks / gate protected_domains) is
#                 filled OR affirmed by its OWN positive flag (_no_*_affirmed PRESENT).
#                 GREEN needs the POSITIVE flag present — not note-absence
#                 (delete-without-affirm → still BLOCK). No single global waiver.
#   D5          : the FULL no-residual-{{token}} check on the REAL filled config/tree
#                 (Plan 04 only fixture-validated it) — closes the 04↔05 cycle.
#   SF5 + Gap-C : the deploy-time skill-gate re-render is validated by a parity oracle
#                 (render-skill-gate.sh --check on the FILLED gate.config = empty). A
#                 NON-ZERO render (malformed config) → BLOCK; parity runs only after a
#                 successful render.
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v jq >/dev/null 2>&1 || { echo "forge-deploy-check: jq required" >&2; exit 2; }

cmd_fill() {
    local PROJ="." pn="__UNSET__" cf="__UNSET__" dl="__UNSET__" pd="__UNSET__" gm="__UNSET__" acf=0 apd=0
    while [ $# -gt 0 ]; do case "$1" in
        --project-dir)                 PROJ="$2"; shift 2 ;;
        --project-name)                pn="$2"; shift 2 ;;
        --compliance)                  cf="$2"; shift 2 ;;
        --doc-language)                dl="$2"; shift 2 ;;
        --protected-domains)           pd="$2"; shift 2 ;;
        --gated-mcp)                   gm="$2"; shift 2 ;;
        --affirm-no-compliance)        acf=1; shift ;;
        --affirm-no-protected-domains) apd=1; shift ;;
        *) echo "fill: unknown option '$1'" >&2; return 2 ;;
    esac; done
    local FC="$PROJ/.claude/forge.config.json" GC="$PROJ/.claude/gate.config.json" tmp
    [ -f "$FC" ] || { echo "fill: forge.config.json not found: $FC" >&2; return 2; }
    [ -f "$GC" ] || { echo "fill: gate.config.json not found: $GC" >&2; return 2; }

    # forge.config ← project_name / doc_language / compliance_frameworks (+ affirm)
    tmp="$(mktemp)"
    jq --arg pn "$pn" --arg dl "$dl" --arg cf "$cf" --argjson acf "$acf" '
        (if $pn != "__UNSET__" then .project_name = $pn else . end)
        | (if $dl != "__UNSET__" then .doc_language = $dl else . end)
        | (if ($cf != "__UNSET__" and $cf != "" and $cf != "none")
             then .compliance_frameworks = ($cf | split(",") | map(gsub("^\\s+|\\s+$";"")) | map(select(length>0)))
             else . end)
        | (if $acf == 1 then ._no_compliance_frameworks_affirmed = true else . end)
    ' "$FC" > "$tmp" && jq -e . "$tmp" >/dev/null 2>&1 && mv "$tmp" "$FC" \
        || { echo "fill: forge.config write failed (fail-closed)" >&2; rm -f "$tmp"; return 1; }

    # gate.config ← protected_domains / gated_mcp (+ affirm). NEVER routing (D-11).
    tmp="$(mktemp)"
    jq --arg pd "$pd" --arg gm "$gm" --argjson apd "$apd" '
        (if ($pd != "__UNSET__" and $pd != "") then .protected_domains = ($pd | fromjson) else . end)
        | (if ($gm != "__UNSET__" and $gm != "") then .gated_mcp = ($gm | fromjson) else . end)
        | (if $apd == 1 then ._no_protected_domains_affirmed = true else . end)
    ' "$GC" > "$tmp" && jq -e . "$tmp" >/dev/null 2>&1 && mv "$tmp" "$GC" \
        || { echo "fill: gate.config write failed (fail-closed)" >&2; rm -f "$tmp"; return 1; }

    # re-render skill-gate.md from the FILLED gate.config (Plan-03 _domains_note forward-dep)
    if [ -f "$PROJ/scripts/forge/render-skill-gate.sh" ]; then
        if ( cd "$PROJ" && bash scripts/forge/render-skill-gate.sh ) >/dev/null 2>&1; then
            echo "  ✓ skill-gate.md re-rendered from the filled gate.config" >&2
        else
            echo "  WARN: render-skill-gate.sh failed on the filled gate.config — deploy-block will BLOCK (Gap-C)" >&2
        fi
    fi
    echo "  ✓ config fill complete (forge.config + gate.config)" >&2
    return 0
}

cmd_check() {
    local PROJ="."
    while [ $# -gt 0 ]; do case "$1" in
        --project-dir) PROJ="$2"; shift 2 ;;
        *) echo "check: unknown option '$1'" >&2; return 2 ;;
    esac; done
    local FC="$PROJ/.claude/forge.config.json" GC="$PROJ/.claude/gate.config.json"
    local BLOCK=0
    blk() { printf '  \033[31mBLOCK\033[0m %s\n' "$1" >&2; BLOCK=1; }
    oky() { printf '  \033[32mOK\033[0m %s\n' "$1"; }
    echo "FORGE deploy-block — ${PROJ}"
    [ -f "$FC" ] || { echo "deploy-block: forge.config.json missing — BLOCK" >&2; echo "DEPLOY: BLOCKED"; exit 1; }
    [ -f "$GC" ] || { echo "deploy-block: gate.config.json missing — BLOCK" >&2; echo "DEPLOY: BLOCKED"; exit 1; }

    # ── D1 sentinel (positive per-concern flag; project_name NEVER waivable) ──
    local pn cfc cfa pdc pda
    pn="$(jq -r '.project_name // ""' "$FC" 2>/dev/null || echo "")"
    [ -n "$pn" ] && oky "project_name set (\"$pn\")" || blk "project_name EMPTY — NEVER waivable (no flag waives it)"
    cfc="$(jq '(.compliance_frameworks // []) | if type=="array" then length else 0 end' "$FC" 2>/dev/null || echo 0)"
    cfa="$(jq -r '._no_compliance_frameworks_affirmed // false' "$FC" 2>/dev/null || echo false)"
    if [ "${cfc:-0}" -gt 0 ]; then oky "compliance_frameworks filled (${cfc})"
    elif [ "$cfa" = "true" ]; then oky "compliance_frameworks empty, affirmed (positive flag present)"
    else blk "compliance_frameworks empty AND _no_compliance_frameworks_affirmed not present (delete-without-affirm = BLOCK)"; fi
    pdc="$(jq '(.protected_domains // []) | if type=="array" then length else 0 end' "$GC" 2>/dev/null || echo 0)"
    pda="$(jq -r '._no_protected_domains_affirmed // false' "$GC" 2>/dev/null || echo false)"
    if [ "${pdc:-0}" -gt 0 ]; then oky "protected_domains filled (${pdc})"
    elif [ "$pda" = "true" ]; then oky "protected_domains empty, affirmed (positive flag present)"
    else blk "protected_domains empty AND _no_protected_domains_affirmed not present (delete-without-affirm = BLOCK)"; fi

    # ── D5 no-residual {{token}} on the REAL filled config/tree (was fixture-only) ──
    if . "$SCRIPT_DIR/.forge/forge-resolve.sh" 2>/dev/null && declare -F tripwire_scan >/dev/null 2>&1; then
        if tripwire_scan \
            "$PROJ/.claude/rules" "$PROJ/.claude/skills" "$PROJ/.claude/hooks" "$PROJ/.githooks" \
            "$PROJ/scripts/forge" "$PROJ/CLAUDE.md" "$GC" "$FC" "$PROJ/.carl/manifest" 2>/dev/null; then
            oky "D5: no residual {{token}} on the real filled config/tree"
        else
            blk "D5: residual {{token}} remains on the REAL filled config (fill via the questionnaire)"
        fi
    else
        blk "D5: forge-resolve.sh tripwire unavailable — cannot verify no-residual (fail-closed)"
    fi

    # ── SF5 + Gap-C: render parity from the FILLED gate.config ──
    local rc=0
    if [ -f "$PROJ/scripts/forge/render-skill-gate.sh" ]; then
        ( cd "$PROJ" && bash scripts/forge/render-skill-gate.sh --check ) >/dev/null 2>&1 || rc=$?
        case "$rc" in
            0) oky "SF5: skill-gate.md in parity with filled gate.config (single-source)" ;;
            1) blk "SF5: skill-gate.md drifts from filled gate.config — re-render ('fill') before deploy" ;;
            *) blk "Gap-C: render-skill-gate.sh could not render the filled gate.config (render-fail → BLOCK)" ;;
        esac
    else
        blk "SF5: render-skill-gate.sh missing — cannot verify skill-gate parity (fail-closed)"
    fi

    echo ""
    if [ "$BLOCK" -eq 1 ]; then echo "DEPLOY: BLOCKED"; exit 1; else echo "DEPLOY: READY"; exit 0; fi
}

SUB="${1:-check}"
case "$SUB" in
    fill)      shift; cmd_fill "$@" ;;
    check)     shift || true; cmd_check "$@" ;;
    -h|--help) sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)         cmd_check "$@" ;;   # default action; e.g. `forge-deploy-check.sh --project-dir X`
esac
