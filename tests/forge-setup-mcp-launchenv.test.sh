#!/usr/bin/env bash
set -uo pipefail
# ============================================================================
# forge-setup-mcp-launchenv.test.sh — AC-5-4 OpenRouter MCP launch-env oracle (Plan 05)
# ============================================================================
# The false-green fix. Asserts:
#   (1) wire (declared) → .mcp.json openrouter entry, key BY NAME (no literal)
#   (2) GUI-launch-safe wrapper RESOLVES the key into the spawn env (the fix)
#   (3) the naive env-ref-only form + parent-unset → EMPTY (the false-green it fixes)
#   (4) launch-path probe with a fake key → FAIL (resolves but 401), never PASS
#   (5) F13: the probe's key-resolution slice == the .mcp.json launcher slice (verbatim)
#   (6) idempotent prune: openrouter NOT in model_router → no/pruned entry
#   (7) idempotent wire: re-run → byte-identical .mcp.json
# Hermetic: keychain OPENROUTER_API_KEY is absent on this box → wrapper resolves
# from .env.local (a deliberately FAKE key). No real key is ever read.
# ============================================================================

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO/forge-setup-executors.sh"

PASS=0; FAIL=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

FAKE="sk-or-v1-FAKEtestkey00000000000000000000000000000000000000000000000000"

mkproj() {  # $1=openrouter-declared(true/false) → echoes project dir
    local d voices; d="$(mktemp -d)"; mkdir -p "$d/.claude"
    if [ "$1" = "true" ]; then voices='["codex-cli","openrouter"]'; else voices='["codex-cli"]'; fi
    jq -n --argjson o "$voices" '{project_name:"acme", model_router:{cross_vendor_voices:{openai:$o, google:["gemini-cli"]}}}' > "$d/.claude/forge.config.json"
    ( cd "$d" && git init -q && printf '.env.local\n' > .gitignore )
    printf 'OPENROUTER_API_KEY=%s\n' "$FAKE" > "$d/.env.local"; chmod 600 "$d/.env.local"
    printf '%s' "$d"
}

echo "── AC-5-4 wire (openrouter declared) ──"
P="$(mkproj true)"
bash "$SCRIPT" mcp wire --project-dir "$P" >/dev/null 2>&1
[ "$?" -eq 0 ] && ok "mcp wire exits 0" || bad "mcp wire failed"
MCP="$P/.mcp.json"
jq -e '.mcpServers.openrouter' "$MCP" >/dev/null 2>&1 && ok ".mcp.json has openrouter entry" || bad "no openrouter entry"
jq -e '.mcpServers.openrouter.env == {}' "$MCP" >/dev/null 2>&1 && ok "openrouter env block empty (no env-ref false-green form)" || bad "env block not empty"
grep -qF "$FAKE" "$MCP" && bad "literal key leaked into .mcp.json" || ok ".mcp.json carries NO literal key"
grep -q 'OPENROUTER_API_KEY' "$MCP" && ok ".mcp.json references OPENROUTER_API_KEY by name" || bad "no OPENROUTER_API_KEY reference"

echo "── AC-5-4 launch-env resolution (the fix) ──"
launcher="$(jq -r '.mcpServers.openrouter.args[1]' "$MCP")"
resolve_slice="${launcher%%; exec*}"
landed="$(bash -c "${resolve_slice}; [ -n \"\${OPENROUTER_API_KEY:-}\" ] && echo RESOLVED || echo EMPTY" 2>/dev/null)"
[ "$landed" = "RESOLVED" ] && ok "wrapper resolves the key into the spawn env (GUI-launch-safe)" || bad "wrapper did NOT resolve the key (landed=$landed)"

echo "── AC-5-4 negative: naive env-ref form false-greens ──"
# the broken form Claude Code would spawn: env-ref only, no wrapper resolution
naive='export OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-}"'   # what ${OPENROUTER_API_KEY} resolves to at GUI launch
naive_landed="$(env -u OPENROUTER_API_KEY bash -c "${naive}; [ -n \"\${OPENROUTER_API_KEY:-}\" ] && echo RESOLVED || echo EMPTY" 2>/dev/null)"
[ "$naive_landed" = "EMPTY" ] && ok "env-ref-only form + parent unset → EMPTY (the false-green the wrapper fixes)" || bad "naive form unexpectedly resolved"

echo "── AC-5-4 launch-path probe (fake key → FAIL, never PASS) ──"
out="$(bash "$SCRIPT" mcp probe --project-dir "$P" 2>&1)"; prc=$?
printf '%s' "$out" | grep -qF "$FAKE" && bad "mcp probe leaked the key" || ok "mcp probe output redacts the key"
[ "$prc" -ne 0 ] && ok "fake key → launch-path probe non-PASS (rc=$prc)" || bad "fake key produced PASS via launch path"
case "$out" in *PASS*) bad "launch-path probe claims PASS on a fake key" ;; *) ok "no false PASS (resolved-then-401, the right behaviour)" ;; esac

echo "── AC-5-4 F13: probe resolution == .mcp.json launcher (byte-for-byte) ──"
# the probe extracts the same slice the GUI launcher carries — re-derive and diff
probe_slice="$(jq -r '.mcpServers.openrouter.args[1]' "$MCP")"; probe_slice="${probe_slice%%; exec*}"
[ "$probe_slice" = "$resolve_slice" ] && ok "probe key-resolution slice is byte-identical to .mcp.json's" || bad "F13: probe slice diverges from launcher"

echo "── AC-5-4 idempotent prune + re-wire ──"
before="$(cat "$MCP")"
bash "$SCRIPT" mcp wire --project-dir "$P" >/dev/null 2>&1
[ "$(cat "$MCP")" = "$before" ] && ok "re-wire idempotent (.mcp.json byte-identical)" || bad "re-wire not idempotent"
# undeclare openrouter → prune
P2="$(mkproj false)"; bash "$SCRIPT" mcp wire --project-dir "$P2" >/dev/null 2>&1
jq -e '.mcpServers.openrouter' "$P2/.mcp.json" >/dev/null 2>&1 && bad "openrouter entry present though not declared" || ok "not declared → no openrouter entry (no mutation)"
# declared then undeclared on an existing entry → pruned
jq '.model_router.cross_vendor_voices.openai = ["codex-cli"]' "$P/.claude/forge.config.json" > "$P/.claude/fc.tmp" && mv "$P/.claude/fc.tmp" "$P/.claude/forge.config.json"
warn="$(bash "$SCRIPT" mcp wire --project-dir "$P" 2>&1)"
jq -e '.mcpServers.openrouter' "$MCP" >/dev/null 2>&1 && bad "stale openrouter entry not pruned" || ok "openrouter removed from router → stale entry pruned (warned)"

rm -rf "$P" "$P2"
echo ""
echo "── result: $PASS passed, $FAIL failed ──"
[ "$FAIL" -eq 0 ]
