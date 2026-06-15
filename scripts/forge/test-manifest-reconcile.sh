#!/usr/bin/env bash
# test-manifest-reconcile.sh — durable oracle for the Phase 22 step-1 manifest↔engine reconciliation.
#
# Encodes the boundary-spec discipline (gap register meta-fix): a manifest that drifts from reality is the
# root cause Phase 22 keeps hitting. These assertions FAIL LOUD when the manifest and the engine disagree,
# so the R1 class (a config/tool added under a watched namespace without being classified → forge-extract
# exit 3) and the R3 class (an allowlist that over-lists EXCLUDED skills) can never silently return.
#
# Checks:
#   1. manifest is valid JSON
#   2. skills_allowlist == (template ∪ template-structure) skills   (internal allowlist consistency)
#   3. no orphan in the extensible files-tier namespaces (.claude/*.json depth-1, scripts/forge/*.sh)
#   4. every non-project-specific tiers.files key has an existing source file
#   5. forge-extract --dry-run → exit 0, "0 orphans", "scrub PASS", gate.config sliced, sync-allowlist emitted
#
# Usage: scripts/forge/test-manifest-reconcile.sh [FORGE_OUT]   (FORGE_OUT default ../project-template-v2)
# Exit:  0 all pass | 1 any fail
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="$ROOT/.forge/extraction-manifest.json"
ENGINE="$ROOT/.forge/forge-extract.sh"
FORGE_OUT="${1:-$ROOT/../project-template-v2}"
PASS=0; FAIL=0
ok(){ printf '  ✓ %s\n' "$1"; PASS=$((PASS+1)); }
ko(){ printf '  ✗ %s\n' "$1" >&2; FAIL=$((FAIL+1)); }

echo "═══ manifest-reconcile oracle ═══"

# 1 — valid JSON
if jq -e . "$MANIFEST" >/dev/null 2>&1; then ok "manifest is valid JSON"; else ko "manifest INVALID JSON"; fi

# 2 — allowlist consistency (the R3/D-6 invariant, manifest-internal)
diff_al="$(comm -3 \
  <(jq -r '.skills_allowlist[]' "$MANIFEST" | sort -u) \
  <(jq -r '.tiers.skills | to_entries[] | select(.value=="template" or .value=="template-structure") | .key' "$MANIFEST" | sort -u))"
if [ -z "$diff_al" ]; then ok "skills_allowlist == template∪template-structure skills"
else ko "skills_allowlist drifts from tiers.skills:"; printf '%s\n' "$diff_al" >&2; fi

# 3 — files-tier extensible-namespace reconcile (mirrors the engine STEP-1 scan EXACTLY — R1 recurrence guard).
#     R4 (round 2): includes `.claude/*.json.template` so this durable oracle does NOT false-green when the
#     engine would exit-3 on an unclassified template (e.g. .claude/settings.json.template, Plan 04 AC-4-2).
orph=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ -n "$(jq -r --arg k "$f" '.tiers.files[$k] // empty' "$MANIFEST")" ] || orph="$orph $f"
done < <(cd "$ROOT" && git ls-files '.claude/*.json' '.claude/*.json.template' 'scripts/forge/*.sh' 2>/dev/null | awk -F/ '!($1==".claude" && NF>2)')
if [ -z "$orph" ]; then ok "no files-tier orphan (.claude/*.json, .claude/*.json.template, scripts/forge/*.sh classified)"
else ko "files-tier ORPHAN(s):$orph"; fi

# 4 — every shippable tiers.files key has a source
miss=""
while IFS= read -r key; do
  case "$key" in _*) continue ;; esac
  t="$(jq -r --arg k "$key" '.tiers.files[$k]' "$MANIFEST")"
  [ "$t" = "project-specific" ] && continue
  [ "$t" = "meta" ] && continue
  [ -f "$ROOT/$key" ] || miss="$miss $key"
done < <(jq -r '.tiers.files | keys[]' "$MANIFEST")
if [ -z "$miss" ]; then ok "every shippable tiers.files key has a source file"
else ko "tiers.files source(s) MISSING:$miss"; fi

# 5 — integration: dry-run is green end-to-end
if [ -d "$FORGE_OUT" ]; then
  LOG="$(mktemp)"
  bash "$ENGINE" "$FORGE_OUT" --dry-run >"$LOG" 2>&1; rc=$?
  grep -q '0 orphans' "$LOG"                                   && ok "dry-run: 0 orphans"        || ko "dry-run: orphan(s) found"
  grep -q 'SCRUB VERDICT: PASS' "$LOG"                         && ok "dry-run: scrub PASS"       || ko "dry-run: scrub did NOT pass"
  grep -q 'sliced .claude/gate.config.json' "$LOG"            && ok "dry-run: gate.config sliced" || ko "dry-run: gate.config NOT sliced"
  grep -q 'emitted .forge/sync-allowlist.json' "$LOG"         && ok "dry-run: sync-allowlist emitted" || ko "dry-run: sync-allowlist NOT emitted"
  [ "$rc" -eq 0 ]                                              && ok "dry-run: exit 0"           || ko "dry-run: exit $rc"
  rm -f "$LOG"
else
  ko "FORGE_OUT '$FORGE_OUT' absent — skipping the dry-run integration check (provide it as \$1)"
fi

echo "─────────────────────────────────"
echo "manifest-reconcile: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
