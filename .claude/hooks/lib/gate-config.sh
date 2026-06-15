#!/bin/bash
# Shared gate-config chokepoint (Plan 22-02). Sourced by pre-tool-use.sh, pre-mcp-gate.sh,
# .githooks/pre-commit, and scripts/forge/render-skill-gate.sh.
#
# ONE place validates .claude/gate.config.json:
#   - file exists, parses as JSON
#   - SHAPE/TYPE is correct (wrong-type fields can't slip past `jq -e .` and silently bypass a gate)
#   - every config-derived ERE actually COMPILES under grep (an uncompilable regex would make a downstream
#     `grep` exit 2 — an error — which the hooks must NOT swallow as "no-match → allow")
#
# Downstream hook code assumes a validated config. This subsumes, in one chokepoint:
#   the empty-key default guards, the per-hook `jq -e .` check, and grep exit-2-vs-exit-1 handling.
# See .claude/rules/skill-gate.md § Correspondance avec le hook.

# Observable-but-no-exit. Loud stdout + stderr + a one-line audit append wrapped `|| true` so the append can
# NEVER fail-CLOSE the hook. The CALLER decides the fail direction (runtime hooks: exit 0 = allow;
# pre-commit: fall back to the default SAST surface and keep scanning).
gate_fail_open() {
  local hook="$1" reason="$2"
  local msg="⚠ GATE FAIL-OPEN (${hook}): ${reason} — gate NOT enforced this call. Fix .claude/gate.config.json."
  echo "$msg"
  echo "$msg" >&2
  { mkdir -p "$HOME/.claude" && printf '[%s] %s fail-open: %s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$hook" "$reason" >> "$HOME/.claude/gate-failopen.log"; } 2>/dev/null || true
}

# gate_degraded <hook> <reason> : observable note that an ALWAYS-ON gate's config pattern was empty /
# vacuous / uncompilable so the hook FELL BACK to its built-in default — the gate STAYS ENFORCED (AC-2-2:
# SCAG / prod-MCP protection is un-skippable). DISTINCT from gate_fail_open, which means the gate is NOT
# enforced this call. Same audit log; the operator sees the misconfiguration without losing the control.
gate_degraded() {
  local hook="$1" reason="$2"
  local msg="⚠ GATE DEGRADED (${hook}): ${reason} — using built-in default; gate STILL enforced. Fix .claude/gate.config.json."
  echo "$msg"
  echo "$msg" >&2
  { mkdir -p "$HOME/.claude" && printf '[%s] %s degraded: %s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$hook" "$reason" >> "$HOME/.claude/gate-failopen.log"; } 2>/dev/null || true
}

# gate_config_shape_ok <path> : returns 0 iff the config is present, valid JSON, well-shaped, and every
# config regex compiles. On failure sets GATE_CONFIG_REASON. Pure predicate — no output, no exit.
GATE_CONFIG_REASON=""
gate_config_shape_ok() {
  local cfg="$1"
  GATE_CONFIG_REASON=""
  [ -f "$cfg" ] || { GATE_CONFIG_REASON="config not found: $cfg"; return 1; }
  jq -e . "$cfg" >/dev/null 2>&1 || { GATE_CONFIG_REASON="invalid JSON"; return 1; }

  # ── Shape / type — one jq assertion. Optional keys may be null/absent; present ones must be well-typed.
  #    Array elements that feed a regex or a marker MUST be strings (never arrays/objects). dep_ecosystems
  #    and code_extensions values must be NON-EMPTY strings so a join() can't yield an empty alternation
  #    (`pip|` / `\.(js|)$`) that makes grep error.
  jq -e '
    (.protected_domains | type == "array")
    and (.protected_domains | all(
          (.name == null or (.name|type) == "string")
          and (.marker == null or (.marker|type) == "string")
          and (.file_patterns == null or (.file_patterns|type) == "string")
          and (.command_patterns == null or (.command_patterns|type) == "string")
          and (.required_skills == null or (.required_skills|type) == "string")
          and (.lessons_domain == null or (.lessons_domain|type) == "string")
          and (.unlock == null or (.unlock|type) == "string")
          and (.label == null or (.label|type) == "string")
          and (.triggers_doc == null or (.triggers_doc|type) == "string")))
    and (.gated_mcp == null or (.gated_mcp|type) == "array")
    and ((.gated_mcp // []) | all(
          (.server_prefix == null or (.server_prefix|type) == "string")
          and (.marker == null or (.marker|type) == "string")
          and (.message == null or (.message|type) == "string")))
    and (.mutation_verbs == null or (.mutation_verbs|type) == "string")
    and (.dep_ecosystems == null or (.dep_ecosystems|type) == "object")
    and (((.dep_ecosystems // {}) | values) | all((type) == "string" and . != ""))
    and (.code_extensions == null or (.code_extensions|type) == "array")
    and ((.code_extensions // []) | all((type) == "string" and . != ""))
    and (.linters == null or (.linters|type) == "object")
    and (.language == null or (.language|type) == "array")
    and ((.language // []) | all((type) == "string"))
    and (.copresence_guards == null or (.copresence_guards|type) == "array")
    and ((.copresence_guards // []) | all(
          (.trigger_pattern == null or (.trigger_pattern|type) == "string")
          and (.required_file == null or (.required_file|type) == "string")
          and (.message == null or (.message|type) == "string")))
  ' "$cfg" >/dev/null 2>&1 || { GATE_CONFIG_REASON="config shape/type invalid"; return 1; }

  # ── Regex compilability — every config-derived ERE must compile, else a downstream grep would exit 2
  #    (error) and be swallowed as no-match. Test-compile against empty input: rc 0/1 = compiles, rc>=2 = error.
  local re rc
  while IFS= read -r re; do
    [ -n "$re" ] || continue
    printf '' | grep -qE "$re" 2>/dev/null
    rc=$?
    [ "$rc" -le 1 ] || { GATE_CONFIG_REASON="uncompilable regex in config: ${re}"; return 1; }
  done < <(jq -r '
      [ (.protected_domains[]? | .file_patterns, .command_patterns),
        ((.dep_ecosystems // {}) | values[]),
        .mutation_verbs,
        (.copresence_guards[]? | .trigger_pattern) ]
      | map(select(. != null and . != "")) | .[]' "$cfg" 2>/dev/null)

  return 0
}

# gate_runtime_floor_ok <path> : the THINNED runtime check (Plan 22-02 Option-3 / AC-2-7). The runtime
# TRUSTS the write-time-validated config (validate-gate-config.sh runs in pre-commit on the staged blob +
# CI) and re-checks ONLY a minimal O(1) floor — present + valid JSON + array-type of the gate-bearing keys
# (protected_domains array, gated_mcp array-or-absent, mutation_verbs string-or-absent). Deep validation
# (regex-compilability, per-element non-emptiness, R3 vacuity) is WRITE-TIME ONLY — deliberately NOT re-run
# here (that was the per-call chokepoint Option-3 removed). On ANY floor miss the CALLER fail-opens
# OBSERVABLY (exit 0 allow + loud stdout/stderr + audit). An empty `protected_domains: []` PASSES the floor
# (it is a valid array) so the always-on SCAG / prod-MCP gates still fire downstream (AC-2-2 greenfield).
# A wrong-SHAPE config (e.g. protected_domains as a string) fails the floor → OBSERVABLE fail-open, never a
# silent jq-accessor no-match — and the write-time validator already blocks such a config from committing.
gate_runtime_floor_ok() {
  local cfg="$1"
  GATE_CONFIG_REASON=""
  [ -f "$cfg" ] || { GATE_CONFIG_REASON="config not found: $cfg"; return 1; }
  jq -e . "$cfg" >/dev/null 2>&1 || { GATE_CONFIG_REASON="invalid JSON"; return 1; }
  jq -e '
    (.protected_domains | type == "array")
    and (.gated_mcp == null or (.gated_mcp | type == "array"))
    and (.mutation_verbs == null or (.mutation_verbs | type == "string"))
  ' "$cfg" >/dev/null 2>&1 \
    || { GATE_CONFIG_REASON="runtime floor: protected_domains/gated_mcp not array or mutation_verbs not string"; return 1; }
  return 0
}

# gate_resolve_alwayson <pattern> <default> <hook> <label> : resolve a guaranteed-usable ERE for an
# ALWAYS-ON gate (SCAG dep_ecosystems, prod-MCP mutation_verbs) into the GLOBAL `GATE_ALWAYSON_RE`. Keeps
# <pattern> when it is non-empty, non-vacuous (not blank-after-trim, not pure-non-word — the SAME R3a test
# the write-time validator applies) and compiles under grep; otherwise sets <default> and emits an
# OBSERVABLE gate_degraded note. The gate is therefore NEVER silently disabled by an empty / vacuous /
# uncompilable config pattern (AC-2-2 / AC-2-7 D2); deep validation is owned by the write-time validator,
# this is only the runtime never-silent floor.
#
# NOTE: the result is returned via the GLOBAL, NOT stdout — gate_degraded writes to stdout (observability,
# like gate_fail_open), so a `$(...)`-captured return value would be contaminated by the warning text.
GATE_ALWAYSON_RE=""
gate_resolve_alwayson() {
  local pat="$1" def="$2" hook="$3" label="$4" trimmed rc
  GATE_ALWAYSON_RE=""
  if [ -z "$pat" ]; then GATE_ALWAYSON_RE="$def"; return 0; fi
  trimmed=$(printf '%s' "$pat" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  if [ -z "$trimmed" ] || ! printf '%s' "$pat" | grep -q '[A-Za-z0-9_]'; then
    gate_degraded "$hook" "${label} is vacuous (blank-after-trim or pure-non-word)"
    GATE_ALWAYSON_RE="$def"; return 0
  fi
  printf '' | grep -qE "$pat" 2>/dev/null; rc=$?
  if [ "$rc" -ge 2 ]; then
    gate_degraded "$hook" "${label} regex does not compile"
    GATE_ALWAYSON_RE="$def"; return 0
  fi
  GATE_ALWAYSON_RE="$pat"
}

# gate_resolve_scag <config-path> <default> <hook> : resolve the SCAG (supply-chain) ERE from the
# `dep_ecosystems` OBJECT into the global GATE_ALWAYSON_RE. dep_ecosystems is an object of PER-ECOSYSTEM
# regexes, so it CANNOT reuse gate_resolve_alwayson (a single-string resolver): a SINGLE vacuous member
# silently DROPS that ecosystem's coverage from the join (e.g. python="   " replaces the pip pattern, so
# `pip install` slips the gate — an UNDER-match the joined-string vacuity test misses because the join
# still has word chars from the other members). So this checks EACH value with the SAME R3a test the
# write-time validator applies; if ANY is non-string / blank-after-trim / pure-non-word, or the dep set is
# empty, or the join won't compile, it falls back to the FULL built-in <default> (gate STAYS ON, every
# ecosystem covered) — OBSERVABLE via gate_degraded when the cause is a malformed (not merely absent)
# config. SCAG is therefore NEVER silently disabled (AC-2-2 / AC-2-7 D2).
gate_resolve_scag() {
  local cfg="$1" def="$2" hook="$3" state re src
  GATE_ALWAYSON_RE=""
  state=$(jq -r '
    (.dep_ecosystems // {}) | [ .[] ] as $v
    | if ($v | length) == 0 then "empty"
      elif ($v | any(
          (type != "string")
          or ((gsub("^[[:space:]]+|[[:space:]]+$";"")) == "")
          or ((test("[A-Za-z0-9_]")) | not))) then "vacuous"
      else "ok" end' "$cfg" 2>/dev/null)
  case "$state" in
    ok)
      re=$(jq -r '(.dep_ecosystems // {}) | to_entries | map(.value) | join("|")' "$cfg" 2>/dev/null)
      if [ -z "$re" ]; then GATE_ALWAYSON_RE="$def"; return 0; fi
      printf '' | grep -qE "$re" 2>/dev/null; src=$?
      if [ "$src" -ge 2 ]; then
        gate_degraded "$hook" "dep_ecosystems regex does not compile"
        GATE_ALWAYSON_RE="$def"; return 0
      fi
      GATE_ALWAYSON_RE="$re" ;;
    vacuous)
      gate_degraded "$hook" "dep_ecosystems has a vacuous member (blank/pure-non-word) — would drop an ecosystem from SCAG"
      GATE_ALWAYSON_RE="$def" ;;
    *)
      # "empty" = absent/greenfield (silent default, legit); any jq error => safe default.
      GATE_ALWAYSON_RE="$def" ;;
  esac
}

# gate_lib_resolve : echo the absolute path to this lib, given a caller's BASH_SOURCE dir. Helper for
# hooks at different depths (.claude/hooks/ vs .githooks/). Not strictly required — kept for clarity.
gate_lib_path() { printf '%s\n' "${BASH_SOURCE[0]}"; }
