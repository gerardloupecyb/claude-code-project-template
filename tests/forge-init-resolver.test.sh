#!/usr/bin/env bash
set -uo pipefail
# ============================================================================
# forge-init-resolver.test.sh — AC-4-7 injection-safety oracle (Phase 22 Plan 04)
# ============================================================================
# SAFE-BY-CONSTRUCTION hostile-input fixture. The questionnaire answer carries sed
# metachars + NON-destructive command-substitution probes ONLY (`$(touch PWNED)` +
# a backtick `touch` + `& / | { } " \`). NO `rm` / destructive payload — a broken
# escape must never be able to delete the tree.
#
# Asserts:
#   (1) no command substitution executed   (PWNED / PWNED2 ABSENT)
#   (2) nothing destructive ran            (CANARY PRESENT)
#   (3) exact literal round-trip           (payload present verbatim in .md)
#   (4) JSON structural safety             (jq --arg path: valid JSON + literal value)
#   (5) fail-closed on invalid structure   (an answer that breaks YAML ⇒ non-zero)
# ============================================================================

REPO="$(cd "$(dirname "$0")/.." && pwd)"
. "$REPO/.forge/forge-resolve.sh"

PASS=0; FAIL=0
ok()   { printf '  \033[32mPASS\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

# NON-destructive hostile payload (sed metachars + command-sub probes; NO rm)
PAYLOAD='a/b&c|d$(touch PWNED)e`touch PWNED2`f{g}h"i\j'

echo "── AC-4-7 injection-safety fixture ──"
FIX="$(mktemp -d)"
# canary + a tracked CWD where an executed $(touch PWNED) would land
WORKDIR="$(mktemp -d)"; cd "$WORKDIR"
touch "$FIX/CANARY"
printf 'before {{HOSTILE}} after\n' > "$FIX/doc.md"
printf '{"name":"{{HOSTILE}}","keep":"x"}\n' > "$FIX/conf.json"
ANS="$(mktemp)"; jq -n --arg v "$PAYLOAD" '{HOSTILE:$v}' > "$ANS"

resolve_tree "$FIX" "$ANS"; RC=$?

# (1) no command-substitution executed
if [ ! -e "$FIX/PWNED" ] && [ ! -e "$FIX/PWNED2" ] && [ ! -e "$WORKDIR/PWNED" ] && [ ! -e "$WORKDIR/PWNED2" ] && [ ! -e ./PWNED ] && [ ! -e ./PWNED2 ]; then
    ok "(1) no command substitution executed (PWNED/PWNED2 absent)"
else
    bad "(1) command substitution EXECUTED — PWNED created"
fi
# (2) canary survived
[ -e "$FIX/CANARY" ] && ok "(2) CANARY present (nothing destructive ran)" || bad "(2) CANARY missing"
# (3) literal round-trip in the .md (awk literal path)
if grep -Fq "$PAYLOAD" "$FIX/doc.md"; then ok "(3) exact literal round-trip in doc.md"; else bad "(3) payload not round-tripped literally"; fi
# (4) JSON structural safety (jq --arg path)
if jq -e . "$FIX/conf.json" >/dev/null 2>&1 && [ "$(jq -r '.name' "$FIX/conf.json")" = "$PAYLOAD" ] && [ "$(jq -r '.keep' "$FIX/conf.json")" = "x" ]; then
    ok "(4) JSON stayed valid + value preserved verbatim (jq --arg)"
else
    bad "(4) JSON broken or value corrupted"
fi
# resolve_tree returned 0 on this (valid) fixture
[ "$RC" -eq 0 ] && ok "(resolve_tree exit 0 on the safe fixture)" || bad "(resolve_tree non-zero on a valid fixture: $RC)"

echo "── AC-4-7 fail-closed-on-invalid-structure ──"
FIX2="$(mktemp -d)"
printf 'version: 1\nkey: {{Y}}\n' > "$FIX2/bad.yaml"          # unclosed flow seq breaks YAML
ANS2="$(mktemp)"; jq -n '{Y:"[a, b"}' > "$ANS2"
if resolve_tree "$FIX2" "$ANS2" >/dev/null 2>&1; then
    bad "(5) shipped an invalid YAML (should have failed closed)"
else
    ok "(5) fail-closed: invalid YAML post-resolve ⇒ non-zero exit"
fi

echo "── AC-4-7 S/F1 secret backstop ──"
if command -v gitleaks >/dev/null 2>&1; then
    FIX3="$(mktemp -d)"
    printf 'token: {{KEY}}\n' > "$FIX3/creds.md"
    # fake-but-detectable GitHub PAT shape (NOT a real secret, NOT an allowlisted example)
    ANS3="$(mktemp)"; jq -n '{KEY:"ghp_0123456789abcdefghijABCDEFGHIJ012345"}' > "$ANS3"
    if resolve_tree "$FIX3" "$ANS3" >/dev/null 2>&1; then
        bad "(6) S/F1: a pasted secret was NOT caught (should fail closed)"
    else
        ok "(6) S/F1: gitleaks caught the pasted key-shape ⇒ non-zero exit"
    fi
    rm -rf "$FIX3" "$ANS3"
else
    printf '  \033[33mSKIP\033[0m (6) S/F1 — gitleaks not installed in this env\n'
fi

rm -rf "$FIX" "$FIX2" "$WORKDIR" "$ANS" "$ANS2"
echo ""
echo "── result: ${PASS} passed, ${FAIL} failed ──"
[ "$FAIL" -eq 0 ]
