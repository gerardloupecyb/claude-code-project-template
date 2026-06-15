#!/usr/bin/env bash
set -uo pipefail
# ============================================================================
# forge-checksetup-class.test.sh — AC-5-6 class-aware executor reporting (Plan 05)
# ============================================================================
# check-setup.sh reports executor/routing/MCP state, never silent, and enforces:
#   - ordinary phase + a family with no voice → DEGRADE (visible, non-blocking)
#   - cross-vendor class + same → BLOCK (no waiver, RED)
#   - declared executor with no installer → 'no installer for X' (RED)
#   - install declined → NOT-PROVISIONED (RED)
# Hermetic: PATH is doctored so a stub `codex` is present and `gemini` is absent;
# bash/jq/git come from the system dirs. The base 5 checks are GREEN so the CLASS
# drives the verdict.
# ============================================================================

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO/check-setup.sh"
BASH_BIN="$(command -v bash)"

PASS=0; FAIL=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

# stub bin: codex present, gemini absent (PATH excludes the nvm bin)
BIN="$(mktemp -d)"; printf '#!/bin/sh\nexit 0\n' > "$BIN/codex"; chmod +x "$BIN/codex"
RUNPATH="$BIN:/usr/bin:/bin"
run() { env PATH="$RUNPATH" "$BASH_BIN" "$SCRIPT" "$@"; }

mkbase() {  # GREEN-base project with cross_vendor_voices; extra jq filter via $1 (optional)
    local d; d="$(mktemp -d)"; mkdir -p "$d/.claude" "$d/.githooks"
    jq -n '{project_name:"acme", _no_compliance_frameworks_affirmed:true,
            model_router:{cross_vendor_voices:{openai:["codex-cli","openrouter"], google:["gemini-cli"]}}}' \
        > "$d/.claude/forge.config.json"
    jq -n '{_no_protected_domains_affirmed:true, protected_domains:[], gated_mcp:[]}' > "$d/.claude/gate.config.json"
    printf '{}' > "$d/.claude/settings.json"
    ( cd "$d" && git init -q && git config core.hooksPath .githooks )
    if [ -n "${1:-}" ]; then jq "$1" "$d/.claude/forge.config.json" > "$d/.claude/fc.tmp" && mv "$d/.claude/fc.tmp" "$d/.claude/forge.config.json"; fi
    printf '%s' "$d"
}

echo "── AC-5-6 ordinary class: missing voice → DEGRADE (visible, non-blocking) ──"
P="$(mkbase)"
out="$(run --class ordinary --project-dir "$P" 2>&1)"; rc=$?
printf '%s' "$out" | grep -q 'codex-cli (openai): available' && ok "codex reported available" || bad "codex not reported available"
printf '%s' "$out" | grep -qi 'single-vendor degrade' && ok "google family → 'single-vendor degrade' (visible)" || bad "no single-vendor degrade line"
printf '%s' "$out" | grep -q 'BLOCK' && bad "ordinary class wrongly emitted BLOCK" || ok "ordinary class did NOT BLOCK"
[ "$rc" -eq 0 ] && ok "ordinary degrade is non-blocking (verdict GREEN, rc 0)" || bad "ordinary verdict rc=$rc (want 0)"

echo "── AC-5-6 cross-vendor class: SAME state → BLOCK ──"
out="$(run --class cross-vendor --project-dir "$P" 2>&1)"; rc=$?
printf '%s' "$out" | grep -q 'BLOCK' && ok "cross-vendor class → BLOCK" || bad "no BLOCK on cross-vendor class"
printf '%s' "$out" | grep -qi 'no-waiver' && ok "BLOCK labelled no-waiver" || bad "BLOCK not labelled no-waiver"
[ "$rc" -ne 0 ] && ok "cross-vendor BLOCK → verdict RED (rc $rc)" || bad "cross-vendor did not block (rc 0)"

echo "── AC-5-6 declared executor with no installer → fail-loud ──"
P3="$(mkbase '.model_router.cross_vendor_voices.openai += ["weirdvoice"]')"
out="$(run --class ordinary --project-dir "$P3" 2>&1)"; rc=$?
printf '%s' "$out" | grep -qi 'no installer for weirdvoice' && ok "unknown executor → 'no installer for weirdvoice'" || bad "no fail-loud for unknown executor"
[ "$rc" -ne 0 ] && ok "unknown executor → RED (rc $rc)" || bad "unknown executor not RED"

echo "── AC-5-6 install declined → NOT-PROVISIONED + RED ──"
P4="$(mkbase '.model_router.executors_declined = ["gemini-cli"]')"
out="$(run --class ordinary --project-dir "$P4" 2>&1)"; rc=$?
printf '%s' "$out" | grep -qi 'NOT-PROVISIONED (install declined)' && ok "declined → NOT-PROVISIONED line" || bad "no NOT-PROVISIONED line"
[ "$rc" -ne 0 ] && ok "declined → RED (rc $rc)" || bad "declined not RED"

echo "── AC-5-6 never silent: a section header is always printed ──"
printf '%s' "$out" | grep -q 'Executor / routing / MCP' && ok "executor section header always printed (never silent)" || bad "executor section missing"

rm -rf "$BIN" "$P" "$P3" "$P4"
echo ""
echo "── result: $PASS passed, $FAIL failed ──"
[ "$FAIL" -eq 0 ]
