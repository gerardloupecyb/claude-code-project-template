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

# (iv) settings.json placed (gate wired) — STRUCTURED exact-match (Path A — post-backstop paradigm shift).
# Three text-match fixes proved a regex on the command STRING cannot parse shell grammar: it both LEAKED
# non-invoking forms (`"…/pre-tool-use.sh "` trailing-space-in-quote, `X="…"` / `HOOKS=(…)` assignments,
# bare path mentions) AND false-RED real ones (fully-quoted, exec, bash -c, source). So we abandon
# text-match and compare STRUCTURED DATA: the canonical command is read from settings.json.template (the
# single source of truth, which ships beside this tool), and we assert the placed settings.json registers
# THAT EXACT command as a `type=="command"` hook under a SINGLE PreToolUse entry whose matcher COVERS the
# gate verbs (Write/Edit/MultiEdit/Bash). By construction a non-invoking command (≠ the exact string) → RED;
# the forge-placed command → GREEN. The full TUPLE (event+matcher+command in the SAME entry) is matched, so
# a hook under the wrong event or behind a too-narrow matcher cannot false-GREEN. A residual {{token}}
# anywhere in settings.json still REDs (separate check below — Note 2: token non-resolution must not GREEN).
SJ="$PROJ/.claude/settings.json"
SJT="$(dirname "$0")/.claude/settings.json.template"
# canonical gate command = the SSOT template's PreToolUse command ending in /pre-tool-use.sh (NOT the
# -git-commit hook); pinned-constant fallback keeps the check usable if the tool is run detached from
# the template (a suite test pins this constant == the template's command, so the SSOT never drifts).
EXPECTED_HOOK_CMD='"$CLAUDE_PROJECT_DIR"/.claude/hooks/pre-tool-use.sh'
if [ -f "$SJT" ]; then
    _t="$(jq -r 'first(.hooks.PreToolUse[]?.hooks[]? | select(.type=="command") | .command | select(endswith("/pre-tool-use.sh"))) // empty' "$SJT" 2>/dev/null)"
    [ -n "$_t" ] && EXPECTED_HOOK_CMD="$_t"
fi
if [ ! -f "$SJ" ]; then fail "settings.json MISSING (run forge-init to place it)"
elif ! jq -e . "$SJ" >/dev/null 2>&1; then fail "settings.json is not valid JSON"
elif ! jq -e --arg cmd "$EXPECTED_HOOK_CMD" '
    [ .hooks.PreToolUse
      | select(type == "array")                       # PreToolUse MUST be an array — jq `[]?` iterates an
      | .[] | . as $e                                 #   OBJECT''s values too, so an object-shaped container
      | ($e.hooks // null) | select(type == "array")  #   would false-GREEN (Claude Code requires arrays here)
      | [ .[] | select(.type=="command") | .command ] as $cmds
      | select( $cmds | index($cmd) )                 # entry registers the EXACT command as a type==command hook
      | ($e.matcher // "") as $m
      | select( ["Write","Edit","MultiEdit","Bash"] | all( . as $v | $v | test($m) ) )  # ...and its matcher COVERS the gate verbs
    ] | length > 0' "$SJ" >/dev/null 2>&1; then
    fail "settings.json present but no PreToolUse entry registers the canonical gate command ($EXPECTED_HOOK_CMD) as a type==command under a matcher covering Write/Edit/MultiEdit/Bash — the gate is not wired as forge placed it (a command that only mentions/encodes the path, or a too-narrow matcher, does NOT count; re-run forge-init)"
elif grep -q '{{[A-Za-z0-9_]' "$SJ"; then
    fail "settings.json has an unresolved {{token}} (e.g. {{GATED_MCP_PREFIXES}} in a matcher → inert prod-MCP gate) — re-run forge-init"
else pass "settings.json present + canonical pre-tool-use.sh hook registered (exact command, covering matcher) + no residual {{token}}"; fi

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
