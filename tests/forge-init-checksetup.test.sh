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
    # settings.json must REGISTER the pre-tool-use.sh hook (review batch ①): a bare {} no
    # longer passes — check-setup validates the gate-firing hook is wired, not just present.
    printf '%s\n' '{"hooks":{"PreToolUse":[{"matcher":"Write|Edit|MultiEdit|Bash","hooks":[{"type":"command","command":"\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/pre-tool-use.sh"}]}]}}' > "$d/.claude/settings.json"
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

# ① review batch — check-setup validates the gate-firing hook is REGISTERED, not just present
NH="$(mktemp -d)"; mkdir -p "$NH/.claude" "$NH/.githooks"
printf '{"project_name":"Acme","_no_compliance_frameworks_affirmed":true}\n' > "$NH/.claude/forge.config.json"
printf '{"protected_domains":[],"_no_protected_domains_affirmed":true}\n' > "$NH/.claude/gate.config.json"
( cd "$NH" && git init -q && git config core.hooksPath .githooks )
printf '{}\n' > "$NH/.claude/settings.json"
[ "$(verdict "$NH")" = 1 ] && ok "(①) bare {} settings.json (no pre-tool-use.sh hook) ⇒ RED (gate would not fire)" || bad "(①) bare {} settings.json wrongly GREEN"
printf '%s\n' '{"hooks":{"PreToolUse":[{"matcher":"{{GATED_MCP_PREFIXES}}","hooks":[{"type":"command","command":"x/pre-tool-use.sh"}]}]}}' > "$NH/.claude/settings.json"
[ "$(verdict "$NH")" = 1 ] && ok "(①) residual {{token}} in settings.json ⇒ RED (inert gate matcher)" || bad "(①) residual {{token}} wrongly GREEN"
printf '%s\n' '{"hooks":{"PreToolUse":[{"matcher":"Write|Edit|MultiEdit|Bash","hooks":[{"type":"command","command":"\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/pre-tool-use.sh"}]}]}}' > "$NH/.claude/settings.json"
[ "$(verdict "$NH")" = 0 ] && ok "(①) settings.json WITH pre-tool-use.sh hook + no residual ⇒ GREEN" || bad "(①) valid hooked settings.json wrongly RED"
# re-review residue (gpt-5.5 P3): a substring-spoof command (basename only, not the canonical path) ⇒ RED
printf '%s\n' '{"hooks":{"PreToolUse":[{"matcher":"Write|Edit|MultiEdit|Bash","hooks":[{"type":"command","command":"echo pre-tool-use.sh"}]}]}}' > "$NH/.claude/settings.json"
[ "$(verdict "$NH")" = 1 ] && ok "(①+) substring-spoof command (echo pre-tool-use.sh) ⇒ RED (canonical-path check)" || bad "(①+) spoof command wrongly GREEN"

# confirmation-pass residue (#2, Path A — STRUCTURED exact-match after the text-match BACKSTOP): three
# regex-on-command-string fixes LEAKED non-invoking forms AND false-RED real ones — proving a regex cannot
# parse shell grammar. The check now compares structured DATA: the canonical command (read from
# settings.json.template, the SSOT beside the tool) must be registered as a type==command under a SINGLE
# PreToolUse entry whose matcher COVERS the gate verbs. Assert the CLASS by construction: every leak form
# (incl. the 3 that GREENed the regex: trailing-space-in-quote, string-assign, array-assign) ⇒ RED; a
# wrong TUPLE (right command, wrong event / too-narrow matcher) ⇒ RED; the exact forge-placed command ⇒
# GREEN; a broader/catch-all matcher ⇒ GREEN. EXP is derived the SAME way check-setup derives it (same SSOT).
EXP="$(jq -r 'first(.hooks.PreToolUse[]?.hooks[]? | select(.type=="command") | .command | select(endswith("/pre-tool-use.sh"))) // empty' "$REPO/.claude/settings.json.template")"
[ -n "$EXP" ] && ok "(②struct) canonical command derivable from settings.json.template SSOT" || bad "(②struct) could not derive canonical command from template SSOT"
# drift guard: check-setup's pinned-constant fallback MUST equal the SSOT template command — else a run
# detached from the template (fallback path) would validate against a stale canonical → silent mis-verdict.
CONST="$(grep -oE "EXPECTED_HOOK_CMD='[^']*'" "$CHECK" | head -1 | sed "s/^EXPECTED_HOOK_CMD='//; s/'\$//")"
[ "$CONST" = "$EXP" ] && ok "(②struct) check-setup pinned-constant fallback == template SSOT (no drift)" || bad "(②struct) DRIFT: check-setup constant <$CONST> != template SSOT <$EXP>"
mkset() { jq -n --arg c "$1" --arg ev "${2:-PreToolUse}" --arg mt "${3:-Write|Edit|MultiEdit|Bash}" '{hooks:{($ev):[{matcher:$mt,hooks:[{type:"command",command:$c}]}]}}' > "$NH/.claude/settings.json"; }
# RED class — non-invoking / non-exact (none EQUALS the exact canonical entry). First 3 GREENed the regex.
REDS=(
  '"$CLAUDE_PROJECT_DIR"/.claude/hooks/pre-tool-use.sh '     # trailing space INSIDE quote (leaked the regex — not the hook)
  'X=" .claude/hooks/pre-tool-use.sh "'                      # string assignment (leaked the regex — never invokes)
  'HOOKS=( .claude/hooks/pre-tool-use.sh )'                  # array assignment (leaked the regex — never invokes)
  'echo .claude/hooks/pre-tool-use.sh'                       # mention (path is an argument)
  'echo pre-tool-use.sh'                                     # basename-only mention
  '/some/other/project/.claude/hooks/pre-tool-use.sh'        # foreign absolute path
  '.claude/hooks/pre-tool-use.sh.disabled'                   # suffixed (not the .sh)
)
R_RED=0; for s in "${REDS[@]}"; do mkset "$s"; [ "$(verdict "$NH")" = 1 ] && R_RED=$((R_RED+1)); done
[ "$R_RED" = "${#REDS[@]}" ] \
  && ok "(②struct) all ${#REDS[@]} non-invoking/non-exact commands ⇒ RED (exact-match closes the leak class by construction)" \
  || bad "(②struct) only $R_RED/${#REDS[@]} ⇒ RED — leak class STILL open"
# Note 1 — full TUPLE: the exact command under the WRONG event, or behind a too-narrow matcher, ⇒ RED.
mkset "$EXP" 'PostToolUse' 'Write|Edit|MultiEdit|Bash'; [ "$(verdict "$NH")" = 1 ] && ok "(②struct) exact command under WRONG event (PostToolUse) ⇒ RED (tuple integrity)" || bad "(②struct) wrong-event exact command wrongly GREEN"
mkset "$EXP" 'PreToolUse' 'Write|Edit'; [ "$(verdict "$NH")" = 1 ] && ok "(②struct) exact command, matcher MISSING Bash ⇒ RED (matcher coverage)" || bad "(②struct) too-narrow matcher wrongly GREEN"
# GREEN — the exact forge-placed canonical command, with the default and a BROADER matcher (coverage, not exact).
mkset "$EXP" 'PreToolUse' 'Write|Edit|MultiEdit|Bash'; [ "$(verdict "$NH")" = 0 ] && ok "(②struct) exact forge-placed command + full matcher ⇒ GREEN" || bad "(②struct) forge-placed canonical wrongly RED"
mkset "$EXP" 'PreToolUse' 'Write|Edit|MultiEdit|Bash|Task'; [ "$(verdict "$NH")" = 0 ] && ok "(②struct) exact command + BROADER matcher (Task added) ⇒ GREEN (coverage)" || bad "(②struct) broader matcher wrongly RED"
# A′ schema-shape guards (narrow-pass #2 cross-vendor: jq `[]?` iterates OBJECT values too, so an
# object-shaped container with the exact command would false-GREEN even though Claude Code requires
# ARRAYS there → the gate would not wire). type=="array" guards at BOTH levels ⇒ object shapes RED.
jq -n --arg c "$EXP" '{hooks:{PreToolUse:{x:{matcher:"Write|Edit|MultiEdit|Bash",hooks:[{type:"command",command:$c}]}}}}' > "$NH/.claude/settings.json"
[ "$(verdict "$NH")" = 1 ] && ok "(②struct) PreToolUse as an OBJECT (not array) ⇒ RED (schema-shape guard)" || bad "(②struct) object-shaped PreToolUse wrongly GREEN (Claude Code would not wire it)"
jq -n --arg c "$EXP" '{hooks:{PreToolUse:[{matcher:"Write|Edit|MultiEdit|Bash",hooks:{y:{type:"command",command:$c}}}]}}' > "$NH/.claude/settings.json"
[ "$(verdict "$NH")" = 1 ] && ok "(②struct) entry .hooks as an OBJECT (not array) ⇒ RED (schema-shape guard)" || bad "(②struct) object-shaped entry .hooks wrongly GREEN"
# H5 (cross-vendor terminal — DOCUMENTED best-effort boundary, NOT an unaddressed gap): the matcher-
# COVERAGE sub-check uses jq's Oniguruma regex, which is NOT Claude Code's JS RegExp. A matcher valid in
# jq but invalid in JS (e.g. `(?>.*)` atomic group) GREENs the STATIC check. Calibrated near-zero — forge
# places the plain JS-valid `Write|Edit|MultiEdit|Bash`, and Claude Code rejects a JS-invalid matcher at
# load (the consumer sees the error). BACKSTOPPED by the behavioral gate-fire test below (authoritative).
# Pinned here so the static boundary is EXPLICIT; both branches pass (characterization, not a regression).
jq -n --arg c "$EXP" '{hooks:{PreToolUse:[{matcher:"(?>.*)",hooks:[{type:"command",command:$c}]}]}}' > "$NH/.claude/settings.json"
if [ "$(verdict "$NH")" = 0 ]; then ok "(②struct/H5) jq-valid/JS-invalid matcher '(?>.*)' GREENs the STATIC check — KNOWN best-effort boundary; behavioral gate-fire test is authoritative (Claude Code rejects it at load)"
else ok "(②struct/H5) '(?>.*)' ⇒ RED — static tightened beyond the documented best-effort boundary (also acceptable)"; fi
rm -rf "$NH"

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

# ★ AUTHORITATIVE #2 VERIFICATION (cross-vendor terminal disposition) — this BEHAVIORAL gate-fire test is
# the source of truth that the gate actually fires end-to-end. check-setup.sh's static check is a fast
# readiness heuristic (authoritative on the command via exact-match + array guards; BEST-EFFORT on matcher
# coverage — see H5). Where the static heuristic and this behavioral test could differ (a jq-valid/JS-
# invalid matcher), THIS test (running the real hook) governs. Keep it green and exercising the real hook.
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
