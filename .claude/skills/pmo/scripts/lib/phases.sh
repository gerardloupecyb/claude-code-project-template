#!/usr/bin/env bash
# lib/phases.sh — filesystem + git scanning of phase directories.
#
# All functions assume config.sh has been sourced and pmo_load_config has
# been called (PMO_REPO_ROOT, PMO_PHASES_DIR, PMO_PHASE_NUMBER_REGEX set).
set -euo pipefail

# pmo_list_phase_dirs <state>
#
# Given a state name (active | planned | complete), print one absolute phase
# directory path per line, sorted. Missing state directory is NOT an error
# (the skill must degrade gracefully on projects that use a subset of states).
pmo_list_phase_dirs() {
  local state="$1"
  local state_dir="$PMO_REPO_ROOT/$PMO_PHASES_DIR/$state"
  [[ -d "$state_dir" ]] || return 0
  find "$state_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort
}

# pmo_extract_phase_number <basename>
#
# Extract the leading version-like token from a phase directory basename using
# PMO_PHASE_NUMBER_REGEX_BASH. Prints the captured token or empty string if no match.
# Examples:
#   "1000-email-security-..."      -> "1000"
#   "24.1-upstream-source-watcher" -> "24.1"
#
# Implementation note: the config.yaml regex uses Python/PCRE-style
# non-capturing groups "(?:...)", which BSD sed -E rejects and bash
# [[ =~ ]] does not understand. config.sh strips those at load time and
# exports the result as PMO_PHASE_NUMBER_REGEX_BASH — a POSIX ERE that
# bash can evaluate directly. This keeps config.yaml as the single FORGE
# portability surface while avoiding python3 invocation overhead in the
# hot path (this function is called 100+ times per run; each python3
# cold start is ~40ms and dominates total latency). See Plan 02 § Deviations.
pmo_extract_phase_number() {
  local base="$1"
  if [[ "$base" =~ $PMO_PHASE_NUMBER_REGEX_BASH ]]; then
    printf '%s' "${BASH_REMATCH[1]:-}"
  fi
}

# pmo_last_commit_iso <phase_dir>
#
# Return the ISO-8601 date (commit committer date, %cI) of the last git commit
# touching the given phase directory. Prints "never" if no commit found.
# The path passed to git is always a literal argument (not via shell), so
# metacharacters in directory names are safe.
pmo_last_commit_iso() {
  local phase_dir="$1"
  local rel="${phase_dir#"$PMO_REPO_ROOT"/}"
  local iso
  iso=$(git -C "$PMO_REPO_ROOT" log -1 --format=%cI -- "$rel" 2>/dev/null || true)
  if [[ -z "$iso" ]]; then
    printf 'never'
  else
    printf '%s' "$iso"
  fi
}

# pmo_days_since_iso <iso_date>
#
# Return the number of whole days between the given ISO-8601 date and now.
# Special values:
#   "never"             -> 999999  (treated as ancient)
#   malformed iso date  -> 999999  (tolerated, does not abort under set -e)
#
# Implementation: strip the ISO to its YYYY-MM-DD prefix and use BSD/GNU
# `date -j -f` (macOS) or `date -d` (Linux) to convert to epoch. No python3
# in the hot path — this matters because the function is called 100+ times
# per run and python3 cold-start (~40ms) dominates total latency.
pmo_days_since_iso() {
  local iso="$1"
  if [[ "$iso" == "never" ]]; then
    printf '999999'
    return 0
  fi
  # Only the date portion is needed for whole-day math.
  local date_prefix="${iso:0:10}"
  # Validate format: YYYY-MM-DD
  if [[ ! "$date_prefix" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    printf '999999'
    return 0
  fi
  local then_epoch now_epoch
  # BSD date (macOS) path first, then GNU date (Linux) fallback.
  then_epoch=$(date -j -f "%Y-%m-%d" "$date_prefix" +%s 2>/dev/null \
               || date -d "$date_prefix" +%s 2>/dev/null \
               || echo "")
  if [[ -z "$then_epoch" ]]; then
    printf '999999'
    return 0
  fi
  now_epoch=$(date +%s)
  printf '%d' $(( (now_epoch - then_epoch) / 86400 ))
}
