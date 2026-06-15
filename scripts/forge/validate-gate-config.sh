#!/bin/bash
# validate-gate-config.sh — WRITE-TIME strict validation of .claude/gate.config.json
# (Plan 22-02, Option-3 / AC-2-6). Runs in .githooks/pre-commit (on the STAGED BLOB) + CI.
#
# It REUSES gate_config_shape_ok (R1 present+valid-JSON, R2 shape/type, regex-compilability) from
# .claude/hooks/lib/gate-config.sh — NO logic fork — then ADDS the two layers the thinned runtime hooks
# no longer run (AC-2-7 relocates deep validation to write-time):
#
#   R3a — VACUITY rejection. An OPERATIVE string that is blank-after-trim OR pure-non-word (contains no
#         [A-Za-z0-9_]) is a no-op pattern that silently disables the gate it feeds. Applies to:
#         mutation_verbs (if present), each dep_ecosystems value, each PRESENT-non-empty
#         protected_domains[].file_patterns / .command_patterns. An EMPTY "" trigger is treated as
#         ABSENT (n8n/ghl legitimately set command_patterns:"") — the all-absent case is caught by R3c.
#   R3c — MANDATORY-FIELD presence + non-emptiness (Gemini F1). gate_config_shape_ok accepts a
#         null/omitted marker / server_prefix, so a PR that DELETES `marker` passes shape — then the
#         runtime hook sees an empty marker and FAILS OPEN (unauthorized prod-MCP mutation / protected
#         write). R3c rejects that here, at write-time:
#           - each gated_mcp[]:        server_prefix AND marker present + non-blank
#           - each protected_domains[]: name AND marker present + non-blank, AND >=1 operative trigger
#
# R3b — a valid-looking word that matches no real verb (e.g. mutation_verbs:"zzz_no_such_verb") is
#       UNDECIDABLE at write-time (the verb universe is open). Explicit NON-GOAL: the validator does NOT
#       attempt it. It is the operator's own-diff choice, observable in their diff.
#
# Usage: validate-gate-config.sh <path-to-gate.config.json>
# Exit:  0 = valid; 1 = invalid (specific reason on stderr); 2 = usage error.

set -uo pipefail

CFG="${1:-}"
[ -n "$CFG" ] || { echo "usage: validate-gate-config.sh <gate.config.json>" >&2; exit 2; }

# Resolve the shared lib relative to THIS script (BASH_SOURCE), so validation works whether the config arg
# is the worktree path (CI) or a temp file holding the staged blob (pre-commit, where cwd-relative fails).
_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_LIB="$_SELF_DIR/../../.claude/hooks/lib/gate-config.sh"
if [ ! -f "$GATE_LIB" ]; then
  echo "gate.config INVALID: shared lib not found ($GATE_LIB)" >&2
  exit 1
fi
# shellcheck source=/dev/null
. "$GATE_LIB"

fail() { echo "gate.config INVALID: $1" >&2; exit 1; }

# ── R1 + R2 + regex-compilability — reuse the shared chokepoint (single source, no re-implementation). ──
gate_config_shape_ok "$CFG" || fail "${GATE_CONFIG_REASON:-shape/type/regex-compilability check failed}"

# ── R3c (mandatory gated_mcp fields) ──────────────────────────────────────────────────────────────────
jq -e '
  (.gated_mcp // []) | all(
    ((.server_prefix // "") | (gsub("^[[:space:]]+|[[:space:]]+$";"") != ""))
    and ((.marker // "") | (gsub("^[[:space:]]+|[[:space:]]+$";"") != "")))
' "$CFG" >/dev/null 2>&1 \
  || fail "R3c: a gated_mcp[] entry has a missing/blank server_prefix or marker (deleted marker => runtime fail-open)"

# ── R3c (mandatory protected_domains fields + >=1 operative trigger) ───────────────────────────────────
jq -e '
  def trimmed: gsub("^[[:space:]]+|[[:space:]]+$";"");
  def is_operative: (. != null) and (. != "") and (trimmed != "") and ((test("[A-Za-z0-9_]")) == true);
  (.protected_domains // []) | all(
    ((.name // "")   | (trimmed != ""))
    and ((.marker // "") | (trimmed != ""))
    and ((.file_patterns | is_operative) or (.command_patterns | is_operative)))
' "$CFG" >/dev/null 2>&1 \
  || fail "R3c: a protected_domains[] entry has a missing/blank name or marker, or NO operative file_patterns/command_patterns trigger"

# ── R3a (vacuity: present-non-empty operative strings must not be blank-after-trim or pure-non-word) ────
#   EMPTY "" is allowed (= absent trigger, R3c covers the all-absent case); only PRESENT-non-empty content
#   that is whitespace-only or has no word char is a silent-disable no-op.
jq -e '
  def trimmed: gsub("^[[:space:]]+|[[:space:]]+$";"");
  # true when a value is PRESENT, non-empty, yet vacuous (blank-after-trim OR pure-non-word).
  def vacuous: (. != null) and (. != "") and (((trimmed) == "") or ((test("[A-Za-z0-9_]")) | not));
  ((.mutation_verbs == null) or ((.mutation_verbs | vacuous) | not))
  and (((.dep_ecosystems // {}) | values) | all((vacuous) | not))
  and ((.protected_domains // []) | all(
        ((.file_patterns | vacuous) | not) and ((.command_patterns | vacuous) | not)))
' "$CFG" >/dev/null 2>&1 \
  || fail "R3a: a vacuous operative string (mutation_verbs / dep_ecosystems value / protected_domains trigger blank-after-trim or pure-non-word) would silently disable its gate"

echo "gate.config OK: $CFG"
exit 0
