#!/bin/bash
# session-lock-enforce.sh — UserPromptSubmit hook (D-B11 amendé)
#
# This is the real enforcement point. On every user prompt:
#   - heartbeat our own lock (refresh mtime + last_seen)
#   - claim if no lock exists
#   - reap-and-claim if stale
#   - BLOCK with exit 2 on active collision (different fresh session)
#
# Exit semantics:
#   0  success / fail-safe / heartbeat / stale-reap / claim
#   2  active collision — prompt blocked
#
# Critical invariants (D-B13):
#   - Every error path → failsafe_exit (exit 0). Only the documented
#     "active collision" branch is allowed to exit 2.
#   - TOCTOU race (lockdir present, lock.yml absent) → fail-safe, do NOT reap.

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

# No lock at all → claim it.
if [ ! -d "$LOCK_DIR" ]; then
  claim_lock "$LOCK_DIR" "$SESSION_ID" || failsafe_exit "claim race lost"
  exit 0
fi

# Lockdir exists — read session_id.
EXISTING_SID=$(read_lock_session_id "$LOCK_FILE")
if [ -z "$EXISTING_SID" ]; then
  # TOCTOU race (Gemini F3) — do not reap, fail-safe.
  failsafe_exit "TOCTOU lockdir without yml"
fi

# Match → heartbeat.
if [ "$EXISTING_SID" = "$SESSION_ID" ]; then
  heartbeat_lock "$LOCK_DIR" "$SESSION_ID"
  exit 0
fi

# Mismatch — check stale before blocking.
if is_lock_stale "$LOCK_DIR"; then
  rm -rf "$LOCK_DIR" 2>/dev/null || failsafe_exit "stale cleanup rm failed"
  claim_lock "$LOCK_DIR" "$SESSION_ID" || failsafe_exit "post-stale claim failed"
  exit 0
fi

# Active collision — BLOCK with exit 2 (the real enforcement).
STARTED=$(grep '^started:' "$LOCK_FILE" 2>/dev/null | head -n 1 | sed 's/^started:[[:space:]]*//;s/^"//;s/"$//')
LAST_SEEN=$(grep '^last_seen:' "$LOCK_FILE" 2>/dev/null | head -n 1 | sed 's/^last_seen:[[:space:]]*//;s/^"//;s/"$//')
EXISTING_WT=$(grep '^worktree:' "$LOCK_FILE" 2>/dev/null | head -n 1 | sed 's/^worktree:[[:space:]]*//;s/^"//;s/"$//')

cat >&2 <<EOF
⛔ Collision détectée — prompt bloqué.
Cette branche est déjà claimée par session ${EXISTING_SID}
démarrée à ${STARTED}, dernière activité ${LAST_SEEN}.
Worktree owner: ${EXISTING_WT}.

Options :
  a) Ouvrir un worktree isolé : git worktree add ../loupe-sandbox-{slug} -b sandbox/{slug}
  b) Si tu es sûr que l'autre session est morte : rm -rf ${LOCK_DIR}
  c) Override one-shot : SKIP_SESSION_LOCK=1 claude
EOF
exit 2
