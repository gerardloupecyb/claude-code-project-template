#!/bin/bash
# Pre-tool-use hook: enforce skill gate (DATA-DRIVEN — sources .claude/gate.config.json)
# Blocks Write/Edit/MultiEdit/Bash on protected-domain files if .skill-locks/{domain} marker is absent.
# Domains, SCAG ecosystems, and Lessons mappings are read from gate.config.json — NO inline domain literals.
# See .claude/rules/skill-gate.md (its Domain Routing table is RENDERED from the same gate.config.json).
# Fires for every tool use. Exits 0 = allow, exits 2 = block with message.
#
# FAIL-OPEN (AC-2-3): on missing/malformed config the hook allows (exit 0) but LOUDLY — stdout+stderr
# warning + a one-line audit append wrapped `|| true` so the append can NEVER fail-CLOSE the hook.
# NEVER-SILENTLY-DISABLE (AC-2-2): SCAG (dep_ecosystems) is parsed independently of protected_domains AND
# falls back to a built-in default if the key is absent/empty — an empty protected_domains (legit greenfield)
# disables ONLY the domain skill-gate, never supply-chain protection.

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LOCKS_DIR="${PROJECT_ROOT}/.skill-locks"
GATE_CONFIG="${PROJECT_ROOT}/.claude/gate.config.json"

# Built-in universal SCAG default — used when dep_ecosystems is absent/empty so SCAG can never be
# silently disabled by a gutted-but-valid config (review F1/C-1, convergent BLOCKER).
SCAG_DEFAULT='\b(pip3?|uv)\s+(install|add)\b|\bnpm\s+(install|i)\b|\b(yarn|pnpm|bun)\s+add\b|\bclaude\s+mcp\s+add\b'

# Worktree fix: .skill-locks/ is gitignored so it won't exist in linked worktrees.
# Resolve locks from the main worktree instead. (gate.config.json is TRACKED, so it lives in each worktree.)
COMMON_GIT=$(cd "$PROJECT_ROOT" && git rev-parse --git-common-dir 2>/dev/null)
if [ -n "$COMMON_GIT" ] && [ "$COMMON_GIT" != ".git" ]; then
  LOCKS_DIR="$(dirname "$COMMON_GIT")/.skill-locks"
fi

# Shared gate-config chokepoint: ONE place validates file + JSON + shape/type + regex-compilability.
GATE_LIB="$(dirname "${BASH_SOURCE[0]}")/lib/gate-config.sh"
if [ -f "$GATE_LIB" ]; then
  . "$GATE_LIB"
else
  echo "⚠ GATE FAIL-OPEN (pre-tool-use): gate-config lib missing ($GATE_LIB) — skill-gate NOT enforced this call." >&2
  exit 0
fi

# Read tool name and input from stdin JSON — parse tool_name first with jq, fall back to python3
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")

# Only check Write, Edit, MultiEdit, Bash (for az rest / runbook operations)
case "$TOOL_NAME" in
  Write|Edit|MultiEdit|Bash) ;;
  *) exit 0 ;;
esac

# Parse tool_input only for relevant tools (deferred to avoid cost on every tool use)
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}' 2>/dev/null || echo "$INPUT" | python3 -c "import json,sys; print(json.dumps(json.load(sys.stdin).get('tool_input',{})))" 2>/dev/null || echo "{}")

# Extract file path or command for domain detection
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // .command // ""' 2>/dev/null || echo "$TOOL_INPUT" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(d.get('file_path', d.get('command', '')))
" 2>/dev/null || echo "")

# --- A2 RUNTIME FLOOR (Option-3 / AC-2-7). TRUST the write-time-validated config (validate-gate-config.sh
# runs in .githooks/pre-commit on the STAGED BLOB + CI). At runtime keep ONLY the minimal floor: present +
# valid JSON + array-type. Deep validation (regex-compilability, per-element non-emptiness, R3 vacuity) is
# WRITE-TIME ONLY — deliberately NOT re-run on every tool call (that per-call chokepoint was the Option-3
# removal). Fail-OPEN OBSERVABLY (exit 0 = allow) on a floor miss; an empty protected_domains:[] PASSES the
# floor so the always-on SCAG gate below still fires (AC-2-2 greenfield-still-protected).
gate_runtime_floor_ok "$GATE_CONFIG" || { gate_fail_open "pre-tool-use" "$GATE_CONFIG_REASON"; exit 0; }

# --- Domain skill-gate (data-driven from protected_domains) ---
# Records are NUL-delimited (process substitution, read -d '') so a field value containing a newline can
# never corrupt the stream (review HIGH). Fields are US-separated (); join() under jq keeps regex
# backslashes verbatim (@tsv would double them). The while loop runs in the MAIN shell (process
# substitution, NOT a pipe) so `exit 2` propagates and actually blocks.
# file_patterns checked for every gated tool; command_patterns checked for Bash only (mirrors pre-refactor).
while IFS=$'\037' read -r -d '' d_name d_marker d_fpat d_cpat d_skills d_lessons d_unlock; do
  [ -n "$d_marker" ] || continue
  matched=0
  # D2 (Option-3 seam): capture grep rc. rc 0 = match, rc 1 = no-match, rc>=2 = ERROR (a non-compiling
  # file/command_pattern in a dirty-tree config the write-time validator has not yet vetted). An rc>=2 is
  # routed to OBSERVABLE fail-open — NEVER swallowed as a silent no-match that would un-gate the domain.
  if [ -n "$d_fpat" ]; then
    printf '%s' "$FILE_PATH" | grep -qE "$d_fpat"; _gp_rc=$?
    [ "$_gp_rc" -ge 2 ] && { gate_fail_open "pre-tool-use" "uncompilable file_patterns for domain ${d_name}: ${d_fpat}"; exit 0; }
    [ "$_gp_rc" -eq 0 ] && matched=1
  fi
  if [ "$matched" -eq 0 ] && [ "$TOOL_NAME" = "Bash" ] && [ -n "$d_cpat" ]; then
    printf '%s' "$FILE_PATH" | grep -qE "$d_cpat"; _gp_rc=$?
    [ "$_gp_rc" -ge 2 ] && { gate_fail_open "pre-tool-use" "uncompilable command_patterns for domain ${d_name}: ${d_cpat}"; exit 0; }
    [ "$_gp_rc" -eq 0 ] && matched=1
  fi
  if [ "$matched" -eq 1 ] && [ ! -f "${LOCKS_DIR}/${d_marker}" ]; then
    echo "⛔ SKILL GATE BLOCKED — domain: ${d_name}"
    echo ""
    echo "You must invoke the required skill(s) and create the unlock marker before proceeding."
    echo ""
    echo "Required: ${d_skills}"
    echo "Unlock:   ${d_unlock}"
    echo ""
    echo "See .claude/rules/skill-gate.md for full instructions."
    exit 2
  fi
done < <(jq -j '.protected_domains[]? | ([(.name//""),(.marker//""),(.file_patterns//""),(.command_patterns//""),(.required_skills//""),(.lessons_domain//""),(.unlock//"")] | join("\u001f")) + "\u0000"' "$GATE_CONFIG" 2>/dev/null)

# --- SCAG gate: block package installs without prior supply-chain audit ---
# ALWAYS-ON (AC-2-2): built from dep_ecosystems, INDEPENDENT of protected_domains, with a built-in default
# so an empty/absent dep_ecosystems cannot silently disable it. An empty/greenfield protected_domains
# disables only the domain skill-gate above — it can NEVER silently kill SCAG here.
# Requires .skill-locks/scag-approved marker (created by /supply-chain-audit on APPROVE/CONDITIONAL).
# One-shot: marker is consumed (deleted) on first allowed install.
# See .claude/rules/supply-chain-audit.md and docs/architecture/forge/dependency-install-gate.md
if [ "$TOOL_NAME" = "Bash" ]; then
  # D2 always-on non-vacuity (AC-2-2 / AC-2-7): resolve the SCAG regex from dep_ecosystems with PER-MEMBER
  # vacuity detection — a single blank member would silently DROP one ecosystem's coverage from the join.
  # Any vacuous / empty / uncompilable case falls back to the full built-in SCAG_DEFAULT (gate STAYS ON,
  # every ecosystem covered), OBSERVABLE via gate_degraded. SCAG can NEVER be silently disabled.
  gate_resolve_scag "$GATE_CONFIG" "$SCAG_DEFAULT" "pre-tool-use"
  SCAG_RE="$GATE_ALWAYSON_RE"
  if printf '%s' "$FILE_PATH" | grep -qE "$SCAG_RE"; then
    SCAG_MARKER="${LOCKS_DIR}/scag-approved"
    if [ ! -f "$SCAG_MARKER" ]; then
      echo "⛔ SCAG GATE — package install blocked"
      echo ""
      echo "A supply-chain audit is required before installing external dependencies."
      echo ""
      echo "1. Clone/download the package to a temp dir"
      echo "2. Run: /supply-chain-audit /tmp/{pkg}-audit --package {name} --version {ver}"
      echo "3. On APPROVE or CONDITIONAL verdict:"
      echo "   mkdir -p .skill-locks && touch .skill-locks/scag-approved"
      echo "4. Re-run this install command"
      echo ""
      echo "Pre-approved (bypass SCAG): check .claude/allowlists/mcp-preapproved.json"
      echo "See .claude/rules/supply-chain-audit.md"
      exit 2
    fi
    # One-time approval: consume marker so next install requires a fresh audit
    rm -f "$SCAG_MARKER"
  fi
fi

# --- Lessons auto-surfacing (OPT-03, per D-03) ---
# Runs AFTER skill gate checks. Non-blocking: all in subshell with || true.
# Domain tag is derived from the SAME protected_domains (lessons_domain) — no inline domain literals.
# Uses a simple (file_patterns, lessons_domain) stream — both fields are single-line regex/tag values.
# Max 3 lines injected as additionalContext. Never blocks (no exit 2).
(
    LESSONS_FILE="${PROJECT_ROOT}/LESSONS.md"
    [ -f "$LESSONS_FILE" ] || exit 0

    # Only surface for Write/Edit/MultiEdit (already filtered above, but guard explicitly)
    case "$TOOL_NAME" in
        Write|Edit|MultiEdit) ;;
        *) exit 0 ;;
    esac

    # FILE_PATH already parsed above from tool_input
    [ -z "$FILE_PATH" ] && exit 0

    # Extract file stem (basename without extension)
    FILE_STEM=$(basename "$FILE_PATH" | sed 's/\.[^.]*$//')
    [ -z "$FILE_STEM" ] && exit 0

    # Skip self-reference
    case "$FILE_STEM" in
        LESSONS) exit 0 ;;
    esac

    # Determine domain tag: protected-domain lessons_domain (data-driven), else FORGE-universal generic map
    DOMAIN=""
    LESSONS_MAP=$(jq -r '.protected_domains[]? | [(.file_patterns//""),(.lessons_domain//"")] | join("\u001f")' "$GATE_CONFIG" 2>/dev/null)
    while IFS=$'\037' read -r l_fpat l_lessons; do
        [ -n "$l_lessons" ] || continue
        if [ -n "$l_fpat" ] && printf '%s' "$FILE_PATH" | grep -qE "$l_fpat"; then DOMAIN="$l_lessons"; break; fi
    done <<< "$LESSONS_MAP"
    if [ -z "$DOMAIN" ]; then
        case "$FILE_PATH" in
            */.planning/*|*.planning/*)  DOMAIN="process" ;;
        esac
    fi

    MATCHES=""

    # Match 1: file stem in lesson text (exact match priority, per D-03)
    if [ -n "$FILE_STEM" ]; then
        MATCHES=$(grep -B 1 -A 2 "$FILE_STEM" "$LESSONS_FILE" 2>/dev/null \
            | grep "^\*\*Faire\*\*" | head -2 | sed 's/\*\*Faire\*\* //' | cut -c1-120 || true)
    fi

    # Match 2: domain tag (fallback if no file stem match, per D-03)
    if [ -z "$MATCHES" ] && [ -n "$DOMAIN" ]; then
        MATCHES=$(grep -E -A 3 "^### \[(${DOMAIN})\]" "$LESSONS_FILE" 2>/dev/null \
            | grep "^\*\*Faire\*\*" | head -3 | sed 's/\*\*Faire\*\* //' | cut -c1-120 || true)
    fi

    # Emit max 3 lines as additionalContext (stdout)
    if [ -n "$MATCHES" ]; then
        echo "=== Lessons Reminder (auto-surfaced) ==="
        echo "$MATCHES" | head -3
        echo ""
    fi
) 2>/dev/null || true

exit 0
