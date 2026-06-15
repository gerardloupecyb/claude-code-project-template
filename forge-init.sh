#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# forge-init.sh — manifest-driven FORGE project scaffold
# ============================================================================
# Evolved from init-project.sh (FORGE Phase 22 Plan 04, AC-4-1).
#
# The copy is DRIVEN by the forge-extract-derived `.forge/sync-allowlist.json`
# — the SAME allowlist sync-project.sh reads (single source of truth). Skills /
# rules / scattered files / hooks the golden does NOT export are absent from the
# allowlist → never copied. The old hardcoded copy lists — and their dead lineage
# (excluded skills + older-lineage rules that no longer exist in the golden) — are
# GONE BY CONSTRUCTION: not in the allowlist means not copied, no special-casing.
#
# Token resolution ({{PROJECT}} / {{project}} / {{TEMPLATE_REPO}} … across the
# copied tree) is the AC-4-7 resolver (added Task 2); the residual-token tripwire
# is AC-4-8 (Task 3). This file (Task 1) lays down the manifest-driven COPY +
# the fresh-scaffold generation; extracted tokens are left for the resolver.
#
# Usage:
#   ./forge-init.sh [--tier 1|2|3] "Project Name" carl_domain "kw1,kw2,kw3"
#
# Arguments:
#   --tier N        Adoption tier (Foundation=1 / +Governance=2 / +Intelligence=3,
#                   additive — maturity-model.md). Default 3 (full).
#   $1  Project name (display name, used in file headers)
#   $2  CARL domain name (lowercase, no dashes, e.g. "monprojetworkflow")
#   $3  CARL recall keywords (comma-separated, triggers domain loading)
# ============================================================================

TEMPLATE_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="${WORKSPACE_DIR:-$(dirname "$TEMPLATE_DIR")}"
ALLOWLIST="$TEMPLATE_DIR/.forge/sync-allowlist.json"

# injection-safe {{token}} resolver (AC-4-7) — sourced so it is unit-testable
RESOLVER_LIB="$TEMPLATE_DIR/.forge/forge-resolve.sh"
# shellcheck source=.forge/forge-resolve.sh
[ -f "$RESOLVER_LIB" ] && . "$RESOLVER_LIB"

usage() {
    cat <<'EOF'
Usage: ./forge-init.sh [--tier 1|2|3] [--answers FILE] "Project Name" carl_domain "keyword1,keyword2"

  --tier 1        Foundation only (memory, verification, todo, lesson, commit-push)
  --tier 2        + Governance (gates, supply-chain, pre-flight, sparc, prepare-phase…)
  --tier 3        + Intelligence (knowledge, graphify, swarm, task-router…)   [default]
  --answers FILE  token-keyed JSON of Plan-05 questionnaire answers (overrides config-
                  derived values; fills the stack-vocabulary {{TOKENS}}).

Example:
  ./forge-init.sh --tier 2 "Mon SaaS" saasworkflow "saas,api,subscription,billing"
EOF
}

# ── argument parsing (flags before/after positionals) ──────────────────────
TIER=3
ANSWERS_FILE=""
POSITIONAL=()
while [ $# -gt 0 ]; do
    case "$1" in
        --tier)      TIER="${2:?--tier requires an argument (1|2|3)}"; shift 2 ;;
        --tier=*)    TIER="${1#*=}"; shift ;;
        --answers)   ANSWERS_FILE="${2:?--answers requires a file}"; shift 2 ;;
        --answers=*) ANSWERS_FILE="${1#*=}"; shift ;;
        -h|--help) usage; exit 0 ;;
        --) shift; while [ $# -gt 0 ]; do POSITIONAL+=("$1"); shift; done ;;
        -*) echo "ERROR: unknown flag: $1" >&2; usage; exit 2 ;;
        *)  POSITIONAL+=("$1"); shift ;;
    esac
done
set -- ${POSITIONAL[@]+"${POSITIONAL[@]}"}

case "$TIER" in 1|2|3) ;; *) echo "ERROR: --tier must be 1, 2 or 3 (got '$TIER')" >&2; exit 2 ;; esac

if [ $# -lt 3 ]; then usage; exit 1; fi

# ── prerequisites ──────────────────────────────────────────────────────────
# jq is required: the derived allowlist is JSON, and the AC-4-7 resolver mandates
# `jq --arg` for injection-safe substitution. (Supersedes init-project.sh's
# "bash+sed only" note — the inverse-transform safety contract needs jq.)
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required (parses the derived allowlist + injection-safe resolve)." >&2; exit 2; }
[ -f "$ALLOWLIST" ] || { echo "ERROR: derived allowlist missing: $ALLOWLIST" >&2
    echo "       Run forge-extract.sh --apply from the Loupe golden first (it emits the derived allowlist)." >&2; exit 2; }
jq -e . "$ALLOWLIST" >/dev/null 2>&1 || { echo "ERROR: derived allowlist is not valid JSON: $ALLOWLIST" >&2; exit 2; }

PROJECT_NAME="$1"
CARL_DOMAIN="$2"
RECALL_KEYWORDS="$3"
CARL_DOMAIN_UPPER=$(echo "$CARL_DOMAIN" | tr '[:lower:]' '[:upper:]')
PROJECT_DIR="${WORKSPACE}/${PROJECT_NAME}"
TODAY=$(date +%Y-%m-%d)

echo "═══════════════════════════════════════════"
echo "  FORGE Project Initializer (tier ${TIER})"
echo "═══════════════════════════════════════════"
echo ""
echo "  Project:    ${PROJECT_NAME}"
echo "  Directory:  ${PROJECT_DIR}"
echo "  CARL:       ${CARL_DOMAIN} (${CARL_DOMAIN_UPPER})"
echo "  Keywords:   ${RECALL_KEYWORDS}"
echo "  Allowlist:  ${ALLOWLIST}"
echo ""

if [ -d "$PROJECT_DIR" ]; then
    echo "ERROR: Directory already exists: ${PROJECT_DIR}" >&2
    exit 1
fi

# ── tier membership (maturity-model.md; anything unlisted defaults to tier 3,
#    so nothing is silently dropped at full adoption) ────────────────────────
tier_of_skill() {
    case "$1" in
        todo|lesson|commit-push) echo 1 ;;
        supply-chain-audit|architecture-kit|pre-flight|sparc|prepare-phase|skill-refresh|security-audit|close-phase|skill-forge|pmo|plan-ceo-review|office-hours|execute-phase-auto) echo 2 ;;
        *) echo 3 ;;
    esac
}
tier_of_rule() {
    case "$1" in
        verification-discipline.md|cognitive-patterns.md|workflow-guide.md|todo-discipline.md) echo 1 ;;
        skill-gate.md|supply-chain-audit.md|dependency-surveillance.md|parallel-worktree-discipline.md|session-isolation.md|protected-files.yaml|phase-lifecycle.md|phase-workflow-orchestrator-default.md|brief-contract-verification.md|governance-index-discipline.md|skill-framework.md) echo 2 ;;
        *) echo 3 ;;
    esac
}
tier_of_hook() {  # by basename
    case "$1" in
        session-start.sh|memory-retention.sh) echo 1 ;;
        *) echo 2 ;;
    esac
}

COPIED_SKILLS=(); COPIED_RULES=(); COPIED_HOOKS=(); COPIED_FILES=()

# ── structural directories ─────────────────────────────────────────────────
echo "→ Creating directory structure..."
mkdir -p "${PROJECT_DIR}/.claude/skills"
mkdir -p "${PROJECT_DIR}/.claude/hooks/lib"
mkdir -p "${PROJECT_DIR}/.claude/rules"
mkdir -p "${PROJECT_DIR}/.claude/agents"
mkdir -p "${PROJECT_DIR}/.claude/workspace"
mkdir -p "${PROJECT_DIR}/.carl"
mkdir -p "${PROJECT_DIR}/.planning"
mkdir -p "${PROJECT_DIR}/.codex"
mkdir -p "${PROJECT_DIR}/.githooks"
mkdir -p "${PROJECT_DIR}/docs/solutions"
mkdir -p "${PROJECT_DIR}/docs/plans"
mkdir -p "${PROJECT_DIR}/docs/brainstorms"
mkdir -p "${PROJECT_DIR}/docs/architecture"
mkdir -p "${PROJECT_DIR}/docs/references"
mkdir -p "${PROJECT_DIR}/memory"
mkdir -p "${PROJECT_DIR}/todos/pending"
mkdir -p "${PROJECT_DIR}/todos/complete"
mkdir -p "${PROJECT_DIR}/todos/done"
mkdir -p "${PROJECT_DIR}/scripts"
mkdir -p "${PROJECT_DIR}/src"

# ── ALLOWLIST-DRIVEN COPY — skills ─────────────────────────────────────────
echo "→ Installing skills (allowlist-driven, tier ≤ ${TIER})..."
while IFS= read -r skill; do
    [ -z "$skill" ] && continue
    [ "$(tier_of_skill "$skill")" -le "$TIER" ] || continue
    src="${TEMPLATE_DIR}/.claude/skills/${skill}"
    if [ -d "$src" ]; then
        mkdir -p "${PROJECT_DIR}/.claude/skills/${skill}"
        cp -R "${src}/." "${PROJECT_DIR}/.claude/skills/${skill}/"
        COPIED_SKILLS+=("$skill")
    else
        echo "  WARN: allowlisted skill '${skill}' not in template tree — skipped" >&2
    fi
done < <(jq -r '.skills[]?' "$ALLOWLIST")

# ── ALLOWLIST-DRIVEN COPY — rules ──────────────────────────────────────────
echo "→ Installing rules (allowlist-driven, tier ≤ ${TIER})..."
while IFS= read -r rule; do
    [ -z "$rule" ] && continue
    [ "$(tier_of_rule "$rule")" -le "$TIER" ] || continue
    src="${TEMPLATE_DIR}/.claude/rules/${rule}"
    if [ -f "$src" ]; then
        cp "$src" "${PROJECT_DIR}/.claude/rules/${rule}"
        COPIED_RULES+=("$rule")
    else
        echo "  WARN: allowlisted rule '${rule}' not in template tree — skipped" >&2
    fi
done < <(jq -r '.rules[]?' "$ALLOWLIST")

# ── ALLOWLIST-DRIVEN COPY — hooks (glob expansion, tier by basename) ────────
echo "→ Installing hooks (allowlist-driven globs)..."
while IFS= read -r glob; do
    [ -z "$glob" ] && continue
    shopt -s nullglob
    for f in "${TEMPLATE_DIR}"/${glob}; do
        [ -f "$f" ] || continue
        rel="${f#${TEMPLATE_DIR}/}"
        base="$(basename "$f")"
        # tier-gate only the `.claude/hooks/*.sh` foundation set; lib/, .githooks/,
        # setup-hooks.sh are governance (tier 2). Default tier 3 takes everything.
        case "$rel" in
            .claude/hooks/*.sh) [ "$(tier_of_hook "$base")" -le "$TIER" ] || continue ;;
            *) [ "$TIER" -ge 2 ] || continue ;;
        esac
        mkdir -p "${PROJECT_DIR}/$(dirname "$rel")"
        cp "$f" "${PROJECT_DIR}/${rel}"
        chmod +x "${PROJECT_DIR}/${rel}" 2>/dev/null || true
        COPIED_HOOKS+=("$rel")
    done
    shopt -u nullglob
done < <(jq -r '.hooks_glob[]?' "$ALLOWLIST")

# ── ALLOWLIST-DRIVEN COPY — scattered files (CLAUDE.md + sliced configs +
#    forge tooling). These carry {{tokens}} resolved by the AC-4-7 resolver. ──
echo "→ Installing scattered files (allowlist-driven)..."
while IFS= read -r relfile; do
    [ -z "$relfile" ] && continue
    src="${TEMPLATE_DIR}/${relfile}"
    if [ -f "$src" ]; then
        mkdir -p "${PROJECT_DIR}/$(dirname "$relfile")"
        cp "$src" "${PROJECT_DIR}/${relfile}"
        case "$relfile" in *.sh) chmod +x "${PROJECT_DIR}/${relfile}" 2>/dev/null || true ;; esac
        COPIED_FILES+=("$relfile")
    else
        echo "  WARN: allowlisted file '${relfile}' not in template tree — skipped" >&2
    fi
done < <(jq -r '.files[]?' "$ALLOWLIST")

# ── CARL — manifest is extracted (tokenized, resolver-bound); the domain RULES
#    file is project-authored (the golden's is protected, never shipped). ─────
echo "→ Installing CARL..."
if [ -f "${TEMPLATE_DIR}/.carl/manifest" ]; then
    cp "${TEMPLATE_DIR}/.carl/manifest" "${PROJECT_DIR}/.carl/manifest"
fi
cat > "${PROJECT_DIR}/.carl/${CARL_DOMAIN}" <<EOF
# CARL Domain: ${PROJECT_NAME}
RULE_0="These rules apply to ${CARL_DOMAIN}. All CARL rules MUST be written in English."
RULE_1="CONSULT BEFORE IMPLEMENTING: Check docs/solutions/ for existing patterns before writing new code."
RULE_2="DOCUMENT AFTER SOLVING: Document patterns in docs/solutions/ after resolving non-trivial problems."
RULE_3="CREDENTIALS SAFETY: All secrets in a vault / .env, never hardcoded."
EOF

# ── agents (template-native, outside the extracted tree) ───────────────────
if [ -d "${TEMPLATE_DIR}/.claude/agents" ]; then
    echo "→ Installing agents..."
    shopt -s nullglob
    for a in "${TEMPLATE_DIR}/.claude/agents/"*.md; do
        cp "$a" "${PROJECT_DIR}/.claude/agents/$(basename "$a")"
    done
    shopt -u nullglob
fi

# ── fresh per-project scaffolds (NOT extracted — generated from .template) ──
# These targets are project-specific/protected (never shipped by extraction), so
# they are seeded fresh per project. {{PROJECT_NAME}}/{{DATE}}/… are resolved here
# (legacy sed vocabulary); the extracted tree's {{PROJECT}} tokens are resolved by
# the AC-4-7 resolver.
gen_from_template() {  # $1=template path  $2=output path  (extra sed exprs follow)
    local tpl="$1" out="$2"; shift 2
    [ -f "$tpl" ] || { echo "  WARN: template missing, skipped: ${tpl#${TEMPLATE_DIR}/}" >&2; return 0; }
    mkdir -p "$(dirname "$out")"
    sed "$@" "$tpl" > "$out"
}

echo "→ Generating fresh scaffolds..."
gen_from_template "${TEMPLATE_DIR}/memory/MEMORY.md.template" "${PROJECT_DIR}/memory/MEMORY.md" \
    -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" -e "s|{{DATE}}|${TODAY}|g" -e "s|{{PROJECT_PATH}}|${PROJECT_DIR}|g"
gen_from_template "${TEMPLATE_DIR}/LESSONS.md.template" "${PROJECT_DIR}/LESSONS.md" \
    -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g"
gen_from_template "${TEMPLATE_DIR}/DECISIONS.md.template" "${PROJECT_DIR}/DECISIONS.md" \
    -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g"
gen_from_template "${TEMPLATE_DIR}/.claude/integrations.md.template" "${PROJECT_DIR}/.claude/integrations.md" \
    -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g"
gen_from_template "${TEMPLATE_DIR}/docs/architecture/contexts.md.template" "${PROJECT_DIR}/docs/architecture/contexts.md" \
    -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g"
gen_from_template "${TEMPLATE_DIR}/.codex/config.toml.template" "${PROJECT_DIR}/.codex/config.toml" \
    -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g"

# reference files (glob of *.md.template)
shopt -s nullglob
for ref_template in "${TEMPLATE_DIR}"/docs/references/*.md.template; do
    ref_name=$(basename "$ref_template" .template)
    sed -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" -e "s|{{PROJECT_ROOT}}|${PROJECT_DIR}|g" \
        "$ref_template" > "${PROJECT_DIR}/docs/references/${ref_name}"
done
shopt -u nullglob

# .gitignore (template-native, copied verbatim)
[ -f "${TEMPLATE_DIR}/.gitignore" ] && cp "${TEMPLATE_DIR}/.gitignore" "${PROJECT_DIR}/.gitignore"

# ── .gitkeep for empty dirs ────────────────────────────────────────────────
for d in .planning docs/solutions docs/plans docs/brainstorms docs/references \
         todos/pending todos/complete todos/done src; do
    [ -z "$(ls -A "${PROJECT_DIR}/${d}" 2>/dev/null)" ] && touch "${PROJECT_DIR}/${d}/.gitkeep"
done

# ── TOKEN RESOLUTION (AC-4-7) — injection-safe, fail-closed ────────────────
# Assemble a token-keyed answers map from the copied configs + args, optionally
# overridden by a Plan-05 questionnaire file (--answers). Empty config values are
# DROPPED so the token survives for the AC-4-8 tripwire / Plan-05 deploy-block.
build_answers() {  # → token-keyed JSON on stdout
    local fc="${PROJECT_DIR}/.claude/forge.config.json" gc="${PROJECT_DIR}/.claude/gate.config.json"
    local pn pl pu rag cf1 lang
    pn=""; [ -f "$fc" ] && pn=$(jq -r '.project_name // ""' "$fc")
    [ -z "$pn" ] && pn="$PROJECT_NAME"
    pl=$(printf '%s' "$pn" | tr '[:upper:]' '[:lower:]')
    pu=$(printf '%s' "$pn" | tr '[:lower:]' '[:upper:]' | tr -c 'A-Z0-9' '_')
    rag="";  [ -f "$fc" ] && rag=$(jq -r '.memory_backend.rag // ""' "$fc")
    cf1="";  [ -f "$fc" ] && cf1=$(jq -r '(.compliance_frameworks // [])[0] // ""' "$fc")
    lang=""; [ -f "$gc" ] && lang=$(jq -r '.language // ""' "$gc")
    jq -n --arg PROJECT "$pn" --arg project "$pl" --arg PROJECT_UPPER "$pu" \
          --arg RAG "$rag" --arg CF1 "$cf1" --arg LANG "$lang" '
        { PROJECT: $PROJECT, project: $project, PROJECT_UPPER: $PROJECT_UPPER }
        | if $RAG  != "" then . + { RAG_BACKEND: $RAG, rag_backend: ($RAG|ascii_downcase), KNOWLEDGE_BACKEND: $RAG, knowledge_backend: ($RAG|ascii_downcase) } else . end
        | if $CF1  != "" then . + { COMPLIANCE_FRAMEWORK_PRIMARY: $CF1, compliance_framework_primary: ($CF1|ascii_downcase) } else . end
        | if $LANG != "" then . + { SCRIPTING_LANG: $LANG, scripting_lang: ($LANG|ascii_downcase) } else . end
        | with_entries(select(.value != ""))
    '
}

if ! command -v resolve_tree >/dev/null 2>&1 && ! declare -F resolve_tree >/dev/null 2>&1; then
    echo "ERROR: resolver lib not loaded ($RESOLVER_LIB) — cannot safely resolve tokens." >&2
    exit 5
fi
echo "→ Resolving {{tokens}} (injection-safe; validity + gitleaks fail-closed)..."
ANSWERS_TMP=$(mktemp)
build_answers > "$ANSWERS_TMP"
if [ -n "$ANSWERS_FILE" ]; then
    [ -f "$ANSWERS_FILE" ] || { echo "ERROR: --answers file not found: $ANSWERS_FILE" >&2; exit 2; }
    jq -e . "$ANSWERS_FILE" >/dev/null 2>&1 || { echo "ERROR: --answers file is not valid JSON: $ANSWERS_FILE" >&2; exit 2; }
    MERGED=$(mktemp)
    jq -s '.[0] * .[1]' "$ANSWERS_TMP" "$ANSWERS_FILE" > "$MERGED" && mv "$MERGED" "$ANSWERS_TMP"
fi
resolve_tree "$PROJECT_DIR" "$ANSWERS_TMP" || { echo "ERROR: token resolution failed (fail-closed). See above." >&2; rm -f "$ANSWERS_TMP"; exit 5; }
rm -f "$ANSWERS_TMP"

# ── AC-4-8 TRIPWIRE — fail-closed on residual {{tokens}} in the FORGE tree ──
# Scope = the extracted/copied FORGE tree only (generated user stubs in
# docs/references, contexts, integrations, codex are manual-fill, out of scope).
echo "→ Tripwire: scanning the FORGE tree for unresolved {{tokens}}..."
TRIPWIRE_RC=0
tripwire_scan \
    "${PROJECT_DIR}/.claude/rules" "${PROJECT_DIR}/.claude/skills" "${PROJECT_DIR}/.claude/hooks" \
    "${PROJECT_DIR}/.githooks" "${PROJECT_DIR}/scripts/forge" "${PROJECT_DIR}/CLAUDE.md" \
    "${PROJECT_DIR}/.claude/gate.config.json" "${PROJECT_DIR}/.claude/forge.config.json" \
    "${PROJECT_DIR}/.carl/manifest" || TRIPWIRE_RC=1

# ── summary ────────────────────────────────────────────────────────────────
echo ""
echo "✓ Project initialized (tier ${TIER})."
echo "    skills copied : ${#COPIED_SKILLS[@]}"
echo "    rules copied  : ${#COPIED_RULES[@]}"
echo "    hooks copied  : ${#COPIED_HOOKS[@]}"
echo "    files copied  : ${#COPIED_FILES[@]}"
echo ""
echo "  Next steps:"
echo "    1. cd \"${PROJECT_DIR}\""
echo "    2. Fill remaining {{TOKENS}} (stack vocabulary) via the Plan-05 questionnaire"
echo "       (re-run with --answers <file>); residuals are flagged by the deploy-block."
echo "    3. Author .carl/${CARL_DOMAIN} project rules + fill CLAUDE.md / docs/references."
echo "    4. Run check-setup.sh to verify the setup is GREEN."
echo ""

# fail-closed on residual FORGE-tree tokens (AC-4-8) — RED until the questionnaire fills them
if [ "${TRIPWIRE_RC:-0}" -ne 0 ]; then
    echo "⚠ RED: unresolved {{tokens}} remain in the FORGE tree (listed above)." >&2
    echo "  Supply the full questionnaire (--answers <file>) on a fresh init, or fill them in place." >&2
    exit 6
fi
