#!/usr/bin/env bash
set -uo pipefail
# ============================================================================
# forge-setup-executors.sh — deploy-time executor routing + provisioning ([SENSIBLE])
# ============================================================================
# FORGE Phase 22 Plan 05. Walks a new project through (1) ROUTING configuration
# (models/executors + fallback chains → forge.config.json model_router), and — in
# later subcommands — leak-proof executor key provisioning, auth probes, and the
# OpenRouter MCP launch-env wiring. [SENSIBLE] cross-vendor no-waiver surface.
#
# D-11 INVARIANT (load-bearing): the model_router block lives in forge.config.json
# (doc/wiring), NEVER gate.config.json. The security hooks (pre-tool-use.sh /
# pre-mcp-gate.sh) read ONLY gate.config.json on the hot path; they must never
# source routing. This script writes routing to forge.config.json and is
# STRUCTURALLY incapable of writing it to gate.config.json — the gate.config path
# is NEVER a write target in any code path here. No invented `adversarial_reviewers`
# field is created: the real field is forge.config.json model_router.cross_vendor_voices.
#
# D-13: model VERSIONS are NOT pinned here — forge.config.json model_router carries
# the executor TRANSPORTS (codex-cli / openrouter / gemini-cli); the canonical model
# IDs (e.g. openai/gpt-5.5) live in .claude/rules/router-rules.md (the doc).
#
# Subcommands:
#   routing   AC-5-1  write model_router.cross_vendor_voices + fill router-rules skeleton
#   (keys / probe / mcp added by Plan-05 Tasks 2-3)
#
# Usage:
#   forge-setup-executors.sh routing [--project-dir DIR]
#       [--openai LIST] [--google LIST]              (executor transports, comma-sep)
#       [--scripting-lang L] [--cloud-provider C] [--workflow-engine W] [--project-slug P]
#   A flag omitted on a TTY is prompted (canonical default offered); omitted without
#   a TTY uses the canonical default. Canonical chains:
#       OpenAI → Codex CLI → OpenRouter (gpt-5.5) ;  Google → Gemini CLI (→ flash)
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v jq >/dev/null 2>&1 || { echo "forge-setup-executors: jq required" >&2; exit 2; }

# Canonical cross-vendor defaults (the D-15 fallback chain; transports, not models).
DEFAULT_OPENAI="codex-cli,openrouter"
DEFAULT_GOOGLE="gemini-cli"

# csv → compact JSON array of trimmed non-empty tokens
_csv_to_json_array() {  # $1=csv
    printf '%s' "$1" | jq -R 'split(",") | map(gsub("^\\s+|\\s+$";"")) | map(select(length>0))'
}

# prompt-with-default ONLY when interactive; otherwise echo the default (no stdin read)
_ask() {  # $1=prompt  $2=default  → value on stdout
    local prompt="$1" def="$2" ans=""
    if [ -t 0 ]; then
        printf '%s [%s]: ' "$prompt" "$def" >&2
        IFS= read -r ans || ans=""
    fi
    [ -z "$ans" ] && ans="$def"
    printf '%s' "$ans"
}

cmd_routing() {
    local PROJECT_DIR="." OPENAI="" GOOGLE="" SLANG="__UNSET__" CLOUD="__UNSET__" WENG="__UNSET__" PSLUG="__UNSET__"
    while [ $# -gt 0 ]; do
        case "$1" in
            --project-dir)      PROJECT_DIR="$2"; shift 2 ;;
            --openai)           OPENAI="$2"; shift 2 ;;
            --google)           GOOGLE="$2"; shift 2 ;;
            --scripting-lang)   SLANG="$2"; shift 2 ;;
            --cloud-provider)   CLOUD="$2"; shift 2 ;;
            --workflow-engine)  WENG="$2"; shift 2 ;;
            --project-slug)     PSLUG="$2"; shift 2 ;;
            *) echo "forge-setup-executors routing: unknown option '$1'" >&2; return 2 ;;
        esac
    done

    local FC="$PROJECT_DIR/.claude/forge.config.json"
    local RR="$PROJECT_DIR/.claude/rules/router-rules.md"
    [ -f "$FC" ] || { echo "forge-setup-executors routing: forge.config.json not found: $FC" >&2; return 2; }
    jq -e . "$FC" >/dev/null 2>&1 || { echo "forge-setup-executors routing: forge.config.json invalid JSON: $FC" >&2; return 2; }

    # --- executor transports (cross_vendor_voices) -------------------------------
    [ -z "$OPENAI" ] && OPENAI="$(_ask 'OpenAI voice transports (csv, order = fallback chain)' "$DEFAULT_OPENAI")"
    [ -z "$GOOGLE" ] && GOOGLE="$(_ask 'Google voice transports (csv)' "$DEFAULT_GOOGLE")"
    local openai_arr google_arr
    openai_arr="$(_csv_to_json_array "$OPENAI")" || { echo "routing: bad --openai list" >&2; return 2; }
    google_arr="$(_csv_to_json_array "$GOOGLE")" || { echo "routing: bad --google list" >&2; return 2; }

    # --- write model_router.cross_vendor_voices to forge.config.json ONLY --------
    # jq merge preserves _canonical_source / primary_executor / subagent_executor; the
    # write target is forge.config.json by construction — gate.config.json is never opened.
    local tmp; tmp="$(mktemp)"
    jq --argjson openai "$openai_arr" --argjson google "$google_arr" '
        .model_router = (.model_router // {})
        | .model_router.cross_vendor_voices = { openai: $openai, google: $google }
    ' "$FC" > "$tmp" 2>/dev/null && jq -e . "$tmp" >/dev/null 2>&1 || {
        echo "routing: failed to write model_router (fail-closed, forge.config untouched)" >&2; rm -f "$tmp"; return 1
    }
    mv "$tmp" "$FC"
    echo "  ✓ model_router.cross_vendor_voices written to forge.config.json (openai=$OPENAI ; google=$GOOGLE)"

    # --- fill the parameterized router-rules skeleton (stack vocab tokens) --------
    # The executor chains are in forge.config; router-rules also references the
    # project's stack vocabulary. Resolve those tokens literally (injection-safe via
    # the Plan-04 awk/ENVIRON helper — no sed program, no metachar activity). A token
    # left UNSET stays {{...}} and is caught by the AC-5-7 deploy-block, not silently lost.
    if [ -f "$RR" ]; then
        # shellcheck source=/dev/null
        . "$SCRIPT_DIR/.forge/forge-resolve.sh" 2>/dev/null || {
            echo "  WARN: forge-resolve.sh not sourceable — router-rules tokens not resolved here (deploy-block will catch residuals)." >&2
        }
        if declare -F _forge_sub_text_file >/dev/null 2>&1; then
            [ "$SLANG" = "__UNSET__" ] && SLANG="$(_ask 'Primary scripting language (router-rules)' '')"
            [ "$CLOUD" = "__UNSET__" ] && CLOUD="$(_ask 'Primary cloud provider (router-rules)' '')"
            [ "$WENG"  = "__UNSET__" ] && WENG="$(_ask 'Primary workflow engine (router-rules)' '')"
            [ "$PSLUG" = "__UNSET__" ] && PSLUG="$(_ask 'Project slug (lowercase, router-rules)' "$(jq -r '.project_name // "" | ascii_downcase' "$FC")")"
            [ -n "$SLANG" ] && _forge_sub_text_file "$RR" "SCRIPTING_LANG"  "$SLANG"
            [ -n "$CLOUD" ] && _forge_sub_text_file "$RR" "CLOUD_PROVIDER"  "$CLOUD"
            [ -n "$WENG"  ] && _forge_sub_text_file "$RR" "WORKFLOW_ENGINE" "$WENG"
            [ -n "$PSLUG" ] && _forge_sub_text_file "$RR" "project"         "$PSLUG"
            echo "  ✓ router-rules skeleton stack tokens resolved (residuals, if any, are deploy-block-gated)"
        fi
    fi

    # --- D-11 self-assert: routing did NOT leak into gate.config.json ------------
    local GC="$PROJECT_DIR/.claude/gate.config.json"
    if [ -f "$GC" ] && grep -Eq '"?(model_router|cross_vendor_voices|adversarial_reviewers)"?' "$GC" 2>/dev/null; then
        echo "ERROR (D-11): routing keys found in gate.config.json — the security-hot config must never carry routing. Fail-closed." >&2
        return 1
    fi
    return 0
}

# ============================================================================
# [SENSIBLE] key handling + auth probe (AC-5-2 / AC-5-3)
# ----------------------------------------------------------------------------
# Invariants (cross-vendor no-waiver surface):
#   - keys read with `read -s` (no echo) or from stdin — NEVER from argv.
#   - keys reach curl via a `-K -` stdin config — NEVER in curl's argv (so a
#     `ps aux` during the probe shows no key). `printf` is a bash BUILTIN, so the
#     header line carrying the key is never a separate process's argv either.
#   - the response body is discarded (`--output /dev/null`) — never printed.
#   - no `set -x` anywhere in this file; `umask 077` before any key write.
#   - .env.local store is gitignore-PRECHECKED + chmod 600. keychain is offered
#     with a documented argv caveat (macOS `security` has no stdin-password mode).
# F12 calibration (feedback_security_finding_calibration): /proc + `ps e` env
# scanning is template-hardening guidance, NOT a gate on the single-operator box
# (a /proc read there = already-owned). The argv + repo-key-scan + output-redaction
# assertions are the real teeth and are what the oracle checks.
# ============================================================================

# executor → canonical env-var / keychain-service name
_keyvar_for() {  # $1=executor
    case "$1" in
        openai|codex|codex-cli)   echo "OPENAI_API_KEY" ;;
        openrouter)               echo "OPENROUTER_API_KEY" ;;
        deepseek)                 echo "DEEPSEEK_API_KEY" ;;
        gemini|google|gemini-cli) echo "GEMINI_API_KEY" ;;
        anthropic|claude)         echo "ANTHROPIC_API_KEY" ;;
        *) printf '%s' "$1" | tr '[:lower:]-' '[:upper:]_' | sed 's/$/_API_KEY/' ;;
    esac
}

# PINNED endpoint allowlist (hardcoded; config-supplied hosts are rejected).
_allowed_hosts() { printf '%s\n' api.openai.com openrouter.ai api.deepseek.com generativelanguage.googleapis.com; }

# Pinned AUTH-GATED probe endpoint per executor. CRITICAL: the endpoint MUST require
# auth so an INVALID key returns 401 — otherwise the probe false-greens. OpenRouter's
# /api/v1/models is PUBLIC (returns 200 with no/any key), so it is unusable as an auth
# probe; its auth-gated endpoint is /api/v1/key (401 on invalid key). OpenAI/DeepSeek
# /models and Gemini /models all require auth. (Surfaced by the AC-5-2/5-3 oracle —
# a fake key PASSED against openrouter /models; deviation logged for the consolidated review.)
_endpoint_for() {  # $1=executor → pinned auth-gated endpoint (or empty + rc 2)
    case "$1" in
        openai|codex|codex-cli)   echo "https://api.openai.com/v1/models" ;;
        openrouter)               echo "https://openrouter.ai/api/v1/key" ;;
        deepseek)                 echo "https://api.deepseek.com/user/balance" ;;
        gemini|google|gemini-cli) echo "https://generativelanguage.googleapis.com/v1beta/models" ;;
        *) return 2 ;;
    esac
}

# accept only https + an allowlisted host (exact). Rejects any config-supplied URL
# whose host is not pinned — closes the "typo'd/malicious endpoint → exfil" threat.
_endpoint_allowed() {  # $1=url
    local url="$1" scheme host
    scheme="${url%%://*}"
    [ "$scheme" = "https" ] || return 1
    host="${url#*://}"; host="${host%%/*}"; host="${host%%:*}"
    _allowed_hosts | grep -qxF "$host"
}

# HTTP status → outcome. 000/5xx = UNREACHABLE (network), 401/403 = FAIL-auth,
# 429/402/other-4xx = VISIBLE non-PASS (rate-limit/quota/denied are NEVER PASS).
_classify_probe() {  # $1=http_status
    case "$1" in
        2??)        echo "PASS" ;;
        401|403)    echo "FAIL-auth" ;;
        429)        echo "RATE-LIMITED" ;;
        402)        echo "QUOTA" ;;
        000|"")     echo "UNREACHABLE" ;;
        5??)        echo "UNREACHABLE" ;;
        4??)        echo "FAIL-other" ;;
        *)          echo "UNREACHABLE" ;;
    esac
}

# .env.local is gitignored? Inside a git repo, `git check-ignore` is AUTHORITATIVE —
# a NOT-ignored verdict must NEVER be overridden by a looser .gitignore-pattern grep
# (a bare `.env` line false-matches `.env.local` → a key would be written to a TRACKED
# file). Only fall back to the grep when the dir is NOT a git repo (check-ignore absent).
_env_local_ignored() {  # $1=project-dir
    local d="$1"
    if ( cd "$d" && git rev-parse --git-dir >/dev/null 2>&1 ); then
        ( cd "$d" && git check-ignore -q .env.local ) 2>/dev/null   # authoritative; its rc IS the answer
        return $?
    fi
    grep -qE '(^|/)\.env(\.local|\.\*)?[[:space:]]*$' "$d/.gitignore" 2>/dev/null
}

cmd_keys() {
    umask 077
    local executor="" store="env-local" project_dir="." from_stdin=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --executor)    executor="$2"; shift 2 ;;
            --store)       store="$2"; shift 2 ;;
            --project-dir) project_dir="$2"; shift 2 ;;
            --stdin)       from_stdin=1; shift ;;
            *) echo "keys: unknown option '$1'" >&2; return 2 ;;
        esac
    done
    [ -n "$executor" ] || { echo "keys: --executor required" >&2; return 2; }

    # --- read the key WITHOUT argv exposure --------------------------------------
    local KEY=""
    if [ "$from_stdin" -eq 1 ]; then
        IFS= read -r KEY || true                       # piped in — not in any argv
    elif [ -t 0 ]; then
        printf 'Paste %s API key (input hidden): ' "$executor" >&2
        IFS= read -rs KEY || true; printf '\n' >&2     # -s: no terminal echo
    else
        echo "keys: no TTY and no --stdin — refusing to read a key non-interactively without --stdin" >&2
        return 2
    fi
    [ -n "$KEY" ] || { echo "keys: empty key — nothing stored" >&2; return 2; }

    local var; var="$(_keyvar_for "$executor")"
    case "$store" in
        env-local)
            _env_local_ignored "$project_dir" || {
                echo "keys: .env.local is NOT gitignored in $project_dir — refusing to write a key to a trackable file" >&2
                unset KEY; return 1; }
            local envf="$project_dir/.env.local" tmp
            tmp="$(mktemp)"; chmod 600 "$tmp"
            [ -f "$envf" ] && grep -vE "^${var}=" "$envf" > "$tmp" 2>/dev/null
            { printf '%s=%s\n' "$var" "$KEY"; } >> "$tmp"   # printf is a BUILTIN → key not in any ps argv
            mv "$tmp" "$envf"; chmod 600 "$envf"
            echo "  ✓ ${var} stored in .env.local (chmod 600, gitignored)" >&2
            ;;
        keychain)
            # DROPPED for v1 (review batch): macOS `security add-generic-password -w VALUE`
            # exposes VALUE in argv (no stdin-password mode), violating the NEVER-argv
            # invariant on this [SENSIBLE] write path. The argv-safe `.env.local` store is
            # the default. An argv-safe keychain write (interactive tty prompt) is Phase 22.1.
            echo "keys: --store keychain is DROPPED for v1 (the 'security -w' write exposes the key in argv)." >&2
            echo "      Use the argv-safe default (.env.local). The probe READ path already supports keychain;" >&2
            echo "      an argv-safe keychain WRITE (tty prompt) is Phase 22.1." >&2
            unset KEY; return 2 ;;
        *) echo "keys: unknown --store '$store' (env-local; keychain DROPPED for v1)" >&2; unset KEY; return 2 ;;
    esac
    unset KEY
    return 0
}

# resolve a key for the probe WITHOUT argv: env > .env.local > keychain.
_resolve_key() {  # $1=executor  $2=project-dir → key on stdout (or empty)
    local var k=""; var="$(_keyvar_for "$1")"
    k="${!var:-}"
    [ -z "$k" ] && [ -f "$2/.env.local" ] && k="$(grep -E "^${var}=" "$2/.env.local" 2>/dev/null | head -1 | cut -d= -f2-)"
    [ -z "$k" ] && k="$(security find-generic-password -a "$USER" -s "$var" -w 2>/dev/null || true)"
    printf '%s' "$k"
}

cmd_probe() {
    umask 077
    local executor="" project_dir="." endpoint=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --executor)    executor="$2"; shift 2 ;;
            --project-dir) project_dir="$2"; shift 2 ;;
            --endpoint)    endpoint="$2"; shift 2 ;;
            *) echo "probe: unknown option '$1'" >&2; return 2 ;;
        esac
    done
    [ -n "$executor" ] || { echo "probe: --executor required" >&2; return 2; }

    local pinned; pinned="$(_endpoint_for "$executor")" || { echo "probe[$executor]: no pinned endpoint — unknown executor" >&2; return 2; }
    # EXACT-TUPLE pinning (scheme+host+PATH): a supplied --endpoint must EQUAL the pinned
    # auth-gated endpoint byte-for-byte. Host-only acceptance would let the PUBLIC
    # `…/api/v1/models` (200 with any key) through → false-GREEN. The default is the pinned
    # endpoint; --endpoint can only re-state it (or is rejected). (_endpoint_allowed stays a
    # host/scheme defense-in-depth helper; the exact match is the real guard.)
    if [ -n "$endpoint" ]; then
        if [ "$endpoint" != "$pinned" ]; then
            echo "probe[$executor]: --endpoint must EXACTLY equal the pinned auth-gated endpoint ($pinned)." >&2
            echo "                  Arbitrary endpoints — incl. the PUBLIC ${pinned%/*}/models — are rejected (false-green guard)." >&2
            return 3
        fi
    else
        endpoint="$pinned"
    fi

    local KEY; KEY="$(_resolve_key "$executor" "$project_dir")"
    [ -n "$KEY" ] || { echo "  probe[$executor]: NO KEY stored — run 'keys --executor $executor' first" >&2; return 2; }
    command -v curl >/dev/null 2>&1 || { unset KEY; echo "  probe[$executor]: curl absent → UNREACHABLE (install curl)" >&2; return 4; }

    local hdr
    case "$executor" in
        gemini|google|gemini-cli) hdr="x-goog-api-key: $KEY" ;;
        *) hdr="Authorization: Bearer $KEY" ;;
    esac
    # key reaches curl ONLY via the -K - stdin config (printf builtin → no ps argv);
    # no -L (cross-host redirects off); body discarded (--output /dev/null = redaction).
    local status
    status="$(printf 'header = "%s"\nurl = "%s"\n' "$hdr" "$endpoint" \
              | curl -K - --silent --show-error --max-time 10 --output /dev/null --write-out '%{http_code}' 2>/dev/null)"
    unset KEY hdr
    local outcome; outcome="$(_classify_probe "$status")"
    case "$outcome" in
        PASS)        echo "  probe[$executor] ${endpoint} → PASS (HTTP $status)"; return 0 ;;
        FAIL-auth)   echo "  probe[$executor] ${endpoint} → FAIL-auth (HTTP $status) — invalid key, re-key: 'keys --executor $executor'" >&2; return 10 ;;
        UNREACHABLE) echo "  probe[$executor] ${endpoint} → UNREACHABLE (HTTP $status) — check connectivity" >&2; return 11 ;;
        *)           echo "  probe[$executor] ${endpoint} → ${outcome} (HTTP $status) — visible non-PASS" >&2; return 12 ;;
    esac
}

# ============================================================================
# OpenRouter MCP wiring + launch-env (AC-5-4) — the false-green fix
# ----------------------------------------------------------------------------
# The naive `.mcp.json` env-ref form  "env": {"OPENROUTER_API_KEY":"${OPENROUTER_API_KEY}"}
# FALSE-GREENS: at GUI launch the parent env is usually empty → ${...} resolves to ""
# → the MCP 401s, while a side-channel curl with the raw key passes (the bug in
# reference_openrouter_mcp_401_fix). The FIX is a GUI-launch-safe WRAPPER that
# RESOLVES the key (keychain → .env.local) INSIDE the launch command before `exec`,
# so the key reaches the spawn env regardless of the GUI env. The key is referenced
# by NAME only — never a literal in .mcp.json.
#
# F13 teeth: the launch-path probe runs the WRAPPER's key-resolution+export slice
# VERBATIM (parsed from .mcp.json, asserted byte-equal), so the probe exercises the
# SAME env-resolution the GUI does — the fix cannot itself false-green via a bespoke
# path. Only the terminal `exec node <server>` is replaced by the AC-5-3 auth probe
# (the MCP server cannot run headless inside a probe); the env-resolution surface —
# the entire false-green surface — is byte-for-byte the GUI's.
# ============================================================================

# the GUI-launch-safe wrapper script (generic: keychain → .env.local; absolute
# .env.local path baked at wire time; server path from $OPENROUTER_MCP_SERVER).
_openrouter_launcher() {  # $1=abs-project-dir → the bash -c script string
    local abs="$1"
    printf '%s' "export OPENROUTER_API_KEY=\"\$(security find-generic-password -a \"\$USER\" -s OPENROUTER_API_KEY -w 2>/dev/null || grep -E '^OPENROUTER_API_KEY=' \"${abs}/.env.local\" 2>/dev/null | head -1 | cut -d= -f2-)\"; exec node \"\${OPENROUTER_MCP_SERVER:?set OPENROUTER_MCP_SERVER to the openrouter MCP server entrypoint}\""
}

# does model_router declare openrouter as an OpenAI voice?
_openrouter_declared() {  # $1=forge.config.json
    [ -f "$1" ] && jq -e '[.model_router.cross_vendor_voices.openai // [] | .[]] | index("openrouter") != null' "$1" >/dev/null 2>&1
}

cmd_mcp() {
    local action="${1:-}"; shift || true
    local project_dir="."
    while [ $# -gt 0 ]; do
        case "$1" in
            --project-dir) project_dir="$2"; shift 2 ;;
            *) echo "mcp: unknown option '$1'" >&2; return 2 ;;
        esac
    done
    local abs; abs="$(cd "$project_dir" 2>/dev/null && pwd)" || { echo "mcp: project-dir not found: $project_dir" >&2; return 2; }
    local FC="$abs/.claude/forge.config.json" MCP="$abs/.mcp.json"

    case "$action" in
        wire)
            [ -f "$MCP" ] || printf '{\n  "mcpServers": {}\n}\n' > "$MCP"
            jq -e . "$MCP" >/dev/null 2>&1 || { echo "mcp wire: .mcp.json invalid JSON" >&2; return 2; }
            if _openrouter_declared "$FC"; then
                local launcher tmp; launcher="$(_openrouter_launcher "$abs")"; tmp="$(mktemp)"
                jq --arg cmd "bash" --arg flag "-c" --arg script "$launcher" '
                    .mcpServers = (.mcpServers // {})
                    | .mcpServers.openrouter = { type: "stdio", command: $cmd, args: [$flag, $script], env: {} }
                ' "$MCP" > "$tmp" 2>/dev/null && jq -e . "$tmp" >/dev/null 2>&1 || { echo "mcp wire: failed to write entry (fail-closed)" >&2; rm -f "$tmp"; return 1; }
                mv "$tmp" "$MCP"
                # no literal key may have landed
                grep -Eq 'sk-or-v1-[A-Za-z0-9]|sk-[A-Za-z0-9]{20}' "$MCP" && { echo "mcp wire: a literal key shape is present in .mcp.json — fail-closed" >&2; return 1; }
                echo "  ✓ .mcp.json openrouter entry wired (GUI-launch-safe wrapper, key by name only)" >&2
            else
                # not declared → prune any stale entry (idempotent), warn if pruned
                if jq -e '.mcpServers.openrouter' "$MCP" >/dev/null 2>&1; then
                    local tmp; tmp="$(mktemp)"
                    jq 'del(.mcpServers.openrouter)' "$MCP" > "$tmp" && mv "$tmp" "$MCP"
                    echo "  ⚠ openrouter not in model_router — pruned the stale .mcp.json openrouter entry" >&2
                else
                    echo "  · openrouter not declared — no .mcp.json mutation" >&2
                fi
            fi
            ;;
        probe)
            # LAUNCH-PATH probe: run the .mcp.json wrapper's key-resolution slice VERBATIM
            # (F13 byte-for-byte), then auth-probe the resolved key. Catches the launch-env
            # gap the old direct-curl probe missed.
            [ -f "$MCP" ] || { echo "  mcp probe: no .mcp.json — run 'mcp wire' first" >&2; return 2; }
            jq -e '.mcpServers.openrouter' "$MCP" >/dev/null 2>&1 || { echo "  mcp probe: no openrouter entry in .mcp.json" >&2; return 2; }
            local script resolve_slice
            script="$(jq -r '.mcpServers.openrouter.args[1] // ""' "$MCP")"
            [ -n "$script" ] || { echo "  mcp probe: openrouter entry has no launch script" >&2; return 2; }
            resolve_slice="${script%%; exec*}"   # the key-resolution+export, verbatim from .mcp.json
            # F13 (review fix): run the auth probe in the SAME child shell that ran the
            # launcher's resolve slice, so curl authenticates with the EXACT key the
            # .mcp.json launcher exports — NOT an independent re-resolution that could
            # diverge from the launcher (the old cmd_probe call re-read env/.env.local/
            # keychain → could PASS on a good .env.local key while the launcher exported a
            # bad one). Key reaches curl via -K - stdin (printf builtin → no argv); empty
            # key (launch-env gap) → status 000; body discarded; status only is printed.
            local op_endpoint; op_endpoint="$(_endpoint_for openrouter)"
            local status
            status="$(bash -c "${resolve_slice}
if [ -z \"\${OPENROUTER_API_KEY:-}\" ]; then printf '000'; exit 0; fi
printf 'header = \"Authorization: Bearer %s\"\nurl = \"%s\"\n' \"\$OPENROUTER_API_KEY\" \"${op_endpoint}\" | curl -K - --silent --show-error --max-time 15 --output /dev/null --write-out '%{http_code}'" 2>/dev/null)"
            local outcome; outcome="$(_classify_probe "$status")"
            case "$outcome" in
                PASS)        echo "  mcp probe[openrouter] ${op_endpoint} (via .mcp.json launcher) → PASS (HTTP $status)"; return 0 ;;
                UNREACHABLE) echo "  mcp probe[openrouter] → FAIL launch-env/unreachable (HTTP $status) — key did NOT resolve into the spawn env, or network" >&2; return 10 ;;
                FAIL-auth)   echo "  mcp probe[openrouter] → FAIL-auth (HTTP $status) — the launcher resolved an INVALID key" >&2; return 10 ;;
                *)           echo "  mcp probe[openrouter] → ${outcome} (HTTP $status) — visible non-PASS" >&2; return 12 ;;
            esac
            ;;
        *) echo "mcp: unknown action '$action' (wire|probe)" >&2; return 2 ;;
    esac
    return 0
}

# ── dispatch (source-safe: when sourced, only the functions load) ─────────────
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    SUB="${1:-}"; shift || true
    case "$SUB" in
        routing) cmd_routing "$@" ;;
        keys)    cmd_keys "$@" ;;
        probe)   cmd_probe "$@" ;;
        mcp)     cmd_mcp "$@" ;;
        ""|-h|--help)
            sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) echo "forge-setup-executors: unknown subcommand '$SUB' (have: routing keys probe mcp)" >&2; exit 2 ;;
    esac
fi
