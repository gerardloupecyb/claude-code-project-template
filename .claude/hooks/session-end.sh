#!/bin/bash
# session-end.sh — SessionEnd hook (D-B7 amendé)
#
# Best-effort cleanup of our own lock when the session ends. SAFETY:
# remove the lockdir ONLY when the recorded session_id matches ours.
# Never delete a lock owned by another session (defensive — if cleanup
# fires for the wrong session, mtime-based stale reaping in
# session-lock-enforce.sh handles it eventually).
#
# Exit semantics:
#   0  always (success, override, fail-safe, no-op, foreign lock)
#
# Critical invariants (D-B13):
#   - Every error path → failsafe_exit (exit 0)
#   - Foreign lock (different session_id) → DO NOT TOUCH, exit 0

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

LOCKS_PARENT=$(compute_lock_dir) || failsafe_exit "no lock dir"
BRANCH_SLUG=$(compute_branch_slug) || failsafe_exit "no branch slug"
[ -z "$BRANCH_SLUG" ] && failsafe_exit "empty branch slug"
LOCK_DIR="${LOCKS_PARENT}/${BRANCH_SLUG}"
LOCK_FILE="${LOCK_DIR}/lock.yml"

# Lock missing — nothing to clean.
[ -f "$LOCK_FILE" ] || exit 0

EXISTING_SID=$(read_lock_session_id "$LOCK_FILE")
# Parse fail → don't touch (safety; mtime stale-reap will handle later).
[ -z "$EXISTING_SID" ] && exit 0

# Only clean up if the lock is ours.
if [ "$EXISTING_SID" = "$SESSION_ID" ]; then
  rm -rf "$LOCK_DIR" 2>/dev/null || failsafe_exit "cleanup rm failed"
fi
# Foreign lock → silent no-op (do NOT touch — safety).
exit 0
