#!/usr/bin/env bash
set -uo pipefail
# ============================================================================
# forge-setup-skills.test.sh — AC-5-5 skill-identification oracle (Plan 05)
# ============================================================================
# Asserts:
#   (1) 'python,rest-api' → python-architect + api-architect SKILL.md skeletons,
#       each skill-framework.md-compliant (frontmatter name/description, H1,
#       'What this skill does NOT do'), registered in skills-inventory + registry
#   (2) 'none' → no skills forged
#   (3) D-16: the questionnaire OUTPUT offers NO reusable-starter catalog /
#       n8n-default-on opt-in (grep for an offer = 0)
#   (4) idempotent: re-run does not duplicate skeletons or registry rows
# ============================================================================

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO/forge-setup-skills.sh"

PASS=0; FAIL=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

mkproj() { local d; d="$(mktemp -d)"; mkdir -p "$d/.claude" "$d/docs/architecture/forge"; printf '# Component Registry\n\n## 1. Skills\n' > "$d/docs/architecture/forge/component-registry.md"; printf '%s' "$d"; }

echo "── AC-5-5 forge from declared stack ──"
P="$(mkproj)"
out="$(bash "$SCRIPT" --project-dir "$P" --stack "python,rest-api" 2>&1)"
[ "$?" -eq 0 ] && ok "questionnaire exits 0" || bad "questionnaire failed"
for sk in python-architect api-architect; do
    f="$P/.claude/skills/$sk/SKILL.md"
    [ -f "$f" ] && ok "$sk SKILL.md scaffolded" || { bad "$sk SKILL.md missing"; continue; }
    grep -q "^name: $sk$" "$f"               && ok "$sk frontmatter name correct"        || bad "$sk frontmatter name wrong"
    grep -q '^description:' "$f"              && ok "$sk has description"                 || bad "$sk no description"
    grep -q "^# /$sk —" "$f"                  && ok "$sk has H1 title"                    || bad "$sk no H1"
    grep -q 'What this skill does NOT do' "$f" && ok "$sk has 'does NOT do' section"      || bad "$sk missing required section"
done
# registered in both inventories
grep -q '`python-architect`' "$P/docs/solutions/agents/skills-inventory.md" 2>/dev/null && ok "python-architect in skills-inventory" || bad "not in skills-inventory"
grep -q '`api-architect`' "$P/docs/architecture/forge/component-registry.md" 2>/dev/null && ok "api-architect registered in component-registry" || bad "not in component-registry"

echo "── AC-5-5 'none' → nothing forged ──"
P2="$(mkproj)"
bash "$SCRIPT" --project-dir "$P2" --stack "none" >/dev/null 2>&1
n="$(ls -1 "$P2/.claude/skills" 2>/dev/null | wc -l | tr -d ' ')"
[ "$n" = "0" ] && ok "'none' forged no skills" || bad "'none' forged $n skill(s)"

echo "── AC-5-5 D-16: no starter-catalog / n8n-default offer ──"
allout="$(bash "$SCRIPT" --project-dir "$(mkproj)" --stack "python,rest-api" 2>&1; bash "$SCRIPT" --project-dir "$(mkproj)" --stack "none" 2>&1)"
if printf '%s' "$allout" | grep -Eiq 'starter[ -]catalog|n8n[ -]default|default[ -]on|opt[ -]?in.*catalog'; then
    bad "questionnaire output offers a starter catalog / n8n-default opt-in (D-16 violation)"
else
    ok "no starter-catalog / n8n-default offer in output (D-16 honoured)"
fi

echo "── AC-5-5 idempotent ──"
before_skills="$(ls -1 "$P/.claude/skills" | sort)"
before_inv="$(wc -l < "$P/docs/solutions/agents/skills-inventory.md")"
bash "$SCRIPT" --project-dir "$P" --stack "python,rest-api" >/dev/null 2>&1
after_skills="$(ls -1 "$P/.claude/skills" | sort)"
after_inv="$(wc -l < "$P/docs/solutions/agents/skills-inventory.md")"
[ "$before_skills" = "$after_skills" ] && ok "re-run does not duplicate skeletons" || bad "skeletons duplicated"
[ "$before_inv" = "$after_inv" ] && ok "re-run does not duplicate inventory rows" || bad "inventory rows duplicated"

rm -rf "$P" "$P2"
echo ""
echo "── result: $PASS passed, $FAIL failed ──"
[ "$FAIL" -eq 0 ]
