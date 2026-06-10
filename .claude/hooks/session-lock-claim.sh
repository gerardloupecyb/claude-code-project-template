#!/bin/bash
# session-lock-claim.sh — SessionStart hook (D-B4 amendé)
#
# Claim the per-branch session lock atomically OR warn-and-exit-0 on
# collision. NON-BLOCKING per Claude Code spec — SessionStart hooks may
# not block session start. The blocking enforcement happens in
# session-lock-enforce.sh on the first user prompt.
#
# Exit semantics:
#   0  always (success, override, fail-safe, or active-collision warn)
#  77  never (skip is exit 0 with a stderr line — keeps tooling consistent)
#
# Critical invariants (D-B13):
#   - Every error path → failsafe_exit (exit 0)
#   - On TOCTOU race (lockdir present, lock.yml missing) → fail-safe, do NOT reap
#   - On active collision (different fresh session) → warn, exit 0 (NOT exit 2)

set -u    # no `set -e` — incompatible with fail-safe

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source helper — fail-safe if missing (D-B13)
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

# Atomic claim attempt
if claim_lock "$LOCK_DIR" "$SESSION_ID"; then
  exit 0   # acquired
fi

# Lockdir already exists — read existing session_id and classify.
EXISTING_SID=$(read_lock_session_id "$LOCK_FILE")
if [ -z "$EXISTING_SID" ]; then
  # TOCTOU: lockdir present but lock.yml absent (claim-in-progress, Gemini F3)
  failsafe_exit "lockdir exists, lock.yml missing — TOCTOU race, do not reap"
fi

if [ "$EXISTING_SID" = "$SESSION_ID" ]; then
  # Re-resume of our own lock — heartbeat to refresh mtime.
  heartbeat_lock "$LOCK_DIR" "$SESSION_ID"
  exit 0
fi

# Different session — check stale.
if is_lock_stale "$LOCK_DIR"; then
  rm -rf "$LOCK_DIR" 2>/dev/null || failsafe_exit "stale cleanup failed"
  claim_lock "$LOCK_DIR" "$SESSION_ID" || failsafe_exit "post-stale claim failed"
  exit 0
fi

# Active collision — print D-B5 warn message to stderr (NON-BLOCKING).
STARTED=$(grep '^started:' "$LOCK_FILE" 2>/dev/null | head -n 1 | sed 's/^started:[[:space:]]*//;s/^"//;s/"$//')
LAST_SEEN=$(grep '^last_seen:' "$LOCK_FILE" 2>/dev/null | head -n 1 | sed 's/^last_seen:[[:space:]]*//;s/^"//;s/"$//')
EXISTING_WT=$(grep '^worktree:' "$LOCK_FILE" 2>/dev/null | head -n 1 | sed 's/^worktree:[[:space:]]*//;s/^"//;s/"$//')

cat >&2 <<EOF
⚠ Collision potentielle.
Cette branche est déjà claimée par session ${EXISTING_SID}
démarrée à ${STARTED}, dernière activité ${LAST_SEEN}.
Worktree owner: ${EXISTING_WT}.

Le prochain user prompt sera bloqué si la collision persiste.
Options :
  a) Ouvrir un worktree isolé sur une nouvelle branche : git worktree add ../loupe-sandbox-{slug} -b sandbox/{slug}
  b) Si tu es sûr que l'autre session est morte : rm -rf ${LOCK_DIR}
  c) Override one-shot : SKIP_SESSION_LOCK=1 claude
EOF
exit 0   # NON-BLOCKING per Claude Code SessionStart spec
