#!/bin/bash
# pre-tool-use-git-commit.sh — PreToolUse Bash hook (D-B6 amendé + D-B8 amendment)
#
# Settings.json matcher = "Bash" (no `if`). This hook runs on EVERY Bash tool
# call and decides internally whether the command is a `git commit`. The
# regex detection covers all variants (cd && git commit, env … git commit,
# /usr/bin/git commit, git -c x commit) while excluding plumbing
# (commit-tree, commit-graph). See is_git_commit_invocation in
# lib/session-lock.sh.
#
# D-B8 amendment (Codex round-2 P1.3): heartbeat FIRST, before regex
# detection. Long Claude turns can exceed 2h between user prompts; heartbeat
# on every Bash call ensures our own lock stays fresh and is not reaped by
# is_lock_stale on the next prompt.
#
# Exit semantics:
#   0  not a git commit / our own session / stale (will be reaped) / fail-safe
#   2  active collision — git commit blocked
#
# Critical invariants (D-B13):
#   - Every error path → failsafe_exit (exit 0). Only the documented
#     "active collision on git commit" branch is allowed to exit 2.
#   - Lock missing → fail-safe (don't block legitimate commits when our own
#     state is unrecoverable).

set -u    # no `set -e`

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LIB="${SCRIPT_DIR}/lib/session-lock.sh"
[ -f "$LIB" ] || { exit 0; }
# shellcheck source=lib/session-lock.sh
source "$LIB"

trap 'failsafe_exit "trap unexpected error"' ERR

check_override
skip_if_managed_worktree

INPUT=$(cat)
SESSION_ID=$(parse_session_id_from_stdin "$INPUT")
[ -z "$SESSION_ID" ] && failsafe_exit "no session_id"

# Compute lock dir up-front so heartbeat (D-B8 amendment) can run BEFORE the
# regex detection. This covers turns > 2h.
LOCKS_PARENT=$(compute_lock_dir) || failsafe_exit "no lock dir"
BRANCH_SLUG=$(compute_branch_slug) || failsafe_exit "no branch slug"
[ -z "$BRANCH_SLUG" ] && failsafe_exit "empty branch slug"
LOCK_DIR="${LOCKS_PARENT}/${BRANCH_SLUG}"
LOCK_FILE="${LOCK_DIR}/lock.yml"

# === D-B8 amendment: heartbeat FIRST (Codex round-2 P1.3 long-turn coverage) ===
# If lock exists AND it is ours, refresh mtime so we are not reaped on the
# next UserPromptSubmit even if the human turn took > 2h.
if [ -d "$LOCK_DIR" ] && [ -f "$LOCK_FILE" ]; then
  HB_SID=$(read_lock_session_id "$LOCK_FILE")
  if [ -n "$HB_SID" ] && [ "$HB_SID" = "$SESSION_ID" ]; then
    touch "$LOCK_DIR" 2>/dev/null || :    # best-effort, never fail
  fi
fi

# Extract tool_input.command from stdin JSON
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
if [ -z "$COMMAND" ] || [ "$COMMAND" = "null" ]; then
  COMMAND=$(printf '%s' "$INPUT" | python3 -c "import json,sys
try:
    d=json.load(sys.stdin)
    print((d.get('tool_input') or {}).get('command','') or '')
except Exception:
    print('')
" 2>/dev/null) || COMMAND=""
fi

# Not a git commit invocation → exit 0 (heartbeat already done above).
if ! is_git_commit_invocation "$COMMAND"; then
  exit 0
fi

# It IS a git commit — verify lock ownership.
[ -f "$LOCK_FILE" ] || failsafe_exit "lock missing — don't block legitimate commit"

EXISTING_SID=$(read_lock_session_id "$LOCK_FILE")
[ -z "$EXISTING_SID" ] && failsafe_exit "no session_id in lock"

# Match → allow.
if [ "$EXISTING_SID" = "$SESSION_ID" ]; then
  exit 0
fi

# Mismatch — check stale (will be reaped on next prompt) → don't block this commit.
if is_lock_stale "$LOCK_DIR"; then
  exit 0
fi

# Active mismatch on git commit — BLOCK.
echo "⛔ git commit bloqué — collision détectée." >&2
echo "Cette branche est claimée par une autre session (${EXISTING_SID})." >&2
echo "Override : SKIP_SESSION_LOCK=1 claude" >&2
exit 2
