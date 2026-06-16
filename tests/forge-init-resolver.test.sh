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

echo "── review batch ⑥ — missing-tool ⇒ FAIL-CLOSED (not WARN+pass) ──"
# gitleaks lives in /usr/local/bin; a PATH of /usr/bin:/bin keeps jq+python3 but drops gitleaks.
FIX5="$(mktemp -d)"; printf 'x: {{Z}}\n' > "$FIX5/f.md"; ANS5="$(mktemp)"; jq -n '{Z:"ok"}' > "$ANS5"
if command -v gitleaks >/dev/null 2>&1 && [ "$(command -v gitleaks)" != "/usr/bin/gitleaks" ]; then
    if ( PATH="/usr/bin:/bin"; command -v gitleaks >/dev/null 2>&1 ) ; then
        printf '  \033[33mSKIP\033[0m (⑥) gitleaks reachable via /usr/bin — cannot simulate absence here\n'
    elif ( PATH="/usr/bin:/bin"; resolve_tree "$FIX5" "$ANS5" ) >/dev/null 2>&1; then
        bad "(⑥) resolve_tree GREEN with gitleaks absent — fail-OPEN regression"
    else
        ok "(⑥) gitleaks absent ⇒ resolve_tree fail-CLOSED (non-zero) — S/F1 mandatory"
    fi
else
    printf '  \033[33mSKIP\033[0m (⑥) gitleaks not installed / in /usr/bin\n'
fi
rm -rf "$FIX5" "$ANS5"

echo "── review batch ⑦ — forge-init has no raw-sed token substitution ──"
if grep -qF 's|{{' "$REPO/forge-init.sh"; then
    bad "(⑦) forge-init.sh still uses raw 'sed s|{{TOKEN}}|VALUE' (operator-value injection: & | \\)"
else
    ok "(⑦) forge-init.sh uses no raw-sed token substitution (gen_from_template ⇒ injection-safe resolver)"
fi

echo "── re-review residue — resolve_files tripwires a residual token (scoped sync fail-closed) ──"
FIX6="$(mktemp -d)"; printf 'a {{ANSWERED}} b {{UNANSWERED}} c\n' > "$FIX6/copied.md"; ANS6="$(mktemp)"; jq -n '{ANSWERED:"x"}' > "$ANS6"
if resolve_files "$FIX6" "$ANS6" "$FIX6/copied.md" >/dev/null 2>&1; then
    bad "(⑧+) resolve_files GREEN with a residual {{UNANSWERED}} in a copied file (should fail-closed)"
else
    ok "(⑧+) resolve_files fail-closed on a residual {{token}} in a copied file (new template token, no answer)"
fi
rm -rf "$FIX6" "$ANS6"

echo "── confirmation-pass residue (#3) — answers.json gitleaks --config is word-split-safe on a SPACED path ──"
# (a) SOURCE guard: forge-init.sh must use an argv ARRAY for the optional --config, not an unquoted
#     string that word-splits when PROJECT_DIR has a space; + the set -u/bash-3.2-safe empty expansion.
if grep -qE '_AJ_CFG="--config' "$REPO/forge-init.sh"; then
    bad "(#3a) forge-init.sh still builds _AJ_CFG as an UNQUOTED string ⇒ word-splits on a spaced PROJECT_DIR"
elif grep -qF '_AJ_CFG=(--config' "$REPO/forge-init.sh" && grep -qF '${_AJ_CFG[@]+"${_AJ_CFG[@]}"}' "$REPO/forge-init.sh"; then
    ok "(#3a) forge-init.sh uses an argv array + set-u/bash-3.2-safe empty expansion for --config"
else
    bad '(#3a) forge-init.sh argv-array form not found (expected _AJ_CFG=(--config ...) + ${_AJ_CFG[@]+"${_AJ_CFG[@]}"})'
fi
# (b) BEHAVIOURAL: reproduce the failure on a SPACED path — the fixed array form keeps --config <path>
#     as ONE argv element, while the OLD unquoted form splits it (proves the test discriminates).
SP3="$(mktemp -d)"; SPP="$SP3/sp ace"; mkdir -p "$SPP/.forge"; printf '[allowlist]\n' > "$SPP/.gitleaks.toml"; printf '{"x":"ok"}\n' > "$SPP/.forge/answers.json"
AF3="$(mktemp)"
bash -c '
  set -uo pipefail
  PROJECT_DIR="$1"; argv_file="$2"
  gitleaks() { : > "$argv_file"; for a in "$@"; do printf "%s\n" "$a" >> "$argv_file"; done; }
  _AJ_CFG=(); [ -f "${PROJECT_DIR}/.gitleaks.toml" ] && _AJ_CFG=(--config "${PROJECT_DIR}/.gitleaks.toml")
  gitleaks detect --no-git --source "${PROJECT_DIR}/.forge/answers.json" ${_AJ_CFG[@]+"${_AJ_CFG[@]}"} --redact --no-banner
  grep -qxF "${PROJECT_DIR}/.gitleaks.toml" "$argv_file" || exit 7      # fixed form failed to keep path whole
  _OLD=""; [ -f "${PROJECT_DIR}/.gitleaks.toml" ] && _OLD="--config ${PROJECT_DIR}/.gitleaks.toml"
  : > "$argv_file"; gitleaks detect --no-git --source "${PROJECT_DIR}/.forge/answers.json" $_OLD --redact --no-banner
  if grep -qxF "${PROJECT_DIR}/.gitleaks.toml" "$argv_file"; then exit 8; fi   # old form kept it whole ⇒ no repro
  exit 0
' _ "$SPP" "$AF3"; RC3=$?
case "$RC3" in
  0) ok "(#3b) spaced-path: argv array keeps --config <path> as ONE arg; unquoted form splits it (regression reproduced + fixed)" ;;
  7) bad "(#3b) argv-array form STILL split the spaced config path (fix ineffective)" ;;
  8) bad "(#3b) could not reproduce the word-split on the spaced path (test no longer discriminates)" ;;
  *) bad "(#3b) spaced-path regression test errored rc=$RC3" ;;
esac
rm -rf "$SP3" "$AF3"

rm -rf "$FIX" "$FIX2" "$WORKDIR" "$ANS" "$ANS2"
echo ""
echo "── result: ${PASS} passed, ${FAIL} failed ──"
[ "$FAIL" -eq 0 ]
