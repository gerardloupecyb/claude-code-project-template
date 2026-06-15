#!/usr/bin/env bash
set -uo pipefail
# ============================================================================
# forge-init-checksetup.test.sh — AC-4-2 [SENSIBLE] gate-wiring (Phase 22 Plan 04)
# ============================================================================
# Covers: the D1/SF2 positive-per-concern sentinel matrix, NO-CLOBBER settings
# placement, core.hooksPath install, and a REAL gate-fire (pre-tool-use blocks a
# Write into a configured protected domain — observed, not assumed).
# ============================================================================

REPO="$(cd "$(dirname "$0")/.." && pwd)"
. "$REPO/.forge/forge-resolve.sh"
CHECK="$REPO/check-setup.sh"
INIT="$REPO/forge-init.sh"

PASS=0; FAIL=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

# minimal project fixture with VALID wiring (settings.json + githooks) so the matrix
# isolates the config sentinel (i/ii/iii). $1=forge.config json  $2=gate.config json
mkproj() {
    local d; d="$(mktemp -d)"
    mkdir -p "$d/.claude" "$d/.githooks"
    printf '%s\n' "$1" > "$d/.claude/forge.config.json"
    printf '%s\n' "$2" > "$d/.claude/gate.config.json"
    printf '{}\n' > "$d/.claude/settings.json"
    ( cd "$d" && git init -q && git config core.hooksPath .githooks )
    echo "$d"
}
verdict() { bash "$CHECK" "$1" >/dev/null 2>&1; echo $?; }   # 0=GREEN 1=RED

echo "── AC-4-2 D1/SF2 sentinel matrix ──"
# 1. all satisfied → GREEN
D="$(mkproj '{"project_name":"Acme","compliance_frameworks":["SOC2"]}' '{"protected_domains":[{"name":"x"}]}')"
[ "$(verdict "$D")" = 0 ] && ok "(1) name+domains+compliance filled ⇒ GREEN" || bad "(1) expected GREEN"; rm -rf "$D"
# 2. affirmed-none on both empties → GREEN
D="$(mkproj '{"project_name":"Acme","compliance_frameworks":[],"_no_compliance_frameworks_affirmed":true}' '{"protected_domains":[],"_no_protected_domains_affirmed":true}')"
[ "$(verdict "$D")" = 0 ] && ok "(2) empties affirmed by positive flags ⇒ GREEN" || bad "(2) expected GREEN"; rm -rf "$D"
# 3. project_name NEVER waivable: empty name + both affirm flags → RED
D="$(mkproj '{"project_name":"","compliance_frameworks":[],"_no_compliance_frameworks_affirmed":true}' '{"protected_domains":[],"_no_protected_domains_affirmed":true}')"
[ "$(verdict "$D")" = 1 ] && ok "(3) empty project_name + both flags ⇒ STILL RED (never waivable)" || bad "(3) expected RED"; rm -rf "$D"
# 4. delete-without-affirm (domains): empty domains, no flag → RED
D="$(mkproj '{"project_name":"Acme","compliance_frameworks":["SOC2"]}' '{"protected_domains":[]}')"
[ "$(verdict "$D")" = 1 ] && ok "(4) empty domains, no affirm flag ⇒ RED (delete-without-affirm closed)" || bad "(4) expected RED"; rm -rf "$D"
# 5. Gap A — compliance delete-without-affirm: empty compliance, no flag → RED
D="$(mkproj '{"project_name":"Acme","compliance_frameworks":[]}' '{"protected_domains":[{"name":"x"}]}')"
[ "$(verdict "$D")" = 1 ] && ok "(5/GapA) empty compliance, no affirm flag ⇒ RED (symmetric)" || bad "(5) expected RED"; rm -rf "$D"
# 6. affirm waives ONLY its own concern: domains affirmed, compliance empty+no flag → RED
D="$(mkproj '{"project_name":"Acme","compliance_frameworks":[]}' '{"protected_domains":[],"_no_protected_domains_affirmed":true}')"
[ "$(verdict "$D")" = 1 ] && ok "(6) _no_protected_domains_affirmed waives ONLY domains (compliance still RED)" || bad "(6) expected RED"; rm -rf "$D"
# 7. Gap B — idempotency: RED config hand-fixed → re-run flips GREEN, no questionnaire
D="$(mkproj '{"project_name":"Acme","compliance_frameworks":["SOC2"]}' '{"protected_domains":[]}')"
[ "$(verdict "$D")" = 1 ] && ok "(7a) blocked config ⇒ RED" || bad "(7a) expected RED"
# hand-fix: add the positive affirmation flag
tmp="$(mktemp)"; jq '. + {"_no_protected_domains_affirmed":true}' "$D/.claude/gate.config.json" > "$tmp" && mv "$tmp" "$D/.claude/gate.config.json"
[ "$(verdict "$D")" = 0 ] && ok "(7b/GapB) re-run after hand-fix ⇒ GREEN (idempotent, no questionnaire)" || bad "(7b) expected GREEN after fix"; rm -rf "$D"

echo "── AC-4-2 forge-init wiring (NO-CLOBBER + hooksPath + gate-fire) ──"
# build a complete fixture answers file from a bare init's residual FORGE tokens
WB="$(mktemp -d)"; WORKSPACE_DIR="$WB" bash "$INIT" "Seed" seeddom "a" >/dev/null 2>&1 || true
SCOPE=(".claude/rules" ".claude/skills" ".claude/hooks" ".githooks" "scripts/forge" "CLAUDE.md" ".claude/gate.config.json" ".claude/forge.config.json" ".carl/manifest")
SP=(); for s in "${SCOPE[@]}"; do [ -e "$WB/Seed/$s" ] && SP+=("$WB/Seed/$s"); done
ANS="$(mktemp)"; grep -rhoE '\{\{[A-Za-z0-9_][A-Za-z0-9_-]*\}\}' "${SP[@]}" 2>/dev/null | sort -u | sed 's/^{{//;s/}}$//' \
    | jq -R . | jq -s 'map({key:.,value:"genericstack"})|from_entries' > "$ANS"
rm -rf "$WB"

# full init ⇒ GREEN exit 0, settings placed, hooksPath set
WP="$(mktemp -d)"; WORKSPACE_DIR="$WP" bash "$INIT" --answers "$ANS" "WireProj" wiredom "a,b" >/tmp/wire.log 2>&1; RCI=$?
PROJ="$WP/WireProj"
[ "$RCI" -eq 0 ] && ok "(init) full-fixture forge-init ⇒ exit 0" || { bad "(init) exit=$RCI"; tail -6 /tmp/wire.log | sed 's/^/    /'; }
[ -f "$PROJ/.claude/settings.json" ] && jq -e . "$PROJ/.claude/settings.json" >/dev/null 2>&1 && ok "(place) settings.json placed + valid JSON" || bad "(place) settings.json missing/invalid"
[ ! -e "$PROJ/.claude/settings.json.template" ] && ok "(place) template consumed" || bad "(place) template not consumed"
grep -qiE '"matcher":[^,]*(azure|n8n|ghl)' "$PROJ/.claude/settings.json" && bad "(place) LEAKED a Loupe domain matcher" || ok "(place) no Loupe domain matcher in settings.json"
[ "$(git -C "$PROJ" config --get core.hooksPath 2>/dev/null)" = ".githooks" ] && ok "(hooks) core.hooksPath = .githooks" || bad "(hooks) hooksPath not set"

# NO-CLOBBER (function-level, observed): pre-existing settings.json is left untouched
NC="$(mktemp -d)"; mkdir -p "$NC/.claude"
printf '{"_mine":"DO_NOT_OVERWRITE"}\n' > "$NC/.claude/settings.json"
printf '{"hooks":{}}\n' > "$NC/.claude/settings.json.template"
place_settings "$NC" 2>/dev/null
if grep -q 'DO_NOT_OVERWRITE' "$NC/.claude/settings.json" && [ ! -e "$NC/.claude/settings.json.template" ]; then
    ok "(NO-CLOBBER) pre-existing settings.json untouched, template discarded"
else
    bad "(NO-CLOBBER) pre-existing settings.json was clobbered"
fi
rm -rf "$NC"

# REAL gate-fire: configure a protected domain, attempt a matching Write ⇒ pre-tool-use exit 2
tmp="$(mktemp)"; jq '.protected_domains += [{"name":"secretdom","marker":"secretdom","file_patterns":"\\.secret$","command_patterns":"","required_skills":"secret-skill","lessons_domain":"sec","unlock":"touch .skill-locks/secretdom"}]' "$PROJ/.claude/gate.config.json" > "$tmp" && mv "$tmp" "$PROJ/.claude/gate.config.json"
GATE_IN='{"tool_name":"Write","tool_input":{"file_path":"config/app.secret"}}'
printf '%s' "$GATE_IN" | CLAUDE_PROJECT_DIR="$PROJ" bash "$PROJ/.claude/hooks/pre-tool-use.sh" >/dev/null 2>&1; GRC=$?
[ "$GRC" -eq 2 ] && ok "(gate-fire) Write into protected domain BLOCKED (pre-tool-use exit 2, observed)" || bad "(gate-fire) expected exit 2, got $GRC"
# with the unlock marker present ⇒ allowed (exit 0)
mkdir -p "$PROJ/.skill-locks" && touch "$PROJ/.skill-locks/secretdom"
printf '%s' "$GATE_IN" | CLAUDE_PROJECT_DIR="$PROJ" bash "$PROJ/.claude/hooks/pre-tool-use.sh" >/dev/null 2>&1; GRC2=$?
[ "$GRC2" -eq 0 ] && ok "(gate-fire) with unlock marker ⇒ allowed (exit 0)" || bad "(gate-fire) marker present but exit=$GRC2"

rm -rf "$WP" "$ANS"
echo ""
echo "── result: ${PASS} passed, ${FAIL} failed ──"
[ "$FAIL" -eq 0 ]
