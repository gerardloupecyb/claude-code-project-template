#!/usr/bin/env bash
set -uo pipefail
# ============================================================================
# forge-setup-keyhandling.test.sh — AC-5-2 / AC-5-3 [SENSIBLE] oracle (Plan 05)
# ============================================================================
# Leak-proof key handling + pinned-endpoint auth probe. Asserts:
#   AC-5-3 classification : 200→PASS, 401→FAIL-auth, 000/5xx→UNREACHABLE,
#                           429/402/4xx→VISIBLE non-PASS (never PASS)
#   AC-5-3 endpoint pin   : https + allowlisted host accepted; foreign host /
#                           plain-http rejected (config-supplied URL rejection)
#   AC-5-2 store          : .env.local gitignore-prechecked + chmod 600, key NOT
#                           in any TRACKED file (git ls-files | grep = 0)
#   AC-5-2 argv-safety    : probe is CONSTRUCTED to pass the key via `-K -` stdin,
#                           never -H/url argv; a live probe shows no key in ps
#   AC-5-2 redaction      : a fake-key probe never echoes the key (no false PASS)
# The probe never uses a REAL key — a deliberately fake sk-or-v1- shape only.
# ============================================================================

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO/forge-setup-executors.sh"
# shellcheck source=/dev/null
. "$SCRIPT"   # source-safe: loads functions, dispatch guarded by BASH_SOURCE==$0

PASS=0; FAIL=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

FAKE="sk-or-v1-FAKEtestkey00000000000000000000000000000000000000000000000000"

echo "── AC-5-3 outcome classification ──"
[ "$(_classify_probe 200)" = "PASS" ]        && ok "200 → PASS"            || bad "200 misclassified: $(_classify_probe 200)"
[ "$(_classify_probe 204)" = "PASS" ]        && ok "204 → PASS"            || bad "204 misclassified"
[ "$(_classify_probe 401)" = "FAIL-auth" ]   && ok "401 → FAIL-auth"       || bad "401 misclassified"
[ "$(_classify_probe 403)" = "FAIL-auth" ]   && ok "403 → FAIL-auth"       || bad "403 misclassified"
[ "$(_classify_probe 000)" = "UNREACHABLE" ] && ok "000 → UNREACHABLE"     || bad "000 misclassified"
[ "$(_classify_probe 503)" = "UNREACHABLE" ] && ok "503 → UNREACHABLE"     || bad "503 misclassified"
# rate-limit / quota / other-4xx must be VISIBLE non-PASS — never PASS
for s in 429 402 404; do
    o="$(_classify_probe "$s")"
    [ "$o" != "PASS" ] && ok "$s → $o (visible non-PASS, not PASS)" || bad "$s wrongly PASS"
done

echo "── AC-5-3 endpoint pinning (allowlist) ──"
_endpoint_allowed "https://api.openai.com/v1/models"      && ok "api.openai.com allowed"        || bad "api.openai.com rejected"
_endpoint_allowed "https://openrouter.ai/api/v1/models"   && ok "openrouter.ai allowed"          || bad "openrouter.ai rejected"
_endpoint_allowed "https://evil.example.com/v1/models"    && bad "foreign host NOT rejected"     || ok "foreign host rejected (exfil threat closed)"
_endpoint_allowed "http://api.openai.com/v1/models"       && bad "plain http NOT rejected"       || ok "plain http rejected (https-only)"
# openrouter MUST be auth-gated (/api/v1/key) — /models is public and would false-green
[ "$(_endpoint_for openrouter)" = "https://openrouter.ai/api/v1/key" ] && ok "openrouter pinned to AUTH-GATED /api/v1/key (not public /models)" || bad "openrouter endpoint wrong: $(_endpoint_for openrouter)"
[ "$(_keyvar_for codex-cli)" = "OPENAI_API_KEY" ] && ok "codex-cli → OPENAI_API_KEY" || bad "keyvar mapping wrong"

echo "── AC-5-2 store: .env.local gitignored + chmod 600, key not tracked ──"
PROJ="$(mktemp -d)"; ( cd "$PROJ" && git init -q && printf '.env.local\n.env\n.env.*\n' > .gitignore && git add .gitignore && git -c user.email=t@t -c user.name=t commit -qm init )
printf '%s' "$FAKE" | bash "$SCRIPT" keys --executor openrouter --stdin --project-dir "$PROJ" >/dev/null 2>&1
RC=$?
[ "$RC" -eq 0 ] && ok "keys store exits 0" || bad "keys store exit=$RC"
[ -f "$PROJ/.env.local" ] && grep -q "^OPENROUTER_API_KEY=${FAKE}$" "$PROJ/.env.local" && ok ".env.local carries OPENROUTER_API_KEY" || bad ".env.local missing the key line"
perm="$(stat -f '%Lp' "$PROJ/.env.local" 2>/dev/null || stat -c '%a' "$PROJ/.env.local" 2>/dev/null)"
[ "$perm" = "600" ] && ok ".env.local perms = 600" || bad ".env.local perms = $perm (want 600)"
# AC-5-2 oracle: the key is NOT in any TRACKED file
tracked_hits="$( cd "$PROJ" && git ls-files -z | xargs -0 grep -lF "$FAKE" 2>/dev/null | wc -l | tr -d ' ' )"
[ "$tracked_hits" = "0" ] && ok "key absent from all TRACKED files (git ls-files | grep = 0)" || bad "key found in $tracked_hits tracked file(s)"
# .env.local is genuinely gitignored
( cd "$PROJ" && git check-ignore -q .env.local ) && ok ".env.local is gitignored (git check-ignore)" || bad ".env.local not gitignored"

echo "── AC-5-2 argv-safety: construction proof + live ps ──"
# CONSTRUCTION: the probe must use `-K -` (stdin config) and must NOT put the key on argv
grep -q 'curl -K -' "$SCRIPT" && ok "probe uses 'curl -K -' (key via stdin, not argv)" || bad "probe does not use curl -K -"
grep -Eq 'curl[^|]*(-H|--header)[^|]*(KEY|Authorization: Bearer \$)' "$SCRIPT" && bad "probe puts an auth header on curl argv" || ok "no auth header on curl argv (construction)"
grep -Eq 'curl[^|]*\$KEY|curl[^|]*key=\$' "$SCRIPT" && bad "probe interpolates the key into curl argv/url" || ok "key never interpolated into curl argv/url"
# LIVE (best-effort, resilient): run a fake-key probe; sample ps; the key must never appear.
( bash "$SCRIPT" probe --executor openrouter --project-dir "$PROJ" >/dev/null 2>&1 ) &
probe_pid=$!
ps_clean=1
for _ in 1 2 3 4 5 6; do
    ps -Ao args= 2>/dev/null | grep -qF "$FAKE" && ps_clean=0 && break
    sleep 0.05
done
wait "$probe_pid" 2>/dev/null
[ "$ps_clean" -eq 1 ] && ok "live probe: fake key never visible in ps" || bad "fake key LEAKED into ps argv"

echo "── AC-5-2 redaction + no-false-PASS (fake key, real allowlisted host) ──"
out="$(bash "$SCRIPT" probe --executor openrouter --project-dir "$PROJ" 2>&1)"
prc=$?
printf '%s' "$out" | grep -qF "$FAKE" && bad "probe output leaked the key" || ok "probe output redacts the key"
# a FAKE key must never yield PASS (rc 0). FAIL-auth / UNREACHABLE / non-PASS all fine.
[ "$prc" -ne 0 ] && ok "fake key did not produce a false PASS (rc=$prc)" || bad "fake key produced PASS (rc=0)"
case "$out" in
    *PASS*) bad "output claims PASS on a fake key" ;;
    *FAIL-auth*|*UNREACHABLE*|*RATE-LIMITED*|*QUOTA*|*FAIL-other*) ok "outcome is a visible non-PASS ($(printf '%s' "$out" | grep -oE 'FAIL-auth|UNREACHABLE|RATE-LIMITED|QUOTA|FAIL-other' | head -1))" ;;
    *) bad "unexpected probe output: $out" ;;
esac

# config-supplied foreign endpoint → rejected
bash "$SCRIPT" probe --executor openrouter --project-dir "$PROJ" --endpoint "https://evil.example.com/v1/models" >/dev/null 2>&1
[ "$?" -eq 3 ] && ok "config-supplied foreign endpoint rejected (rc 3)" || bad "foreign endpoint not rejected"

# probe with NO key stored → returns 2 (not a crash, not a PASS)
PROJ2="$(mktemp -d)"; ( cd "$PROJ2" && git init -q )
env -u OPENROUTER_API_KEY bash "$SCRIPT" probe --executor openrouter --project-dir "$PROJ2" >/dev/null 2>&1
[ "$?" -eq 2 ] && ok "probe with no key → rc 2 (NO KEY, no false PASS)" || bad "probe no-key wrong rc"

rm -rf "$PROJ" "$PROJ2"
echo ""
echo "── result: $PASS passed, $FAIL failed ──"
[ "$FAIL" -eq 0 ]
