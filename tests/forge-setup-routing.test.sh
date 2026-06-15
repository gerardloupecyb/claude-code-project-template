#!/usr/bin/env bash
set -uo pipefail
# ============================================================================
# forge-setup-routing.test.sh — AC-5-1 routing-questionnaire oracle (Phase 22 Plan 05)
# ============================================================================
# Asserts the deploy-time ROUTING questionnaire:
#   (1) writes model_router.cross_vendor_voices to forge.config.json (openai+google)
#   (2) does NOT write routing into gate.config.json (grep model_router /
#       adversarial_reviewers = 0) — the D-11 hot-config invariant
#   (3) leaves NO residual {{...}} in router-rules.md after the stack answers
#   (4) keeps the canonical OpenRouter→gpt-5.5 fallback line in router-rules.md
#   (5) is idempotent (second run = byte-identical forge.config model_router)
#   (6) preserves the model_router siblings (_canonical_source etc.) — no clobber
# ============================================================================

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SETUP="$REPO/forge-setup-executors.sh"

PASS=0; FAIL=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

echo "── AC-5-1 routing questionnaire ──"

# Build an isolated project copy carrying the real template config + skeleton.
PROJ="$(mktemp -d)"
mkdir -p "$PROJ/.claude/rules" "$PROJ/.forge"
cp "$REPO/.claude/forge.config.json" "$PROJ/.claude/forge.config.json"
cp "$REPO/.claude/gate.config.json"  "$PROJ/.claude/gate.config.json"
cp "$REPO/.claude/rules/router-rules.md" "$PROJ/.claude/rules/router-rules.md"
cp "$REPO/.forge/forge-resolve.sh"   "$PROJ/.forge/forge-resolve.sh"
# the script sources .forge/forge-resolve.sh relative to ITS OWN dir, so run a copy
# of the script from inside the project so the relative source resolves there too.
cp "$SETUP" "$PROJ/forge-setup-executors.sh"
SETUP_LOCAL="$PROJ/forge-setup-executors.sh"

bash "$SETUP_LOCAL" routing --project-dir "$PROJ" \
    --openai "codex-cli,openrouter" --google "gemini-cli" \
    --scripting-lang python --cloud-provider AWS --workflow-engine airflow --project-slug acme \
    >/dev/null 2>&1
RC=$?
[ "$RC" -eq 0 ] && ok "routing exits 0 on a clean run" || bad "routing exit=$RC (want 0)"

FC="$PROJ/.claude/forge.config.json"
GC="$PROJ/.claude/gate.config.json"
RR="$PROJ/.claude/rules/router-rules.md"

# (1) model_router.cross_vendor_voices populated in forge.config.json
oa="$(jq -rc '.model_router.cross_vendor_voices.openai' "$FC" 2>/dev/null)"
go="$(jq -rc '.model_router.cross_vendor_voices.google' "$FC" 2>/dev/null)"
[ "$oa" = '["codex-cli","openrouter"]' ] && ok "forge.config openai voices = [codex-cli, openrouter]" || bad "openai voices = $oa"
[ "$go" = '["gemini-cli"]' ] && ok "forge.config google voices = [gemini-cli]" || bad "google voices = $go"

# (2) gate.config.json carries NO routing (D-11 hot-config invariant)
if grep -Eq 'model_router|cross_vendor_voices|adversarial_reviewers' "$GC"; then
    bad "gate.config.json contains routing keys (D-11 violation)"
else
    ok "gate.config.json has NO routing keys (D-11 hot-config clean)"
fi

# (3) no residual {{...}} in router-rules.md
res="$(grep -oE '\{\{[A-Za-z0-9_][A-Za-z0-9_-]*\}\}' "$RR" 2>/dev/null | sort -u)"
[ -z "$res" ] && ok "router-rules.md has no residual {{tokens}}" || bad "router-rules residuals: $(echo "$res" | tr '\n' ' ')"

# (4) the canonical OpenRouter→gpt-5.5 fallback line survived
grep -q 'gpt-5.5' "$RR" && ok "router-rules keeps the OpenRouter gpt-5.5 fallback line" || bad "gpt-5.5 fallback line missing from router-rules"

# (5) idempotent: a second run leaves model_router byte-identical
before="$(jq -S '.model_router' "$FC")"
bash "$SETUP_LOCAL" routing --project-dir "$PROJ" \
    --openai "codex-cli,openrouter" --google "gemini-cli" \
    --scripting-lang python --cloud-provider AWS --workflow-engine airflow --project-slug acme \
    >/dev/null 2>&1
after="$(jq -S '.model_router' "$FC")"
[ "$before" = "$after" ] && ok "routing is idempotent (model_router unchanged on re-run)" || bad "routing not idempotent"

# (6) model_router siblings preserved (the D-13 _canonical_source note still there)
jq -e '.model_router._canonical_source != null and (.model_router._canonical_source|type=="string")' "$FC" >/dev/null 2>&1 \
    && ok "model_router siblings preserved (_canonical_source intact)" || bad "model_router siblings clobbered"

rm -rf "$PROJ"
echo ""
echo "── result: $PASS passed, $FAIL failed ──"
[ "$FAIL" -eq 0 ]
