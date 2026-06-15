#!/usr/bin/env bash
set -uo pipefail
# ============================================================================
# e2e-python.test.sh — AC-4-6 load-bearing multi-stack proof (Phase 22 Plan 04)
# ============================================================================
# Proves the template is multi-stack with a POSITIVE assertion, not just absence-of-
# failure: a non-PowerShell (python) throwaway project inits, goes GREEN, ships no
# residual tokens / no PowerShell gate, and a configured PYTHON protected-domain
# actually BLOCKS a .py Write (the gate fires for real because AC-4-2 registered the
# hooks in the consumer settings.json). The throwaway is deleted after evidence.
# ============================================================================

REPO="$(cd "$(dirname "$0")/.." && pwd)"
INIT="$REPO/forge-init.sh"
CHECK="$REPO/check-setup.sh"

PASS=0; FAIL=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

echo "── AC-4-6 python multi-stack e2e ──"

# complete fixture answers (every residual FORGE token), SCRIPTING_LANG=python
WB="$(mktemp -d)"; WORKSPACE_DIR="$WB" bash "$INIT" "PySeed" pyseed "a" >/dev/null 2>&1 || true
SCOPE=(".claude/rules" ".claude/skills" ".claude/hooks" ".githooks" "scripts/forge" "CLAUDE.md" ".claude/gate.config.json" ".claude/forge.config.json" ".carl/manifest")
SP=(); for s in "${SCOPE[@]}"; do [ -e "$WB/PySeed/$s" ] && SP+=("$WB/PySeed/$s"); done
ANS="$(mktemp)"
grep -rhoE '\{\{[A-Za-z0-9_][A-Za-z0-9_-]*\}\}' "${SP[@]}" 2>/dev/null | sort -u | sed 's/^{{//;s/}}$//' \
    | jq -R . | jq -s 'map({key:., value:"generic"}) | from_entries | . + {SCRIPTING_LANG:"python", scripting_lang:"python"}' > "$ANS"
rm -rf "$WB"

# init the python throwaway
WP="$(mktemp -d)"; WORKSPACE_DIR="$WP" bash "$INIT" --answers "$ANS" "PyApp" pyapp "python,api" >/tmp/pyapp.log 2>&1; RCI=$?
PROJ="$WP/PyApp"
[ "$RCI" -eq 0 ] && ok "init (language=python) ⇒ exit 0 (tripwire GREEN, no residual)" || { bad "init exit=$RCI"; tail -6 /tmp/pyapp.log | sed 's/^/    /'; }

# no residual {{...}} in the FORGE tree
RES=$(grep -rhoE '\{\{[A-Za-z0-9_][A-Za-z0-9_-]*\}\}' "$PROJ/.claude/rules" "$PROJ/.claude/skills" "$PROJ/.claude/hooks" "$PROJ/CLAUDE.md" "$PROJ/.carl/manifest" 2>/dev/null | sort -u)
[ -z "$RES" ] && ok "no residual {{...}} in the FORGE tree" || bad "residual tokens: $(printf '%s' "$RES" | tr '\n' ' ')"

# gitleaks clean over the resolved tree
if command -v gitleaks >/dev/null 2>&1; then
    gitleaks detect --no-git --source "$PROJ" --redact --no-banner >/dev/null 2>&1 && ok "gitleaks: 0 findings over the resolved tree" || bad "gitleaks found a secret in the e2e tree"
else
    printf '  \033[33mSKIP\033[0m gitleaks not installed\n'
fi

# no PowerShell protected-DOMAIN is WIRED (functional skill-gate). Prose mentions of
# .ps1 in skill docs are inert; what matters is no PS gate fires for this python project.
# (gate.config ships the source's multi-language defaults incl a ps1 linter entry —
# inert without .ps1 files; a 22.1 genericization candidate, not a leak.)
if jq -e '[.protected_domains[]? | (.file_patterns // "") + " " + (.name // "")] | any(test("ps1|powershell";"i"))' "$PROJ/.claude/gate.config.json" >/dev/null 2>&1; then
    bad "a PowerShell protected-domain is wired in the python project"
else
    ok "no PowerShell protected-domain wired (functional gate)"
fi
# positive python signal #2: the python linter is configured (py → semgrep)
[ "$(jq -r '.linters.py // ""' "$PROJ/.claude/gate.config.json")" = "semgrep" ] && ok "python linter configured (py → semgrep)" || bad "python linter (py→semgrep) missing"

# configure the project for GREEN + a PYTHON protected domain (gate fires for real)
tmp="$(mktemp)"; jq '. + {"project_name":"PyApp","_no_compliance_frameworks_affirmed":true}' "$PROJ/.claude/forge.config.json" > "$tmp" && mv "$tmp" "$PROJ/.claude/forge.config.json"
tmp="$(mktemp)"; jq '.language="python" | .protected_domains += [{"name":"python","marker":"python-skill","file_patterns":"\\.py$","command_patterns":"","required_skills":"python-architect","lessons_domain":"py","unlock":"touch .skill-locks/python-skill"}]' "$PROJ/.claude/gate.config.json" > "$tmp" && mv "$tmp" "$PROJ/.claude/gate.config.json"

# check-setup GREEN
bash "$CHECK" "$PROJ" >/dev/null 2>&1 && ok "check-setup ⇒ GREEN (exit 0)" || { bad "check-setup not GREEN"; bash "$CHECK" "$PROJ" 2>&1 | sed 's/^/    /'; }

# no PowerShell gate FIRES: a .ps1 Write is NOT blocked (no PS domain configured)
printf '%s' '{"tool_name":"Write","tool_input":{"file_path":"scripts/deploy.ps1"}}' | CLAUDE_PROJECT_DIR="$PROJ" bash "$PROJ/.claude/hooks/pre-tool-use.sh" >/dev/null 2>&1; PS_RC=$?
[ "$PS_RC" -eq 0 ] && ok "no PowerShell gate fires (.ps1 Write allowed, exit 0)" || bad "a PowerShell gate unexpectedly fired (exit $PS_RC)"

# POSITIVE python behavior: a .py Write into the configured python domain is BLOCKED
printf '%s' '{"tool_name":"Write","tool_input":{"file_path":"app/main.py"}}' | CLAUDE_PROJECT_DIR="$PROJ" bash "$PROJ/.claude/hooks/pre-tool-use.sh" >/dev/null 2>&1; PY_RC=$?
[ "$PY_RC" -eq 2 ] && ok "POSITIVE: python domain BLOCKS a .py Write (pre-tool-use exit 2, observed)" || bad "python gate did not fire (exit $PY_RC)"

# cleanup throwaway
rm -rf "$WP" "$ANS"
[ ! -d "$PROJ" ] && ok "throwaway removed" || bad "throwaway not removed"

echo ""
echo "── result: ${PASS} passed, ${FAIL} failed ──"
[ "$FAIL" -eq 0 ]
