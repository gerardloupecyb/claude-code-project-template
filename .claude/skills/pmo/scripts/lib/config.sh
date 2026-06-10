#!/usr/bin/env bash
# lib/config.sh — load and validate .claude/skills/pmo/config.yaml
#
# Exports every PMO_* variable the rest of the /pmo skill consumes.
# Called from pmo.sh (and from automated tests that source it directly).
#
# Contract:
#   - Silent on success (Loupe convention).
#   - Non-zero exit and stderr message on any failure (missing file, bad schema).
#   - Allows pre-set PMO_STATE_MD env override so tests can exercise D-19
#     graceful degradation without rewriting config.yaml on disk.
#
# Parser note:
#   The original implementation used `python3 -c 'import yaml; ...'`, but PyYAML
#   is not guaranteed to be installed and adding a pip dependency collides with
#   the SCAG gate. This file now embeds a minimal awk-based YAML reader that
#   handles the exact schema of config.yaml (flat scalars, one-level nested
#   maps, block sequences of scalars). It is NOT a general YAML parser. Any
#   structural change to config.yaml must be mirrored here.
set -euo pipefail

# _pmo_unescape_double_quoted — undo YAML double-quoted escapes we care about
# (\\ → \, \" → ", \n → LF). Called only for values that started with '"'.
_pmo_unescape_double_quoted() {
  local s="$1"
  s="${s//\\\\/$'\x01'}"    # protect literal backslash
  s="${s//\\\"/\"}"
  s="${s//\\n/$'\n'}"
  s="${s//$'\x01'/\\}"
  printf '%s' "$s"
}

# _pmo_strip_quotes_and_unescape <raw-value>
# Strip a trailing `# comment`, trim whitespace, peel matching quotes, and
# unescape if the value was double-quoted. Prints the result.
_pmo_strip_quotes_and_unescape() {
  local v="$1"
  # Strip trailing inline comment (naive: # preceded by whitespace, outside quotes).
  # We accept the simplification: config.yaml never contains '#' inside a value.
  if [[ "$v" == *"#"* && "$v" != \"*\" && "$v" != \'*\' ]]; then
    v="${v%%#*}"
  fi
  # Trim whitespace.
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  if [[ ${#v} -ge 2 && "${v:0:1}" == '"' && "${v: -1}" == '"' ]]; then
    v="${v:1:${#v}-2}"
    _pmo_unescape_double_quoted "$v"
    return
  fi
  if [[ ${#v} -ge 2 && "${v:0:1}" == "'" && "${v: -1}" == "'" ]]; then
    v="${v:1:${#v}-2}"
    # Single-quoted: only '' → ' escape exists in YAML.
    printf '%s' "${v//\'\'/\'}"
    return
  fi
  printf '%s' "$v"
}

# _pmo_yaml_top <file> <key>
# Print the raw value of a top-level `key: value` line (value only, trimmed).
# Returns empty string if the key is absent or has no inline value.
_pmo_yaml_top() {
  local file="$1" key="$2"
  awk -v k="$key" '
    /^[[:space:]]*#/ { next }
    $0 ~ "^"k":" {
      sub("^"k":[[:space:]]*", "")
      print
      exit
    }
  ' "$file"
}

# _pmo_yaml_nested <file> <parent> <child>
# Print the raw value of `child: value` nested under a top-level `parent:` key.
# Any indentation under the parent is accepted; the block ends when a new
# top-level (non-indented, non-comment) line appears.
_pmo_yaml_nested() {
  local file="$1" parent="$2" child="$3"
  awk -v p="$parent" -v c="$child" '
    /^[[:space:]]*#/ { next }
    !in_block && $0 ~ "^"p":[[:space:]]*$" { in_block=1; next }
    in_block && /^[^[:space:]#]/ { in_block=0 }
    in_block && $0 ~ "^[[:space:]]+"c":" {
      sub("^[[:space:]]+"c":[[:space:]]*", "")
      print
      exit
    }
  ' "$file"
}

# _pmo_yaml_list <file> <key>
# Print space-separated list items for a top-level `key:` that opens a block
# sequence of scalar items (`  - value`). Quoted items are unquoted.
_pmo_yaml_list() {
  local file="$1" key="$2"
  local items=()
  local line
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    items+=("$(_pmo_strip_quotes_and_unescape "$line")")
  done < <(
    awk -v k="$key" '
      /^[[:space:]]*#/ { next }
      !in_list && $0 ~ "^"k":[[:space:]]*$" { in_list=1; next }
      in_list && /^[^[:space:]#-]/ { in_list=0 }
      in_list && /^[[:space:]]*-[[:space:]]/ {
        sub("^[[:space:]]*-[[:space:]]+", "")
        print
      }
    ' "$file"
  )
  local out="${items[*]}"
  printf '%s' "$out"
}

pmo_load_config() {
  local config_file="${1:-${PMO_SKILL_DIR:-.claude/skills/pmo}/config.yaml}"
  if [[ ! -f "$config_file" ]]; then
    echo "pmo: config file not found: $config_file" >&2
    return 2
  fi

  # Validate schema.
  local version
  version=$(_pmo_strip_quotes_and_unescape "$(_pmo_yaml_top "$config_file" schema_version)")
  if [[ "$version" != "1" ]]; then
    echo "pmo: unsupported config schema_version (got $version, expected 1)" >&2
    return 2
  fi

  export PMO_REPO_ROOT
  PMO_REPO_ROOT=$(_pmo_strip_quotes_and_unescape "$(_pmo_yaml_top "$config_file" repo_root)")

  export PMO_PHASES_DIR
  PMO_PHASES_DIR=$(_pmo_strip_quotes_and_unescape "$(_pmo_yaml_top "$config_file" phases_dir)")

  export PMO_PHASE_STATES
  PMO_PHASE_STATES=$(_pmo_yaml_list "$config_file" phase_states)

  export PMO_PHASE_NUMBER_REGEX
  PMO_PHASE_NUMBER_REGEX=$(_pmo_strip_quotes_and_unescape "$(_pmo_yaml_top "$config_file" phase_number_regex)")

  # Derive a bash-compatible POSIX ERE by stripping Python/PCRE-style
  # non-capturing-group prefixes "(?:". bash [[ =~ ]] and BSD sed -E cannot
  # parse "(?:...)" but can parse the same regex with plain "(...)". The
  # semantic shift (non-capturing -> capturing) is harmless because we only
  # ever reference BASH_REMATCH[1], which remains the outermost group.
  export PMO_PHASE_NUMBER_REGEX_BASH
  PMO_PHASE_NUMBER_REGEX_BASH="${PMO_PHASE_NUMBER_REGEX//\(\?:/(}"

  export PMO_CONTEXT_MD_GLOB
  PMO_CONTEXT_MD_GLOB=$(_pmo_strip_quotes_and_unescape "$(_pmo_yaml_top "$config_file" context_md_glob)")

  export PMO_PLAN_CHECKER_MARKER
  PMO_PLAN_CHECKER_MARKER=$(_pmo_strip_quotes_and_unescape "$(_pmo_yaml_top "$config_file" plan_checker_marker)")

  # Pre-set env override is honored (D-19 graceful-degrade test uses this).
  : "${PMO_STATE_MD:=$(_pmo_strip_quotes_and_unescape "$(_pmo_yaml_nested "$config_file" drift_sources state_md)")}"
  export PMO_STATE_MD

  export PMO_MEMORY_MD
  PMO_MEMORY_MD=$(_pmo_strip_quotes_and_unescape "$(_pmo_yaml_nested "$config_file" drift_sources memory_md)")

  export PMO_ROADMAP_MD
  PMO_ROADMAP_MD=$(_pmo_strip_quotes_and_unescape "$(_pmo_yaml_nested "$config_file" drift_sources roadmap_md)")

  export PMO_STALE_DAYS
  PMO_STALE_DAYS=$(_pmo_strip_quotes_and_unescape "$(_pmo_yaml_nested "$config_file" thresholds stale_days)")

  export PMO_ADVISORY_ENABLED
  local adv
  adv=$(_pmo_strip_quotes_and_unescape "$(_pmo_yaml_top "$config_file" advisory_enabled)")
  PMO_ADVISORY_ENABLED=$(printf '%s' "$adv" | tr '[:upper:]' '[:lower:]')

  export PMO_GIT_LOG_STRATEGY
  PMO_GIT_LOG_STRATEGY=$(_pmo_strip_quotes_and_unescape "$(_pmo_yaml_top "$config_file" git_log_strategy)")
}
