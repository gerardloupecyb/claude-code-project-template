#!/usr/bin/env bash
# test-gate-config.sh — oracle suite for the data-driven gate (Plan 22-02, AC-2-1..AC-2-5)
# Re-runnable, zero-network. Tests pre-tool-use.sh / pre-mcp-gate.sh / .githooks/pre-commit / render
# against Project, greenfield, gutted (silent-disable), and corrupt configs.
# Usage: scripts/forge/test-gate-config.sh   (exit 0 = all PASS, 1 = a FAIL)
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PTU="$REPO_ROOT/.claude/hooks/pre-tool-use.sh"
MCP="$REPO_ROOT/.claude/hooks/pre-mcp-gate.sh"
PRECOMMIT="$REPO_ROOT/.githooks/pre-commit"
RENDER="$REPO_ROOT/scripts/forge/render-skill-gate.sh"
CONFIG="$REPO_ROOT/.claude/gate.config.json"
SKILLGATE="$REPO_ROOT/.claude/rules/skill-gate.md"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; }
# run hook: $1=json $2=projectdir [$3=hook path, default pre-tool-use.sh] -> sets RC, OUT, ERR
hook() { local h="${3:-$PTU}"; OUT=$(echo "$1" | CLAUDE_PROJECT_DIR="$2" bash "$h" 2>/tmp/gt.err); RC=$?; ERR=$(cat /tmp/gt.err 2>/dev/null || true); }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
mk() { mkdir -p "$WORK/$1/.claude"; }
FORGE="$WORK/proj";   mk proj;   cp "$CONFIG" "$FORGE/.claude/gate.config.json"
GREEN="$WORK/green";   mk green
CORR="$WORK/corrupt";  mk corrupt; echo "{ broken json" > "$CORR/.claude/gate.config.json"
# greenfield: EMPTY protected_domains, dep_ecosystems=python kept, gated_mcp kept (independence test)
jq '.protected_domains = [] | .dep_ecosystems = {"python": .dep_ecosystems.python}' "$CONFIG" > "$GREEN/.claude/gate.config.json"
# gutted: valid JSON but dep_ecosystems + gated_mcp REMOVED entirely (silent-disable attempt)
GUT="$WORK/gutted"; mk gutted
jq 'del(.dep_ecosystems) | del(.gated_mcp) | .protected_domains = []' "$CONFIG" > "$GUT/.claude/gate.config.json"
# empty-mcp: gated_mcp=[] but dep_ecosystems kept
EMPTYMCP="$WORK/emptymcp"; mk emptymcp
jq '.gated_mcp = []' "$CONFIG" > "$EMPTYMCP/.claude/gate.config.json"
# marker-blank: first gated_mcp entry has marker="" (valid shape, but inert)
BLANKM="$WORK/blankmarker"; mk blankmarker
jq '.gated_mcp[0].marker = ""' "$CONFIG" > "$BLANKM/.claude/gate.config.json"
# WRONG-SHAPE fixtures (chokepoint must fail-open OBSERVABLY, never silently bypass)
WS_MV="$WORK/ws-mv"; mk ws-mv; jq '.mutation_verbs=[]' "$CONFIG" > "$WS_MV/.claude/gate.config.json"
WS_FP="$WORK/ws-fp"; mk ws-fp; jq '.protected_domains[0].file_patterns=["a"]' "$CONFIG" > "$WS_FP/.claude/gate.config.json"
WS_DE="$WORK/ws-de"; mk ws-de; jq '.dep_ecosystems.node=""' "$CONFIG" > "$WS_DE/.claude/gate.config.json"
WS_GM="$WORK/ws-gm"; mk ws-gm; jq '.gated_mcp="abc"' "$CONFIG" > "$WS_GM/.claude/gate.config.json"
WS_RE="$WORK/ws-re"; mk ws-re; jq '.protected_domains[0].file_patterns="["' "$CONFIG" > "$WS_RE/.claude/gate.config.json"

PRE="mcp__"

echo "── AC-2-1 — config split (jq valid; hooks source ONLY gate.config.json) ──"
jq -e . "$CONFIG" >/dev/null 2>&1 && ok "gate.config.json valid JSON" || bad "gate.config.json invalid"
jq -e . "$REPO_ROOT/.claude/forge.config.json" >/dev/null 2>&1 && ok "forge.config.json valid JSON" || bad "forge.config.json invalid"
grep -lq 'forge\.config\.json' "$PTU" "$MCP" "$PRECOMMIT" 2>/dev/null && bad "a hook references forge.config.json" || ok "no hook references forge.config.json"
DOCKEYS='memory_backend|rag_collections|model_router|compliance_frameworks|doc_language|canonical_files'
grep -Eq "$DOCKEYS" "$PTU" "$MCP" "$PRECOMMIT" 2>/dev/null && bad "doc-rendering keys in a hook's parse surface" || ok "doc-rendering keys absent from hooks"

echo "── AC-2-2a — zero domain literals; per-domain block + marker-lift matrix ──"
for h in "$PTU" "$MCP"; do
  lit=$(grep -nE '\b(azure|n8n|ghl)\b' "$h" | grep -vE '^[0-9]+:[[:space:]]*#' | grep -vE 'gate\.config|skill-gate\.md')
  [ -z "$lit" ] && ok "no domain literals in $(basename "$h")" || { bad "domain literals in $(basename "$h")"; echo "$lit"; }
done
# azure
hook '{"tool_name":"Write","tool_input":{"file_path":"x.ps1"}}' "$FORGE"; [ "$RC" = 2 ] && ok "azure: *.ps1 blocked" || bad "azure *.ps1 RC=$RC"
mkdir -p "$FORGE/.skill-locks"; touch "$FORGE/.skill-locks/azure"
hook '{"tool_name":"Write","tool_input":{"file_path":"x.ps1"}}' "$FORGE"; [ "$RC" = 0 ] && ok "azure: *.ps1 +marker allowed" || bad "azure +marker RC=$RC"
rm -f "$FORGE/.skill-locks/azure"
# n8n
hook '{"tool_name":"Write","tool_input":{"file_path":"a/n8n/wf.json"}}' "$FORGE"; [ "$RC" = 2 ] && ok "n8n: n8n/ blocked" || bad "n8n RC=$RC"
touch "$FORGE/.skill-locks/n8n"
hook '{"tool_name":"Write","tool_input":{"file_path":"a/n8n/wf.json"}}' "$FORGE"; [ "$RC" = 0 ] && ok "n8n: n8n/ +marker allowed" || bad "n8n +marker RC=$RC"
rm -f "$FORGE/.skill-locks/n8n"
# ghl
hook '{"tool_name":"Write","tool_input":{"file_path":"ghl/c.js"}}' "$FORGE"; [ "$RC" = 2 ] && ok "ghl: ghl/ blocked" || bad "ghl RC=$RC"
touch "$FORGE/.skill-locks/ghl"
hook '{"tool_name":"Write","tool_input":{"file_path":"ghl/c.js"}}' "$FORGE"; [ "$RC" = 0 ] && ok "ghl: ghl/ +marker allowed" || bad "ghl +marker RC=$RC"
rm -f "$FORGE/.skill-locks/ghl"
# non-domain allowed
hook '{"tool_name":"Write","tool_input":{"file_path":"src/app.py"}}' "$FORGE"; [ "$RC" = 0 ] && ok "non-domain *.py allowed" || bad "*.py RC=$RC"
hook '{"tool_name":"Write","tool_input":{"file_path":"scripts/setup.sh"}}' "$FORGE"; [ "$RC" = 0 ] && ok "scripts/*.sh NOT azure-gated" || bad "scripts/*.sh RC=$RC"

echo "── AC-2-2b — MCP gate: mutation blocked, read allowed, marker lifts, dev not gated ──"
hook "{\"tool_name\":\"${PRE}n8n-mcp__n8n_create_workflow\"}" "$FORGE" "$MCP"; [ "$RC" = 2 ] && ok "n8n-mcp create blocked" || bad "n8n-mcp create RC=$RC"
hook "{\"tool_name\":\"${PRE}n8n-mcp__n8n_get_workflow\"}" "$FORGE" "$MCP"; [ "$RC" = 0 ] && ok "n8n-mcp get (read) allowed" || bad "n8n-mcp get RC=$RC"
hook "{\"tool_name\":\"${PRE}prod-ghl-care-mcp__contacts_update\"}" "$FORGE" "$MCP"; [ "$RC" = 2 ] && ok "prod-ghl-care-mcp update blocked" || bad "ghl-care RC=$RC"
hook "{\"tool_name\":\"${PRE}n8n-dev-mcp__n8n_create_workflow\"}" "$FORGE" "$MCP"; [ "$RC" = 0 ] && ok "n8n-DEV-mcp create not gated" || bad "n8n-dev RC=$RC"
touch "$FORGE/.skill-locks/n8n"
hook "{\"tool_name\":\"${PRE}n8n-mcp__n8n_create_workflow\"}" "$FORGE" "$MCP"; [ "$RC" = 0 ] && ok "n8n-mcp create +marker allowed" || bad "n8n-mcp +marker RC=$RC"
rm -f "$FORGE/.skill-locks/n8n"

echo "── AC-2-2c — SCAG one-shot consumption + greenfield independence ──"
hook '{"tool_name":"Bash","tool_input":{"command":"pip install r"}}' "$FORGE"; [ "$RC" = 2 ] && ok "SCAG: pip blocked (no marker)" || bad "SCAG pip RC=$RC"
touch "$FORGE/.skill-locks/scag-approved"
hook '{"tool_name":"Bash","tool_input":{"command":"pip install r"}}' "$FORGE"; [ "$RC" = 0 ] && ok "SCAG: pip allowed (marker present)" || bad "SCAG allow RC=$RC"
[ ! -f "$FORGE/.skill-locks/scag-approved" ] && ok "SCAG: marker consumed after allow (one-shot)" || bad "SCAG marker NOT consumed"
hook '{"tool_name":"Bash","tool_input":{"command":"pip install r"}}' "$FORGE"; [ "$RC" = 2 ] && ok "SCAG: re-gated after consumption" || bad "SCAG re-gate RC=$RC"
# greenfield: empty protected_domains -> skill-gate off BUT SCAG + MCP stay on
hook '{"tool_name":"Write","tool_input":{"file_path":"x.ps1"}}' "$GREEN"; [ "$RC" = 0 ] && ok "greenfield: *.ps1 allowed (no domains)" || bad "greenfield *.ps1 RC=$RC"
hook '{"tool_name":"Bash","tool_input":{"command":"pip install r"}}' "$GREEN"; [ "$RC" = 2 ] && ok "greenfield: pip STILL blocked (SCAG independent)" || bad "greenfield pip RC=$RC"
hook "{\"tool_name\":\"${PRE}n8n-mcp__n8n_create_workflow\"}" "$GREEN" "$MCP"; [ "$RC" = 2 ] && ok "greenfield: prod-MCP STILL gated" || bad "greenfield mcp RC=$RC"

echo "── AC-2-2d — silent-disable PREVENTION (gutted/empty configs never silently off) ──"
# dep_ecosystems removed entirely -> SCAG falls back to built-in default, STILL fires
hook '{"tool_name":"Bash","tool_input":{"command":"pip install r"}}' "$GUT"; [ "$RC" = 2 ] && ok "gutted dep_ecosystems: pip STILL blocked (fallback)" || bad "gutted SCAG SILENTLY DISABLED RC=$RC"
# gated_mcp=[] -> mutation allowed but OBSERVABLE warning (not silent)
hook "{\"tool_name\":\"${PRE}n8n-mcp__n8n_create_workflow\"}" "$EMPTYMCP" "$MCP"
{ [ "$RC" = 0 ] && echo "$ERR" | grep -q 'INERT'; } && ok "empty gated_mcp: mutation allowed but warns (observable)" || bad "empty gated_mcp silent RC=$RC err='$ERR'"
# matched entry marker="" -> allowed but OBSERVABLE warning
hook "{\"tool_name\":\"${PRE}n8n-mcp__n8n_create_workflow\"}" "$BLANKM" "$MCP"
{ [ "$RC" = 0 ] && echo "$ERR" | grep -q 'INERT'; } && ok "blank marker: mutation allowed but warns (observable)" || bad "blank marker silent RC=$RC err='$ERR'"

echo "── AC-2-7 — runtime TRUST: chokepoint removed; floor + D2 fail-open OBSERVABLE; always-on NEVER silent ──"
# Option-3: the per-call deep-validation chokepoint is GONE from the runtime hot path (it lives at
# write-time in validate-gate-config.sh now). The runtime keeps only the O(1) A2 floor + D2 protections.
grep -q 'gate_config_shape_ok' "$PTU" && bad "pre-tool-use STILL calls gate_config_shape_ok (chokepoint not removed)" || ok "pre-tool-use: per-call chokepoint REMOVED"
grep -q 'gate_config_shape_ok' "$MCP" && bad "pre-mcp-gate STILL calls gate_config_shape_ok" || ok "pre-mcp-gate: per-call chokepoint REMOVED"
{ grep -q 'gate_runtime_floor_ok' "$PTU" && grep -q 'gate_runtime_floor_ok' "$MCP"; } && ok "both runtime hooks use the A2 gate_runtime_floor_ok" || bad "a runtime hook is missing gate_runtime_floor_ok"
# FLOOR-level wrong-shape (array-type miss) → OBSERVABLE fail-open, never a silent jq no-match
WS_PD="$WORK/ws-pd"; mk ws-pd; jq '.protected_domains="x"' "$CONFIG" > "$WS_PD/.claude/gate.config.json"
hook '{"tool_name":"Write","tool_input":{"file_path":"x.ps1"}}' "$WS_PD"
{ [ "$RC" = 0 ] && echo "$OUT$ERR" | grep -q 'FAIL-OPEN'; } && ok "protected_domains string → floor fail-open observable" || bad "protected_domains string RC=$RC"
hook "{\"tool_name\":\"${PRE}n8n-mcp__n8n_create_workflow\"}" "$WS_MV" "$MCP"
{ [ "$RC" = 0 ] && echo "$OUT$ERR" | grep -q 'FAIL-OPEN'; } && ok "mutation_verbs array → MCP floor fail-open observable" || bad "mutation_verbs array RC=$RC err='$ERR'"
hook "{\"tool_name\":\"${PRE}n8n-mcp__n8n_create_workflow\"}" "$WS_GM" "$MCP"
{ [ "$RC" = 0 ] && echo "$OUT$ERR" | grep -q 'FAIL-OPEN'; } && ok "gated_mcp string → MCP floor fail-open observable" || bad "gated_mcp string RC=$RC"
# D2(a): a dirty-tree NON-COMPILING file_patterns → domain grep rc>=2 → fail-open OBSERVABLE (not silent no-match)
hook '{"tool_name":"Write","tool_input":{"file_path":"x.ps1"}}' "$WS_RE"
{ [ "$RC" = 0 ] && echo "$OUT$ERR" | grep -q 'FAIL-OPEN'; } && ok "D2a: uncompilable file_patterns → domain grep fail-open observable" || bad "D2a uncompilable file_patterns RC=$RC"
# D2(b): a vacuous ALWAYS-ON gate is NEVER silently disabled — it falls back to the built-in default
#        (gate STAYS ON) with an OBSERVABLE gate_degraded note. This is the silent-disable the runtime fixes.
MVBLANK="$WORK/mv-blank"; mk mv-blank; jq '.mutation_verbs=" "' "$CONFIG" > "$MVBLANK/.claude/gate.config.json"
hook "{\"tool_name\":\"${PRE}n8n-mcp__n8n_create_workflow\"}" "$MVBLANK" "$MCP"
{ [ "$RC" = 2 ] && echo "$OUT$ERR" | grep -q 'DEGRADED'; } && ok "D2b: blank mutation_verbs → MCP gate STILL fires (default) + DEGRADED observable" || bad "D2b blank mutation_verbs RC=$RC (expect BLOCK + degraded)"
DEVAC="$WORK/de-vac"; mk de-vac; jq '.dep_ecosystems.python="   "' "$CONFIG" > "$DEVAC/.claude/gate.config.json"
hook '{"tool_name":"Bash","tool_input":{"command":"pip install r"}}' "$DEVAC"
{ [ "$RC" = 2 ] && echo "$OUT$ERR" | grep -q 'DEGRADED'; } && ok "SCAG: vacuous dep member → SCAG STILL fires (default) + DEGRADED observable" || bad "SCAG vacuous member RC=$RC (expect BLOCK + degraded)"

echo "── AC-2-3 — observable fail-open; audit content; never fail-closed ──"
hook '{"tool_name":"Write","tool_input":{"file_path":"x.ps1"}}' "$CORR"
{ [ "$RC" = 0 ] && echo "$OUT" | grep -q 'FAIL-OPEN'; } && ok "pre-tool-use corrupt → exit0 + loud warning" || bad "pre-tool-use corrupt RC=$RC"
hook "{\"tool_name\":\"${PRE}n8n-mcp__n8n_create_workflow\"}" "$CORR" "$MCP"; [ "$RC" = 0 ] && ok "pre-mcp-gate corrupt → exit0 (fail-open)" || bad "pre-mcp corrupt RC=$RC"
# audit log content under a WRITABLE HOME
WH="$WORK/wh-home"; mkdir -p "$WH"
OUT=$(echo '{"tool_name":"Write","tool_input":{"file_path":"x.ps1"}}' | HOME="$WH" CLAUDE_PROJECT_DIR="$CORR" bash "$PTU" 2>/dev/null)
{ [ -f "$WH/.claude/gate-failopen.log" ] && grep -q 'pre-tool-use fail-open' "$WH/.claude/gate-failopen.log"; } && ok "fail-open writes audit-log line" || bad "no audit-log line written"
# read-only HOME: still exit0 AND stdout warning still present
RO="$WORK/ro-home"; mkdir -p "$RO"; chmod 555 "$RO"
OUT=$(echo '{"tool_name":"Write","tool_input":{"file_path":"x.ps1"}}' | HOME="$RO" CLAUDE_PROJECT_DIR="$CORR" bash "$PTU" 2>/dev/null); RC=$?
chmod 755 "$RO"
{ [ "$RC" = 0 ] && echo "$OUT" | grep -q 'FAIL-OPEN'; } && ok "read-only HOME: exit0 + warning still emitted" || bad "read-only HOME RC=$RC out='$OUT'"

echo "── AC-2-4 — pre-commit per-language linter gating (end-to-end temp repo) ──"
pc() { # $1=config-jq-filter $2=desc  -> runs pre-commit on a temp repo staging app.py + script.ps1
  local T; T=$(mktemp -d); ( cd "$T" && git init -q && git config user.email t@t.t && git config user.name t
    mkdir -p .claude scripts/forge .claude/hooks/lib
    cp "$REPO_ROOT/.gitleaks.toml" .gitleaks.toml 2>/dev/null || true
    cp "$REPO_ROOT/scripts/PSScriptAnalyzerSettings.psd1" scripts/ 2>/dev/null || true
    cp "$REPO_ROOT/.claude/hooks/lib/gate-config.sh" .claude/hooks/lib/ 2>/dev/null || true
    cp "$REPO_ROOT/scripts/forge/validate-gate-config.sh" scripts/forge/ 2>/dev/null || true
    printf 'print("hi")\n' > app.py; printf 'Write-Output "hi"\n' > script.ps1
    jq "$1" "$CONFIG" > .claude/gate.config.json
    git add -A 2>/dev/null
    bash "$PRECOMMIT" > /tmp/pc.out 2>/tmp/pc.err ) ; PCRC=$?; PCOUT=$(cat /tmp/pc.out); PCERR=$(cat /tmp/pc.err)
  rm -rf "$T"
}
pc '.' 'proj'
echo "$PCOUT" | grep -qi 'PSScriptAnalyzer' && ok "language incl powershell → PSA invoked" || bad "PSA not invoked for proj config"
echo "$PCOUT" | grep -qi 'semgrep' && ok "semgrep invoked (universal)" || bad "semgrep missing"
{ echo "$PCOUT" | grep 'Gate config (staged blob)' | grep -qi 'OK'; } && ok "valid staged gate.config.json → staged-blob validator OK (no false-block)" || bad "staged-blob validator did not pass a valid config"
pc '.language = ["python"]' 'python-only'
echo "$PCOUT" | grep -qi 'PSScriptAnalyzer' && bad "PSA invoked despite language=python" || ok "language=python → PSA NOT invoked"
echo "$PCERR$PCOUT" | grep -qi 'PowerShell files staged but' && ok "language=python + .ps1 staged → observable WARN" || bad "no PSA-skip warning"
echo "$PCOUT" | grep -qi 'gitleaks' && ok "gitleaks runs (universal) under python-only" || bad "gitleaks missing under python-only"
# Option-3: a wrong-shape (empty code_extensions element) STAGED gate.config.json is REJECTED at write-time
# by the staged-blob validator wired into pre-commit (R2) → the COMMIT is BLOCKED. Deep validation moved off
# the SAST-surface read (which now only light-guards valid JSON) and onto validate-gate-config.sh.
pc '.code_extensions=["js",""]' 'wrong-shape'
{ [ "$PCRC" != 0 ] && echo "$PCOUT" | grep 'Gate config (staged blob)' | grep -qi 'BLOCKED'; } && ok "pre-commit: wrong-shape staged config → BLOCKED by validator" || bad "pre-commit wrong-shape NOT blocked (PCRC=$PCRC)"

echo "── AC-2-5 — single source: render --check, markers≡config, mutation round-trip ──"
bash "$RENDER" --check >/dev/null 2>&1 && ok "render --check: in sync (no drift)" || bad "render --check: DRIFT"
CFG_M=$(jq -r '.protected_domains[].marker' "$CONFIG" | sort -u | tr '\n' ' ')
REND_M=$(awk '/BEGIN GENERATED: domain-routing/{f=1;next}/END GENERATED: domain-routing/{f=0}f' "$SKILLGATE" \
  | grep -oE '\.skill-locks/[a-z0-9_-]+' | sed 's#.*/##' | sort -u | tr '\n' ' ')
[ "$CFG_M" = "$REND_M" ] && ok "rendered markers ≡ config markers ($CFG_M)" || bad "marker mismatch cfg='$CFG_M' rend='$REND_M'"
# mutation round-trip: add a synthetic domain, render, assert it appears, --check passes
RT="$WORK/rt"; mkdir -p "$RT"
jq '.protected_domains += [{"name":"testdom","marker":"testdom","label":"TestDom","triggers_doc":"`testdom/`","file_patterns":"testdom/","command_patterns":"","required_skills":"test-skill","lessons_domain":"test","unlock":"touch .skill-locks/testdom"}]' "$CONFIG" > "$RT/gate.config.json"
cp "$SKILLGATE" "$RT/skill-gate.md"
bash "$RENDER" "$RT/gate.config.json" "$RT/skill-gate.md" >/dev/null 2>&1
grep -q 'TestDom' "$RT/skill-gate.md" && ok "round-trip: new domain rendered into skill-gate.md" || bad "round-trip: new domain NOT rendered"
bash "$RENDER" --check "$RT/gate.config.json" "$RT/skill-gate.md" >/dev/null 2>&1 && ok "round-trip: --check passes after re-render" || bad "round-trip: --check failed post-render"
# deletion of a marker is detected (not silently passed through)
sed '/BEGIN GENERATED: mcp-gating/d' "$SKILLGATE" > "$RT/sg-nomarker.md"
cp "$CONFIG" "$RT/cfg2.json"
bash "$RENDER" --check "$RT/cfg2.json" "$RT/sg-nomarker.md" >/dev/null 2>&1 && bad "deleted mcp-gating marker NOT detected" || ok "deleted marker detected (render refuses)"

echo "── AC-2-6 — WRITE-TIME validator: shape/regex/empty REJECTED, R3a vacuity, R3c mandatory, R3b non-goal ──"
VALIDATOR="$REPO_ROOT/scripts/forge/validate-gate-config.sh"
# vrej <jq-filter> <desc>: validator MUST reject (exit != 0).  vacc <jq-filter> <desc>: MUST accept (exit 0).
vrej() { local f; f=$(mktemp); jq "$1" "$CONFIG" > "$f" 2>/dev/null; bash "$VALIDATOR" "$f" >/dev/null 2>&1 && bad "validator should REJECT: $2" || ok "validator rejects: $2"; rm -f "$f"; }
vacc() { local f; f=$(mktemp); jq "$1" "$CONFIG" > "$f" 2>/dev/null; bash "$VALIDATOR" "$f" >/dev/null 2>&1 && ok "validator accepts: $2" || bad "validator should ACCEPT: $2"; rm -f "$f"; }
# the committed worked-example config PASSES (AC-2-6 oracle)
bash "$VALIDATOR" "$CONFIG" >/dev/null 2>&1 && ok "worked-example config → validator exit 0" || bad "worked-example config REJECTED"
# R1: absent file + invalid JSON
bash "$VALIDATOR" "$WORK/does-not-exist.json" >/dev/null 2>&1 && bad "absent file accepted" || ok "validator rejects: absent file"
{ BJ=$(mktemp); printf '{bad json' > "$BJ"; bash "$VALIDATOR" "$BJ" >/dev/null 2>&1 && bad "invalid JSON accepted" || ok "validator rejects: invalid JSON"; rm -f "$BJ"; }
# R2: shape / type / empty-element (RE-HOMED from the old runtime wrong-shape section — now write-time)
vrej '.protected_domains="x"'                     "R2 protected_domains not array"
vrej '.mutation_verbs=[]'                          "R2 mutation_verbs not string"
vrej '.gated_mcp="abc"'                            "R2 gated_mcp not array"
vrej '.protected_domains[0].file_patterns=["a"]'   "R2 file_patterns not string (per-element)"
vrej '.dep_ecosystems.node=""'                     "R2 dep_ecosystems empty-value"
vrej '.code_extensions=["js",""]'                  "R2 code_extensions empty element"
vrej '.protected_domains[0].file_patterns="["'     "regex-compilability: uncompilable file_patterns"
# R3a vacuity (blank-after-trim OR pure-non-word — incl. a COMPILABLE no-op like [ ])
vrej '.mutation_verbs=" "'                          "R3a mutation_verbs blank-after-trim"
vrej '.mutation_verbs="[ ]"'                        "R3a mutation_verbs compilable-but-pure-non-word"
vrej '.dep_ecosystems.python="   "'                 "R3a dep_ecosystems value blank"
vrej '.protected_domains[0].file_patterns="   "'    "R3a protected_domains trigger blank"
# R3c mandatory-field presence (a deleted marker must NOT pass shape then runtime-fail-open)
vrej '.gated_mcp[0] |= del(.marker)'                "R3c gated_mcp deleted marker"
vrej '.gated_mcp[0] |= del(.server_prefix)'         "R3c gated_mcp missing server_prefix"
vrej '.protected_domains[0] |= del(.marker)'        "R3c protected_domains missing marker"
vrej '.protected_domains[0] |= (.file_patterns="" | .command_patterns="")' "R3c protected_domains no operative trigger"
# R3b documented NON-GOAL: a valid word matching no real verb is undecidable at write-time → ACCEPTED
vacc '.mutation_verbs="zzz_no_such_verb"'           "R3b non-goal (mutation_verbs=zzz) accepted (documented)"
# source-not-fork: gate_config_shape_ok is SOURCED, not re-implemented (AC-2-6)
[ "$(grep -cE '^[[:space:]]*gate_config_shape_ok ' "$VALIDATOR")" -eq 1 ] && ok "validator CALLS gate_config_shape_ok once (no logic fork)" || bad "validator gate_config_shape_ok call count != 1"
grep -qE 'gate_config_shape_ok[[:space:]]*\(\)[[:space:]]*\{' "$VALIDATOR" && bad "validator RE-IMPLEMENTS gate_config_shape_ok" || ok "validator does not re-implement gate_config_shape_ok"

echo "── AC-2-6 staged-blob (Gemini F3): malformed STAGED blob + clean worktree → pre-commit BLOCKS ──"
f3() { local T; T=$(mktemp -d); ( cd "$T" && git init -q && git config user.email t@t.t && git config user.name t
    mkdir -p .claude scripts/forge .claude/hooks/lib
    cp "$REPO_ROOT/.claude/hooks/lib/gate-config.sh" .claude/hooks/lib/
    cp "$REPO_ROOT/scripts/forge/validate-gate-config.sh" scripts/forge/
    cp "$REPO_ROOT/.gitleaks.toml" .gitleaks.toml 2>/dev/null || true
    cp "$CONFIG" .claude/gate.config.json; git add -A >/dev/null 2>&1; git commit -qm init
    jq 'del(.gated_mcp[0].marker)' "$CONFIG" > .claude/gate.config.json; git add .claude/gate.config.json   # stage BAD blob
    cp "$CONFIG" .claude/gate.config.json                                                                    # restore GOOD worktree
    bash "$PRECOMMIT" > /tmp/f3.out 2>/tmp/f3.err ) ; F3RC=$?; F3OUT=$(cat /tmp/f3.out); rm -rf "$T"; }
f3
{ [ "$F3RC" != 0 ] && echo "$F3OUT" | grep 'Gate config (staged blob)' | grep -qi 'BLOCKED'; } && ok "F3: staged BAD + worktree GOOD → pre-commit BLOCKS (validates the blob, not the worktree)" || bad "F3 NOT blocked (F3RC=$F3RC) — worktree-bypass regression"

echo ""
echo "════ RESULT: $PASS passed, $FAIL failed ════"
[ "$FAIL" -eq 0 ]
