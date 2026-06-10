#!/bin/bash
# lib/session-lock.sh — sourceable helper for Phase 24.9 session isolation
#
# Provides fourteen functions used by the SessionStart, UserPromptSubmit, and
# PreToolUse hooks that enforce one-session-per-branch isolation.
#
# Critical invariants (do NOT remove without architectural review):
#
#   D-B1  branch-only injective slug — `feature/foo` and `feature-foo` MUST map
#         to DISTINCT slugs. Implementation uses `tr / .` (forward-slash → dot)
#         since `.` is not a legal character in git refnames per git refname
#         rules — this guarantees injectivity while keeping the slug filename-
#         safe.
#   D-B2  YAML lock file is written atomically (tmp + mv) with strict field
#         validation; session_id may not contain quotes, backslashes, or
#         newlines.
#   D-B6  POSIX-extended-regex detection of `git commit` that distinguishes
#         it from `git commit-tree` and `git commit-graph`.
#   D-B8  Stale liveness uses lockdir mtime (`find -mmin +120`). NO pid,
#         NO `kill -0`. Heartbeats touch the lockdir at each prompt.
#   D-B10 Repo-main resolution uses `git rev-parse --git-common-dir` so the
#         lockdir parent path is invariant across linked worktrees.
#   D-B12 Override: setting `SKIP_SESSION_LOCK=1` short-circuits the helper
#         (one-shot escape hatch).
#   D-B13 FAIL-SAFE EVERYWHERE — every error path ends in `failsafe_exit`
#         which calls `exit 0`. The helper MUST NEVER exit 2. `set -e` is
#         deliberately NOT used (incompatible with fail-safe semantics).
#   D-B14 Atomic claim with grace period — `claim_lock` mkdir's the lockdir,
#         then writes lock.yml via tmp+mv. `is_lockdir_orphan` distinguishes a
#         claim-in-progress (lockdir <30s old, no lock.yml) from an orphan
#         (lockdir ≥30s old, no lock.yml).
#
# This file is sourced; do not invoke directly. Callers must export
# PROJECT_ROOT before sourcing (typically from CLAUDE_PROJECT_DIR).

# ---------------------------------------------------------------------------
# === Failsafe — D-B13 ===
# Call from any error path. Hooks must NEVER exit 2 from an error path here.
# Optional debug log to stderr when SESSION_LOCK_DEBUG is non-empty.
# ---------------------------------------------------------------------------
failsafe_exit() {
  if [ -n "${SESSION_LOCK_DEBUG:-}" ]; then
    echo "session-lock: failsafe (${1:-no-reason})" >&2
  fi
  exit 0
}

# ---------------------------------------------------------------------------
# === Override — D-B12 ===
# `SKIP_SESSION_LOCK=1` is the documented one-shot escape hatch. When set,
# the helper exits 0 immediately so the surrounding hook becomes a no-op.
# ---------------------------------------------------------------------------
check_override() {
  if [ "${SKIP_SESSION_LOCK:-}" = "1" ]; then
    failsafe_exit "override SKIP_SESSION_LOCK=1"
  fi
}

# ---------------------------------------------------------------------------
# === Skip managed worktrees ===
# Skip the lock entirely when running inside Claude-managed or skill-managed
# worktrees (lifecycle is owned by Claude/Anthropic, not by us). See RESEARCH
# § 5 and parallel-worktree-discipline.md "Cas particulier".
# ---------------------------------------------------------------------------
skip_if_managed_worktree() {
  case "${PROJECT_ROOT:-}" in
    */.claude/worktrees/*|*/.worktrees/*)
      failsafe_exit "managed worktree — skip"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# === D-B10 — repo main resolution ===
# Returns the absolute path of the *main* repo (i.e. the parent of the common
# git dir). Invariant across linked worktrees: every worktree of the same
# repo resolves to the same value.
#
# Usage: REPO_MAIN=$(resolve_repo_main) || failsafe_exit "no repo main"
# ---------------------------------------------------------------------------
resolve_repo_main() {
  local cd_target="${1:-${PROJECT_ROOT:-$(pwd)}}"
  local common_dir
  common_dir=$(cd "$cd_target" 2>/dev/null && git rev-parse --git-common-dir 2>/dev/null) || return 1
  [ -z "$common_dir" ] && return 1
  local resolved
  if [ "${common_dir#/}" = "$common_dir" ]; then
    # Relative path (e.g. ".git" or "../foo/.git") — resolve from the cd target
    resolved=$(cd "$cd_target" 2>/dev/null && cd "$common_dir/.." 2>/dev/null && pwd) || return 1
  else
    # Absolute path — parent is the worktree root for the common dir
    resolved=$(cd "$common_dir/.." 2>/dev/null && pwd) || return 1
  fi
  [ -z "$resolved" ] && return 1
  echo "$resolved"
}

# ---------------------------------------------------------------------------
# === D-B1 — branch-only injective slug ===
# Slugify the current branch name into a filename-safe, INJECTIVE token.
#
# Mapping:
#   `/`    → `.`   (dot is forbidden in git refnames per git-check-ref-format,
#                   so `feature/foo` (→ `feature.foo`) cannot collide with
#                   any plain branch name like `feature-foo` or `feature.foo`
#                   itself — the latter is rejected by git)
#   space  → `_`
#   uppercase → lowercase (filesystem-case-insensitive safety on Darwin)
#
# Detached HEAD: `DETACHED-<short-sha>` so two detached states on different
# commits do not collide.
#
# Returns the slug on stdout. On failure, returns 1 with empty stdout — caller
# must handle via failsafe_exit.
# ---------------------------------------------------------------------------
compute_branch_slug() {
  local branch
  branch=$(cd "${PROJECT_ROOT:-$(pwd)}" 2>/dev/null && git branch --show-current 2>/dev/null) || return 1
  if [ -z "$branch" ]; then
    local short
    short=$(cd "${PROJECT_ROOT:-$(pwd)}" 2>/dev/null && git rev-parse --short HEAD 2>/dev/null) || short="unknown"
    branch="DETACHED-${short}"
  fi
  # `tr / .` is the injectivity guarantee (dot is illegal in branch names);
  # space → underscore handles refs that quoted (rare but possible).
  printf '%s' "$branch" | tr '/' '.' | tr ' ' '_' | tr '[:upper:]' '[:lower:]'
}

# ---------------------------------------------------------------------------
# === Compute the lockdir parent — `<repo-main>/.session-locks` ===
# The directory itself is created on demand by `claim_lock`.
# ---------------------------------------------------------------------------
compute_lock_dir() {
  local repo_main
  repo_main=$(resolve_repo_main) || { failsafe_exit "no repo main for compute_lock_dir"; }
  echo "${repo_main}/.session-locks"
}

# ---------------------------------------------------------------------------
# === Read session_id field — fail-safe ===
# Returns the session_id stored in the lock file, stripping surrounding
# quotes. On any failure, returns empty string (caller treats as TOCTOU).
# ---------------------------------------------------------------------------
read_lock_session_id() {
  local lock_file="$1"
  if [ ! -f "$lock_file" ]; then
    echo ""
    return 0
  fi
  local sid
  sid=$(grep '^session_id:' "$lock_file" 2>/dev/null \
        | head -n 1 \
        | sed 's/^session_id:[[:space:]]*//' \
        | sed 's/^"//;s/"$//')
  echo "$sid"
}

# ---------------------------------------------------------------------------
# === D-B2 — YAML write with validated/escaped fields ===
# Validates the session_id, then writes the YAML atomically via tmp + mv.
# All string fields are double-quoted. Any failure → failsafe_exit.
# ---------------------------------------------------------------------------
write_lock_yml() {
  local lock_file="$1"
  local session_id="$2"
  local started="$3"
  local last_seen="$4"
  local worktree="$5"
  local branch="$6"

  # Validate session_id: non-empty, no quotes, no newlines, no backslashes.
  if [ -z "$session_id" ]; then
    failsafe_exit "write_lock_yml: empty session_id"
  fi
  case "$session_id" in
    *\"*|*\\*|*$'\n'*|*$'\r'*)
      failsafe_exit "write_lock_yml: forbidden char in session_id"
      ;;
  esac

  local parent_dir
  parent_dir=$(dirname "$lock_file")
  [ -d "$parent_dir" ] || mkdir -p "$parent_dir" 2>/dev/null || failsafe_exit "write_lock_yml: mkdir parent failed"

  local tmp="${lock_file}.tmp.$$"
  cat > "$tmp" <<EOF
session_id: "${session_id}"
started: "${started}"
last_seen: "${last_seen}"
worktree: "${worktree}"
branch: "${branch}"
EOF
  if [ ! -s "$tmp" ]; then
    rm -f "$tmp" 2>/dev/null
    failsafe_exit "write_lock_yml: empty tmp"
  fi
  if ! mv "$tmp" "$lock_file" 2>/dev/null; then
    rm -f "$tmp" 2>/dev/null
    failsafe_exit "write_lock_yml: mv failed"
  fi
}

# ---------------------------------------------------------------------------
# === D-B8 — mtime-based stale detection ===
# Stale := lockdir mtime > 120 minutes (no heartbeat touch in 2 hours). The
# heartbeat is written by UserPromptSubmit; if no prompt has fired in 2h, we
# treat the session as dead.
#
# Returns 0 (true) if stale, 1 (false) if fresh or non-existent.
# ---------------------------------------------------------------------------
is_lock_stale() {
  local lock_dir="$1"
  [ -d "$lock_dir" ] || return 1
  if find "$lock_dir" -maxdepth 0 -mmin +120 2>/dev/null | grep -q .; then
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# === D-B14 — empty-lockdir orphan detection ===
# A lockdir with no lock.yml inside has two possible interpretations:
#   (a) Claim-in-progress: another session just mkdir'd and is about to mv
#       lock.yml into place. Grace window = 30 seconds.
#   (b) Crash orphan: a previous session died between mkdir and mv. After 30s
#       it is safe to reclaim.
#
# Returns 0 (orphan, reclaim allowed) when:
#   - lockdir exists
#   - lock.yml absent
#   - lockdir mtime ≥ 30 seconds old
# Otherwise returns 1 (treat as fresh / claim-in-progress; do not reap).
# ---------------------------------------------------------------------------
is_lockdir_orphan() {
  local lock_dir="$1"
  [ -d "$lock_dir" ] || return 1
  if [ -f "${lock_dir}/lock.yml" ]; then
    return 1
  fi
  # mtime older than 30 seconds → orphan. Cross-platform stat (BSD/macOS + GNU).
  local mtime now age
  mtime=$(stat -f %m "$lock_dir" 2>/dev/null) \
    || mtime=$(stat -c %Y "$lock_dir" 2>/dev/null) \
    || return 1
  now=$(date +%s 2>/dev/null) || return 1
  age=$((now - mtime))
  [ "$age" -ge 30 ]
}

# ---------------------------------------------------------------------------
# === Atomic claim via mkdir ===
# (1) Ensure parent exists.
# (2) `mkdir lockdir` — atomic on a single filesystem.
# (3) Write lock.yml via write_lock_yml (which itself uses tmp + mv).
# Returns 0 on successful claim, 1 if the lockdir already existed.
# ---------------------------------------------------------------------------
claim_lock() {
  local lock_dir="$1"
  local session_id="$2"

  local parent
  parent=$(dirname "$lock_dir")
  mkdir -p "$parent" 2>/dev/null || failsafe_exit "claim_lock: parent mkdir failed"

  if mkdir "$lock_dir" 2>/dev/null; then
    local now
    now=$(date -u +%FT%TZ 2>/dev/null) || now="1970-01-01T00:00:00Z"
    local branch_name
    branch_name=$(cd "${PROJECT_ROOT:-$(pwd)}" 2>/dev/null && git branch --show-current 2>/dev/null)
    [ -z "$branch_name" ] && branch_name="(detached)"
    write_lock_yml "${lock_dir}/lock.yml" "$session_id" "$now" "$now" "${PROJECT_ROOT:-}" "$branch_name"
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# === Heartbeat ===
# Touch the lockdir (refreshes mtime — the liveness signal) and rewrite
# lock.yml with an updated last_seen field. The original `started` and
# `worktree` are preserved across heartbeats.
# ---------------------------------------------------------------------------
heartbeat_lock() {
  local lock_dir="$1"
  local session_id="$2"

  if [ ! -d "$lock_dir" ]; then
    failsafe_exit "heartbeat: lockdir vanished"
  fi
  touch "$lock_dir" 2>/dev/null || failsafe_exit "heartbeat: touch failed"

  local lock_file="${lock_dir}/lock.yml"
  if [ ! -f "$lock_file" ]; then
    # Nothing to update — touch already refreshed mtime.
    return 0
  fi

  local now started worktree branch
  now=$(date -u +%FT%TZ 2>/dev/null) || now="1970-01-01T00:00:00Z"
  started=$(grep '^started:' "$lock_file" 2>/dev/null | head -n 1 | sed 's/^started:[[:space:]]*//;s/^"//;s/"$//')
  worktree=$(grep '^worktree:' "$lock_file" 2>/dev/null | head -n 1 | sed 's/^worktree:[[:space:]]*//;s/^"//;s/"$//')
  branch=$(grep '^branch:' "$lock_file" 2>/dev/null | head -n 1 | sed 's/^branch:[[:space:]]*//;s/^"//;s/"$//')
  [ -z "$started" ] && started="$now"
  [ -z "$worktree" ] && worktree="${PROJECT_ROOT:-}"
  [ -z "$branch" ] && branch=$(cd "${PROJECT_ROOT:-$(pwd)}" 2>/dev/null && git branch --show-current 2>/dev/null)
  [ -z "$branch" ] && branch="(detached)"

  write_lock_yml "$lock_file" "$session_id" "$started" "$now" "$worktree" "$branch"
}

# ---------------------------------------------------------------------------
# === Read session_id from stdin JSON payload ===
# Hooks receive a JSON envelope on stdin (Claude Code spec). Try jq first,
# then python3, then fall back to empty string. Never errors out — caller
# treats empty as "no session_id" (which is itself a fail-safe path).
# ---------------------------------------------------------------------------
parse_session_id_from_stdin() {
  local input="$1"
  local sid
  sid=$(printf '%s' "$input" | jq -r '.session_id // ""' 2>/dev/null)
  if [ -z "$sid" ] || [ "$sid" = "null" ]; then
    sid=$(printf '%s' "$input" | python3 -c "import json,sys
try:
    d=json.load(sys.stdin)
    print(d.get('session_id','') or '')
except Exception:
    print('')
" 2>/dev/null)
  fi
  [ "$sid" = "null" ] && sid=""
  echo "$sid"
}

# ---------------------------------------------------------------------------
# === D-B6 — POSIX regex detection of `git commit` ===
# Matches all real `git commit` invocation shapes while excluding plumbing
# commands like `git commit-tree` and `git commit-graph`.
#
# Match anchors:
#   - start of string OR a shell separator (`;`, `&&`, `|`, etc.) OR whitespace
#   - optional env-var prefix:    env FOO=bar git ...
#   - optional binary path:       /usr/bin/git ...
#   - optional `git -c key=val`:  any number of flag/value pairs before the
#                                 subcommand
#   - the subcommand itself MUST be `commit` followed by whitespace OR end of
#     string (NOT followed by `-`, which would match commit-tree/-graph).
#
# Returns 0 (true) if the command is a `git commit`, 1 otherwise.
# ---------------------------------------------------------------------------
is_git_commit_invocation() {
  local cmd="$1"
  # Build the regex piece by piece for readability:
  #   (^|[\s;&|])                  separator before the invocation
  #   (env\s+[^;&|]*\s+)?          optional env-var prefix
  #   (/[^[:space:]]*/)?           optional absolute path prefix
  #   git                          the binary (literal)
  #   (\s+-[a-zA-Z]\S*|\s+--\S+|\s+-c\s+\S+)*   any number of flags
  #   \s+commit                    the subcommand
  #   ($|[[:space:]])              terminator — NOT a hyphen
  #
  # POSIX ERE doesn't support `\s`, so use [[:space:]].
  local re
  re='(^|[[:space:];&|])([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)*'
  re="${re}(env[[:space:]]+([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)+)?"
  re="${re}(/[^[:space:]]+/)?git([[:space:]]+(-[A-Za-z][^[:space:]]*|--[A-Za-z][^[:space:]]*|-c[[:space:]]+[^[:space:]]+))*[[:space:]]+commit([[:space:]]|$)"
  if printf '%s' "$cmd" | grep -qE "$re"; then
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# End of session-lock.sh — sourceable, no top-level side effects.
# ---------------------------------------------------------------------------
