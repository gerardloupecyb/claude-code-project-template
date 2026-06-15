#!/usr/bin/env bash
set -uo pipefail
# ============================================================================
# forge-setup-executors.sh — deploy-time executor routing + provisioning ([SENSIBLE])
# ============================================================================
# FORGE Phase 22 Plan 05. Walks a new project through (1) ROUTING configuration
# (models/executors + fallback chains → forge.config.json model_router), and — in
# later subcommands — leak-proof executor key provisioning, auth probes, and the
# OpenRouter MCP launch-env wiring. [SENSIBLE] cross-vendor no-waiver surface.
#
# D-11 INVARIANT (load-bearing): the model_router block lives in forge.config.json
# (doc/wiring), NEVER gate.config.json. The security hooks (pre-tool-use.sh /
# pre-mcp-gate.sh) read ONLY gate.config.json on the hot path; they must never
# source routing. This script writes routing to forge.config.json and is
# STRUCTURALLY incapable of writing it to gate.config.json — the gate.config path
# is NEVER a write target in any code path here. No invented `adversarial_reviewers`
# field is created: the real field is forge.config.json model_router.cross_vendor_voices.
#
# D-13: model VERSIONS are NOT pinned here — forge.config.json model_router carries
# the executor TRANSPORTS (codex-cli / openrouter / gemini-cli); the canonical model
# IDs (e.g. openai/gpt-5.5) live in .claude/rules/router-rules.md (the doc).
#
# Subcommands:
#   routing   AC-5-1  write model_router.cross_vendor_voices + fill router-rules skeleton
#   (keys / probe / mcp added by Plan-05 Tasks 2-3)
#
# Usage:
#   forge-setup-executors.sh routing [--project-dir DIR]
#       [--openai LIST] [--google LIST]              (executor transports, comma-sep)
#       [--scripting-lang L] [--cloud-provider C] [--workflow-engine W] [--project-slug P]
#   A flag omitted on a TTY is prompted (canonical default offered); omitted without
#   a TTY uses the canonical default. Canonical chains:
#       OpenAI → Codex CLI → OpenRouter (gpt-5.5) ;  Google → Gemini CLI (→ flash)
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v jq >/dev/null 2>&1 || { echo "forge-setup-executors: jq required" >&2; exit 2; }

# Canonical cross-vendor defaults (the D-15 fallback chain; transports, not models).
DEFAULT_OPENAI="codex-cli,openrouter"
DEFAULT_GOOGLE="gemini-cli"

# csv → compact JSON array of trimmed non-empty tokens
_csv_to_json_array() {  # $1=csv
    printf '%s' "$1" | jq -R 'split(",") | map(gsub("^\\s+|\\s+$";"")) | map(select(length>0))'
}

# prompt-with-default ONLY when interactive; otherwise echo the default (no stdin read)
_ask() {  # $1=prompt  $2=default  → value on stdout
    local prompt="$1" def="$2" ans=""
    if [ -t 0 ]; then
        printf '%s [%s]: ' "$prompt" "$def" >&2
        IFS= read -r ans || ans=""
    fi
    [ -z "$ans" ] && ans="$def"
    printf '%s' "$ans"
}

cmd_routing() {
    local PROJECT_DIR="." OPENAI="" GOOGLE="" SLANG="__UNSET__" CLOUD="__UNSET__" WENG="__UNSET__" PSLUG="__UNSET__"
    while [ $# -gt 0 ]; do
        case "$1" in
            --project-dir)      PROJECT_DIR="$2"; shift 2 ;;
            --openai)           OPENAI="$2"; shift 2 ;;
            --google)           GOOGLE="$2"; shift 2 ;;
            --scripting-lang)   SLANG="$2"; shift 2 ;;
            --cloud-provider)   CLOUD="$2"; shift 2 ;;
            --workflow-engine)  WENG="$2"; shift 2 ;;
            --project-slug)     PSLUG="$2"; shift 2 ;;
            *) echo "forge-setup-executors routing: unknown option '$1'" >&2; return 2 ;;
        esac
    done

    local FC="$PROJECT_DIR/.claude/forge.config.json"
    local RR="$PROJECT_DIR/.claude/rules/router-rules.md"
    [ -f "$FC" ] || { echo "forge-setup-executors routing: forge.config.json not found: $FC" >&2; return 2; }
    jq -e . "$FC" >/dev/null 2>&1 || { echo "forge-setup-executors routing: forge.config.json invalid JSON: $FC" >&2; return 2; }

    # --- executor transports (cross_vendor_voices) -------------------------------
    [ -z "$OPENAI" ] && OPENAI="$(_ask 'OpenAI voice transports (csv, order = fallback chain)' "$DEFAULT_OPENAI")"
    [ -z "$GOOGLE" ] && GOOGLE="$(_ask 'Google voice transports (csv)' "$DEFAULT_GOOGLE")"
    local openai_arr google_arr
    openai_arr="$(_csv_to_json_array "$OPENAI")" || { echo "routing: bad --openai list" >&2; return 2; }
    google_arr="$(_csv_to_json_array "$GOOGLE")" || { echo "routing: bad --google list" >&2; return 2; }

    # --- write model_router.cross_vendor_voices to forge.config.json ONLY --------
    # jq merge preserves _canonical_source / primary_executor / subagent_executor; the
    # write target is forge.config.json by construction — gate.config.json is never opened.
    local tmp; tmp="$(mktemp)"
    jq --argjson openai "$openai_arr" --argjson google "$google_arr" '
        .model_router = (.model_router // {})
        | .model_router.cross_vendor_voices = { openai: $openai, google: $google }
    ' "$FC" > "$tmp" 2>/dev/null && jq -e . "$tmp" >/dev/null 2>&1 || {
        echo "routing: failed to write model_router (fail-closed, forge.config untouched)" >&2; rm -f "$tmp"; return 1
    }
    mv "$tmp" "$FC"
    echo "  ✓ model_router.cross_vendor_voices written to forge.config.json (openai=$OPENAI ; google=$GOOGLE)"

    # --- fill the parameterized router-rules skeleton (stack vocab tokens) --------
    # The executor chains are in forge.config; router-rules also references the
    # project's stack vocabulary. Resolve those tokens literally (injection-safe via
    # the Plan-04 awk/ENVIRON helper — no sed program, no metachar activity). A token
    # left UNSET stays {{...}} and is caught by the AC-5-7 deploy-block, not silently lost.
    if [ -f "$RR" ]; then
        # shellcheck source=/dev/null
        . "$SCRIPT_DIR/.forge/forge-resolve.sh" 2>/dev/null || {
            echo "  WARN: forge-resolve.sh not sourceable — router-rules tokens not resolved here (deploy-block will catch residuals)." >&2
        }
        if declare -F _forge_sub_text_file >/dev/null 2>&1; then
            [ "$SLANG" = "__UNSET__" ] && SLANG="$(_ask 'Primary scripting language (router-rules)' '')"
            [ "$CLOUD" = "__UNSET__" ] && CLOUD="$(_ask 'Primary cloud provider (router-rules)' '')"
            [ "$WENG"  = "__UNSET__" ] && WENG="$(_ask 'Primary workflow engine (router-rules)' '')"
            [ "$PSLUG" = "__UNSET__" ] && PSLUG="$(_ask 'Project slug (lowercase, router-rules)' "$(jq -r '.project_name // "" | ascii_downcase' "$FC")")"
            [ -n "$SLANG" ] && _forge_sub_text_file "$RR" "SCRIPTING_LANG"  "$SLANG"
            [ -n "$CLOUD" ] && _forge_sub_text_file "$RR" "CLOUD_PROVIDER"  "$CLOUD"
            [ -n "$WENG"  ] && _forge_sub_text_file "$RR" "WORKFLOW_ENGINE" "$WENG"
            [ -n "$PSLUG" ] && _forge_sub_text_file "$RR" "project"         "$PSLUG"
            echo "  ✓ router-rules skeleton stack tokens resolved (residuals, if any, are deploy-block-gated)"
        fi
    fi

    # --- D-11 self-assert: routing did NOT leak into gate.config.json ------------
    local GC="$PROJECT_DIR/.claude/gate.config.json"
    if [ -f "$GC" ] && grep -Eq '"?(model_router|cross_vendor_voices|adversarial_reviewers)"?' "$GC" 2>/dev/null; then
        echo "ERROR (D-11): routing keys found in gate.config.json — the security-hot config must never carry routing. Fail-closed." >&2
        return 1
    fi
    return 0
}

# ── dispatch ─────────────────────────────────────────────────────────────────
SUB="${1:-}"; shift || true
case "$SUB" in
    routing) cmd_routing "$@" ;;
    ""|-h|--help)
        sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
        exit 0 ;;
    *) echo "forge-setup-executors: unknown subcommand '$SUB' (have: routing)" >&2; exit 2 ;;
esac
