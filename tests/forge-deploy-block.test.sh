#!/usr/bin/env bash
set -uo pipefail
# ============================================================================
# forge-deploy-block.test.sh — AC-5-7 deploy-block oracle (N1; D1+D5+SF5) (Plan 05)
# ============================================================================
# Asserts the fail-closed deploy-block + the fill-to-correct-files:
#   D1 : project_name="" no affirm → BLOCK; fill → proceeds; empty compliance no
#        affirm → BLOCK; empty project_name + BOTH affirm flags → STILL BLOCK
#        (never waivable); empty protected_domains + positive flag → proceeds;
#        delete-without-affirm → still BLOCK
#   D5 : a residual {{token}} on the REAL filled config → BLOCK
#   SF5: render parity holds after fill+render; gate.config mutated without re-render → drift BLOCK
#   GapC: malformed gate.config (render-fail) → BLOCK
#   fill: writes to the CORRECT files (forge.config / gate.config), no routing in gate.config (D-11)
# ============================================================================

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEP="$REPO/forge-deploy-check.sh"

PASS=0; FAIL=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

# minimal but REAL project: render deps + token-free skill-gate w/ markers + sliced configs
mkproj() {
    local d; d="$(mktemp -d)"
    mkdir -p "$d/.claude/rules" "$d/.claude/hooks/lib" "$d/scripts/forge" "$d/.forge"
    cp "$REPO/scripts/forge/render-skill-gate.sh" "$d/scripts/forge/"
    cp "$REPO/.claude/hooks/lib/gate-config.sh"   "$d/.claude/hooks/lib/"
    cp "$REPO/.forge/forge-resolve.sh"            "$d/.forge/"
    cp "$DEP" "$d/forge-deploy-check.sh"   # sources .forge relative to ITS dir
    cat > "$d/.claude/rules/skill-gate.md" <<'EOF'
# Skill Gate (test)

<!-- BEGIN GENERATED: domain-routing -->
<!-- END GENERATED: domain-routing -->

<!-- BEGIN GENERATED: mcp-gating -->
<!-- END GENERATED: mcp-gating -->
EOF
    jq -n '{project_name:"", compliance_frameworks:[], doc_language:"en"}' > "$d/.claude/forge.config.json"
    jq -n '{protected_domains:[], gated_mcp:[]}' > "$d/.claude/gate.config.json"
    printf '%s' "$d"
}
DEPL() { bash "$1/forge-deploy-check.sh" "${@:2}"; }   # run the project's own copy

echo "── AC-5-7 D1: empty project_name (no affirm) → BLOCK ──"
P="$(mkproj)"
out="$(DEPL "$P" --project-dir "$P" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi 'project_name EMPTY' && ok "empty project_name → BLOCKED (names the field)" || bad "did not block empty project_name"

echo "── AC-5-7 fill → proceeds (READY) ──"
DEPL "$P" fill --project-dir "$P" --project-name "Acme Corp" --doc-language en --affirm-no-compliance --affirm-no-protected-domains >/dev/null 2>&1
out="$(DEPL "$P" --project-dir "$P" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'DEPLOY: READY' && ok "filled + affirmed → DEPLOY: READY" || { bad "fill did not reach READY (rc=$rc)"; printf '%s\n' "$out" | sed 's/^/    /'; }
# fill wrote to the CORRECT files
jq -e '.project_name == "Acme Corp"' "$P/.claude/forge.config.json" >/dev/null && ok "project_name written to forge.config" || bad "project_name not in forge.config"
grep -Eq 'model_router|cross_vendor_voices|adversarial_reviewers' "$P/.claude/gate.config.json" && bad "routing leaked into gate.config (D-11)" || ok "gate.config carries NO routing (D-11)"

echo "── AC-5-7 D1: empty compliance, no affirm → BLOCK ──"
P2="$(mkproj)"
jq '.project_name="Acme"' "$P2/.claude/forge.config.json" > "$P2/.claude/fc" && mv "$P2/.claude/fc" "$P2/.claude/forge.config.json"
jq '._no_protected_domains_affirmed=true' "$P2/.claude/gate.config.json" > "$P2/.claude/gc" && mv "$P2/.claude/gc" "$P2/.claude/gate.config.json"
out="$(DEPL "$P2" --project-dir "$P2" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi 'compliance_frameworks empty' && ok "empty compliance, no affirm → BLOCK" || bad "did not block empty compliance"

echo "── AC-5-7 D1: empty project_name + BOTH affirm flags → STILL BLOCK (never waivable) ──"
P3="$(mkproj)"
jq '._no_compliance_frameworks_affirmed=true' "$P3/.claude/forge.config.json" > "$P3/.claude/fc" && mv "$P3/.claude/fc" "$P3/.claude/forge.config.json"
jq '._no_protected_domains_affirmed=true' "$P3/.claude/gate.config.json" > "$P3/.claude/gc" && mv "$P3/.claude/gc" "$P3/.claude/gate.config.json"
out="$(DEPL "$P3" --project-dir "$P3" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi 'project_name EMPTY' && ok "empty project_name BLOCKS even with both affirm flags (never waivable)" || bad "project_name was waived (D1 violation)"

echo "── AC-5-7 D1: empty protected_domains + positive flag → that concern OK ──"
# (P with project_name + both affirms is READY — already shown; assert the protected_domains line is OK)
out="$(DEPL "$P" --project-dir "$P" 2>&1)"
printf '%s' "$out" | grep -qi 'protected_domains empty, affirmed' && ok "empty protected_domains + positive flag → affirmed OK" || bad "affirmed protected_domains not accepted"

echo "── AC-5-7 D5: residual {{token}} on the REAL filled config → BLOCK ──"
P4="$(mkproj)"
DEPL "$P4" fill --project-dir "$P4" --project-name "Acme" --affirm-no-compliance --affirm-no-protected-domains >/dev/null 2>&1
printf '\nleftover {{UNFILLED_TOKEN}} here\n' >> "$P4/.claude/rules/skill-gate.md"
out="$(DEPL "$P4" --project-dir "$P4" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi 'D5: residual' && ok "residual {{token}} on real config → BLOCK (D5)" || bad "D5 did not block a residual token"

echo "── AC-5-7 SF5: drift after gate.config mutation without re-render → BLOCK ──"
P5="$(mkproj)"
DEPL "$P5" fill --project-dir "$P5" --project-name "Acme" --affirm-no-compliance \
    --protected-domains '[{"name":"python","label":"Python","triggers_doc":"`.py`","required_skills":"python-architect","unlock":"touch .skill-locks/python"}]' >/dev/null 2>&1
DEPL "$P5" --project-dir "$P5" >/dev/null 2>&1 && rdy=0 || rdy=$?
[ "$rdy" -eq 0 ] && ok "after fill+render, parity holds (READY)" || bad "parity should hold post-fill (rc=$rdy)"
# mutate gate.config WITHOUT re-render → skill-gate.md now stale → drift BLOCK
jq '.protected_domains[0].label = "Python CHANGED"' "$P5/.claude/gate.config.json" > "$P5/.claude/gc" && mv "$P5/.claude/gc" "$P5/.claude/gate.config.json"
out="$(DEPL "$P5" --project-dir "$P5" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi 'SF5:.*drift' && ok "gate.config mutated w/o re-render → SF5 drift BLOCK" || bad "SF5 did not catch drift"

echo "── AC-5-7 Gap-C: malformed gate.config (render-fail) → BLOCK ──"
P6="$(mkproj)"
jq '.project_name="Acme" | ._no_compliance_frameworks_affirmed=true' "$P6/.claude/forge.config.json" > "$P6/.claude/fc" && mv "$P6/.claude/fc" "$P6/.claude/forge.config.json"
# protected_domains as a STRING → shape-invalid → render exits non-zero
jq '.protected_domains = "not-an-array"' "$P6/.claude/gate.config.json" > "$P6/.claude/gc" && mv "$P6/.claude/gc" "$P6/.claude/gate.config.json"
out="$(DEPL "$P6" --project-dir "$P6" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi 'Gap-C' && ok "malformed gate.config → render-fail → BLOCK (Gap-C)" || bad "Gap-C did not block a render-fail"

rm -rf "$P" "$P2" "$P3" "$P4" "$P5" "$P6"
echo ""
echo "── result: $PASS passed, $FAIL failed ──"
[ "$FAIL" -eq 0 ]
