#!/usr/bin/env bash
set -uo pipefail
# ============================================================================
# forge-init-tripwire.test.sh — AC-4-8 unresolved-token tripwire (Phase 22 Plan 04)
# ============================================================================
# Validates the fail-closed tripwire + the D5 cycle-break: Plan 04 goes GREEN with
# a FIXTURE config supplying every answer — NO dependency on the Plan-05
# questionnaire (no 04↔05 completion cycle).
# ============================================================================

REPO="$(cd "$(dirname "$0")/.." && pwd)"
. "$REPO/.forge/forge-resolve.sh"

PASS=0; FAIL=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

echo "── AC-4-8 tripwire unit ──"
# A + B(F11): planted residual including a digit-bearing token
D="$(mktemp -d)"; mkdir -p "$D/.claude/rules"
printf 'see {{FOO}} and {{COMPLIANCE_FRAMEWORK_1}} here\n' > "$D/.claude/rules/x.md"
OUT="$(tripwire_scan "$D/.claude/rules" 2>&1)"; RC=$?
[ "$RC" -ne 0 ] && ok "(A) residual tokens ⇒ non-zero exit" || bad "(A) did not fail on residual"
printf '%s' "$OUT" | grep -q '{{FOO}}' && ok "(A) names offender {{FOO}}" || bad "(A) did not name {{FOO}}"
printf '%s' "$OUT" | grep -q '{{COMPLIANCE_FRAMEWORK_1}}' && ok "(B/F11) names digit token {{COMPLIANCE_FRAMEWORK_1}}" || bad "(B/F11) missed the digit token"
# demonstrate why F11 is needed: the narrow [A-Za-z_]+ regex MISSES the digit token
if printf '{{COMPLIANCE_FRAMEWORK_1}}' | grep -qE '\{\{[A-Za-z_]+\}\}'; then
    bad "(B) narrow [A-Za-z_]+ unexpectedly matched the digit token"
else
    ok "(B) narrow [A-Za-z_]+ regex MISSES the digit token — F11 [A-Za-z0-9_-] is required"
fi
rm -rf "$D"

# C: clean tree ⇒ exit 0
D2="$(mktemp -d)"; mkdir -p "$D2/.claude/rules"; printf 'no tokens here at all\n' > "$D2/.claude/rules/clean.md"
tripwire_scan "$D2/.claude/rules" >/dev/null 2>&1 && ok "(C) clean tree ⇒ exit 0" || bad "(C) false positive on clean tree"
rm -rf "$D2"

# E: an empty config slice value (project_name:"") is NOT a token → not flagged
D3="$(mktemp -d)"; printf '{"project_name":"","compliance_frameworks":[]}\n' > "$D3/forge.config.json"
tripwire_scan "$D3/forge.config.json" >/dev/null 2>&1 && ok "(E) empty config value is NOT flagged (D1 sentinel, not a token)" || bad "(E) flagged an empty config value"
rm -rf "$D3"

echo "── AC-4-8 D5 cycle-break (fixture config, NO Plan-05 questionnaire) ──"
TF="$REPO/forge-init.sh"
# (D5a) bare init (config-only) ⇒ RED on the structural residuals (exit 6)
W1="$(mktemp -d)"; WORKSPACE_DIR="$W1" bash "$TF" "TripBare" tripbare "a,b" >/dev/null 2>&1; RC1=$?
[ "$RC1" -eq 6 ] && ok "(D5a) bare init (no answers) ⇒ tripwire RED, exit 6" || bad "(D5a) bare init exit=$RC1 (expected 6)"

# build a FIXTURE answers file covering every residual FORGE-tree token (every answer
# supplied locally — this is what proves Plan 04 is green WITHOUT the questionnaire)
SCOPE=(".claude/rules" ".claude/skills" ".claude/hooks" ".githooks" "scripts/forge" "CLAUDE.md" ".claude/gate.config.json" ".claude/forge.config.json" ".carl/manifest")
PATHS=(); for p in "${SCOPE[@]}"; do [ -e "$W1/TripBare/$p" ] && PATHS+=("$W1/TripBare/$p"); done
ANSF="$(mktemp)"
grep -rhoE '\{\{[A-Za-z0-9_][A-Za-z0-9_-]*\}\}' "${PATHS[@]}" 2>/dev/null | sort -u | sed 's/^{{//; s/}}$//' \
    | jq -R . | jq -s 'map({key: ., value: "fixtureval"}) | from_entries' > "$ANSF"
echo "  fixture answers cover $(jq 'length' "$ANSF") residual structural tokens"

# (D5b) fresh init WITH the complete fixture ⇒ GREEN (exit 0)
W2="$(mktemp -d)"; WORKSPACE_DIR="$W2" bash "$TF" --answers "$ANSF" "TripFull" tripfull "a,b" >/tmp/tripfull.log 2>&1; RC2=$?
if [ "$RC2" -eq 0 ]; then
    ok "(D5b) full-fixture init ⇒ tripwire GREEN, exit 0 (no Plan-05 questionnaire needed)"
else
    bad "(D5b) full-fixture init exit=$RC2 (expected 0)"; tail -8 /tmp/tripfull.log | sed 's/^/    /'
fi
rm -rf "$W1" "$W2" "$ANSF"

echo ""
echo "── result: ${PASS} passed, ${FAIL} failed ──"
[ "$FAIL" -eq 0 ]
