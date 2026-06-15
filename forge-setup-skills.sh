#!/usr/bin/env bash
set -uo pipefail
# ============================================================================
# forge-setup-skills.sh — deploy-time skill-identification questionnaire (AC-5-5)
# ============================================================================
# INTERIM, pre-scan. Asks the project's stack/domains, proposes the domain skills
# to create, and scaffolds each as a skill-framework.md-compliant SKILL.md skeleton
# (the same shape /skill-forge would produce), registering a stub in the project
# component-registry + skills-inventory. Auto-scan / domain detection is a LATER
# phase — this is the manual interim.
#
# D-16 (DELIBERATE deferral): the reusable-starter CATALOG (the default-on bundle,
# the `starter_catalog` tier reserved in the manifest) is OUT of Phase 22 v1 →
# Phase 22.1. This questionnaire does NOT build, offer, or opt-in any default
# bundle — it only forges the PROJECT-SPECIFIC domain skills the operator declares.
# (Annotated so an executor neither builds an unscoped bundle nor ships confused.)
#
# Usage: forge-setup-skills.sh [--project-dir DIR] [--stack "python,rest-api"]
#   --stack none (or empty) → nothing forged. A flag omitted on a TTY is prompted.
# ============================================================================

# declared domain → proposed skill name (known mappings + a safe slug fallback)
_skill_name_for() {  # $1=domain
    case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' ')" in
        python|py)                         echo "python-architect" ;;
        javascript|typescript|node|nodejs) echo "node-architect" ;;
        rest-api|restapi|rest|api)         echo "api-architect" ;;
        sql|postgres|postgresql|database|db) echo "data-architect" ;;
        docker|container|containers|k8s|kubernetes) echo "container-architect" ;;
        *) printf '%s-architect' "$(printf '%s' "$1" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-' | sed 's/^-*//;s/-*$//')" ;;
    esac
}

_scaffold_skill() {  # $1=project-dir  $2=skill-name  $3=domain-label
    local dir="$1/.claude/skills/$2"
    if [ -d "$dir" ]; then echo "  · $2 already present — left untouched (no clobber)" >&2; return 0; fi
    mkdir -p "$dir"
    cat > "$dir/SKILL.md" <<EOF
---
name: $2
description: >
  $3 domain skill (scaffolded by forge-setup-skills — flesh out per skill-framework.md).
  Triggers on: $3, /$2.
---

# /$2 — $3 domain skill

> Scaffolded skeleton (AC-5-5 interim). Fill the routing table, workflow, and scope
> per \`.claude/rules/skill-framework.md\` before relying on it.

## Usage
\`/$2\` — invoke for $3 work.

## Workflow
1. (define the steps for $3 here)

## What this skill does NOT do
- (list explicit out-of-scope items here)
EOF
    echo "  ✓ scaffolded .claude/skills/$2/SKILL.md ($3)" >&2
}

_register_skill() {  # $1=project-dir  $2=skill-name  $3=domain
    local inv="$1/docs/solutions/agents/skills-inventory.md"
    mkdir -p "$(dirname "$inv")"
    [ -f "$inv" ] || printf '# Skills Inventory (project)\n\n| Skill | Domain | Status |\n|---|---|---|\n' > "$inv"
    grep -qF "| \`$2\` |" "$inv" || printf '| `%s` | %s | scaffolded |\n' "$2" "$3" >> "$inv"
    local reg="$1/docs/architecture/forge/component-registry.md"
    if [ -f "$reg" ]; then
        grep -q '<!-- forge-setup-skills: deploy-forged -->' "$reg" \
            || printf '\n<!-- forge-setup-skills: deploy-forged -->\n## Deploy-time forged skills\n\n| Skill | Domain |\n|---|---|\n' >> "$reg"
        grep -qF "| \`$2\` |" "$reg" || printf '| `%s` | %s |\n' "$2" "$3" >> "$reg"
    fi
}

main() {
    local project_dir="." stack=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --project-dir) project_dir="$2"; shift 2 ;;
            --stack)       stack="$2"; shift 2 ;;
            *) echo "forge-setup-skills: unknown option '$1'" >&2; return 2 ;;
        esac
    done
    if [ -z "$stack" ] && [ -t 0 ]; then
        printf 'Project stack / domains (csv, e.g. "python,rest-api"; "none" to skip): ' >&2
        IFS= read -r stack || stack=""
    fi
    case "$(printf '%s' "$stack" | tr '[:upper:]' '[:lower:]' | tr -d ' ')" in
        ""|none) echo "  · no domains declared — no skills forged (auto-scan is a later phase)" >&2; return 0 ;;
    esac

    local saved_ifs="$IFS" d name; declare -a DOMAINS
    IFS=','; read -ra DOMAINS <<< "$stack"; IFS="$saved_ifs"
    echo "Proposed domain skills (interim — flesh out per skill-framework.md):" >&2
    for d in "${DOMAINS[@]}"; do
        d="$(printf '%s' "$d" | sed 's/^ *//;s/ *$//')"; [ -z "$d" ] && continue
        name="$(_skill_name_for "$d")"
        _scaffold_skill "$project_dir" "$name" "$d"
        _register_skill "$project_dir" "$name" "$d"
    done
    return 0
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then main "$@"; fi
