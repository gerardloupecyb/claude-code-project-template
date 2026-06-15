#!/usr/bin/env bash
# ============================================================================
# forge-resolve.sh — injection-safe full-tree {{PLACEHOLDER}} resolver (lib)
# ============================================================================
# Sourced by forge-init.sh (FORGE Phase 22 Plan 04, AC-4-7). [SENSIBLE] —
# cross-vendor no-waiver surface. The resolver is the INVERSE of the extraction:
# it substitutes operator/config answers into the copied tree. Two invariants:
#
#   1. NO EXECUTION, NO PROGRAM-BREAK. Operator answers are never executed and
#      never break the substitution program. Text files use an awk literal-index
#      replace with the value passed via ENVIRON (no sed program, no regex
#      metachars active, no command-substitution re-evaluation). JSON files use
#      jq gsub with --arg (the value is JSON-escaped on serialization, so
#      `& / | { } "` cannot break structure).
#   2. FAIL-CLOSED. A structured file that would become invalid post-substitution
#      fails a positive validity assert (jq -e / PyYAML) → non-zero, nothing
#      ships. A real secret pasted as an answer is caught by a gitleaks pass
#      (S/F1) — the structural assert cannot see a key SHAPE.
#
# Functions are pure (arg-driven, no global coupling) so the hostile-input
# fixture test can source this file and call resolve_tree directly.
# ============================================================================

# literal substitution in a text file — value via ENVIRON so it is NEVER expanded
# (no command substitution, no backslash processing, no sed/awk metachar activity)
_forge_sub_text_file() {  # $1=file  $2=token-name  $3=value
    local f="$1" tmp; tmp="$(mktemp)"
    TOK="{{$2}}" VAL="$3" awk '
        BEGIN { tok = ENVIRON["TOK"]; val = ENVIRON["VAL"]; tl = length(tok) }
        {
            line = $0; out = ""
            while ((p = index(line, tok)) > 0) { out = out substr(line, 1, p-1) val; line = substr(line, p + tl) }
            print out line
        }
    ' "$f" > "$tmp" && mv "$tmp" "$f" || { rm -f "$tmp"; return 1; }
}

# structural substitution in a JSON file — jq gsub with --arg. The replacement is
# a literal jq string (no `&` backref semantics), JSON-escaped on serialization;
# the token charset [A-Za-z0-9_-] carries no active jq-regex metacharacter.
_forge_sub_json_file() {  # $1=file  $2=token-name  $3=value
    local f="$1" tmp; tmp="$(mktemp)"
    jq --arg tok "$2" --arg val "$3" \
       'walk(if type == "string" then gsub("\\{\\{" + $tok + "\\}\\}"; $val) else . end)' \
       "$f" > "$tmp" 2>/dev/null && mv "$tmp" "$f" || { rm -f "$tmp"; return 1; }
}

# positive post-substitution validity assert (fail-closed)
_forge_validate_tree() {  # $1=dir
    local dir="$1" f
    while IFS= read -r f; do
        jq -e . "$f" >/dev/null 2>&1 || { echo "ERROR: invalid JSON post-resolve (fail-closed): ${f#"${dir}"/}" >&2; return 1; }
    done < <(find "$dir" -type f -name '*.json')
    if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' 2>/dev/null; then
        while IFS= read -r f; do
            # residual {{tokens}} ⇒ not fully resolved ⇒ validity deferred to the
            # Plan-05 questionnaire / AC-4-8 tripwire (an unanswered token in a scalar
            # position is legitimately unparseable until filled).
            grep -q '{{[A-Za-z0-9_]' "$f" && continue
            # safe_load_all: these rules carry an `---` frontmatter fence + body, i.e.
            # a legitimate MULTI-document YAML stream (single-doc load would false-reject).
            python3 -c 'import sys, yaml; list(yaml.safe_load_all(open(sys.argv[1])))' "$f" >/dev/null 2>&1 \
                || { echo "ERROR: invalid YAML post-resolve (fail-closed): ${f#"${dir}"/}" >&2; return 1; }
        done < <(find "$dir" -type f \( -name '*.yaml' -o -name '*.yml' \))
    else
        echo "  WARN: python3+PyYAML unavailable — YAML validity assert skipped (install for full fail-closed coverage)." >&2
    fi
}

# S/F1 — fail-closed secret backstop over the materialized tree. A project-local
# .gitleaks.toml (if present) is honoured; otherwise gitleaks default rules apply.
_forge_gitleaks_scan() {  # $1=dir
    local dir="$1"
    command -v gitleaks >/dev/null 2>&1 || {
        echo "  WARN: gitleaks absent — S/F1 secret backstop SKIPPED (install gitleaks; Tier-2 toolchain)." >&2
        return 0
    }
    if [ -f "$dir/.gitleaks.toml" ]; then
        gitleaks detect --no-git --source "$dir" --config "$dir/.gitleaks.toml" --redact --no-banner >/dev/null 2>&1
    else
        gitleaks detect --no-git --source "$dir" --redact --no-banner >/dev/null 2>&1
    fi || {
        echo "ERROR: gitleaks found a secret in the resolved tree — an answer persisted a key-shape. Fail-closed (nothing ships)." >&2
        return 1
    }
    return 0
}

# resolve every {{token}} present in the tree from a token-keyed answers JSON,
# then validate structure + run the secret backstop. Tokens with no answer are
# LEFT in place (the AC-4-8 tripwire / the Plan-05 deploy-block handle residuals).
resolve_tree() {  # $1=dir  $2=answers.json
    local dir="$1" answers="$2" tok val f
    [ -d "$dir" ] || { echo "ERROR: resolve_tree: dir not found: $dir" >&2; return 2; }
    jq -e . "$answers" >/dev/null 2>&1 || { echo "ERROR: resolve_tree: answers not valid JSON: $answers" >&2; return 2; }
    while IFS= read -r tok; do
        [ -z "$tok" ] && continue
        jq -e --arg k "$tok" 'has($k)' "$answers" >/dev/null 2>&1 || continue
        val="$(jq -r --arg k "$tok" '.[$k]' "$answers")"
        while IFS= read -r f; do
            case "$f" in
                *.json) _forge_sub_json_file "$f" "$tok" "$val" || { echo "ERROR: JSON resolve failed: ${f#"${dir}"/}" >&2; return 1; } ;;
                *)      _forge_sub_text_file "$f" "$tok" "$val" || { echo "ERROR: text resolve failed: ${f#"${dir}"/}" >&2; return 1; } ;;
            esac
        done < <(grep -rlF "{{$tok}}" "$dir" 2>/dev/null)
    done < <(grep -rhoE '\{\{[A-Za-z0-9_][A-Za-z0-9_-]*\}\}' "$dir" 2>/dev/null | sed 's/^{{//; s/}}$//' | sort -u)
    _forge_validate_tree "$dir" || return 1
    _forge_gitleaks_scan "$dir" || return 1
    return 0
}
