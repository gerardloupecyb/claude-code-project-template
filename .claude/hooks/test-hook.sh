#!/bin/bash
# test-hook.sh — Single hook smoke test helper.
# Validates a single hook by name: syntax, trap invariant, shebang, no yq.
# Per VALIDATION.md: quick verification before/after each hook modification.
#
# Usage:
#   bash .claude/hooks/test-hook.sh pre-compact.sh    # test a hook
#   bash .claude/hooks/test-hook.sh pre-compact       # .sh extension optional
#   bash .claude/hooks/test-hook.sh --check-deps      # verify python3 yaml available

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="${SCRIPT_DIR}"

# Gate hooks (exit 2 = block by design) — exempt from trap 'exit 0' EXIT invariant
GATE_HOOKS=("pre-tool-use.sh" "pre-mcp-gate.sh")

is_gate_hook() {
    local hook="$1"
    for gate in "${GATE_HOOKS[@]}"; do
        [ "$gate" = "$hook" ] && return 0
    done
    return 1
}

# --check-deps: confirm python3 yaml availability (RESEARCH.md: PyYAML is installed, yq is NOT)
if [ "${1:-}" = "--check-deps" ]; then
    if python3 -c "import yaml; print('PyYAML available')" 2>/dev/null; then
        echo "PASS: python3 yaml (PyYAML) is available"
        exit 0
    else
        echo "FAIL: python3 yaml (PyYAML) not available — install with: pip install pyyaml"
        exit 1
    fi
fi

# Require exactly one argument (hook name)
if [ $# -lt 1 ]; then
    echo "Usage: bash .claude/hooks/test-hook.sh <hook-name>"
    echo "       bash .claude/hooks/test-hook.sh --check-deps"
    exit 1
fi

HOOK_ARG="$1"
# Add .sh extension if missing
HOOK_NAME="${HOOK_ARG%.sh}.sh"
HOOK_PATH="${HOOKS_DIR}/${HOOK_NAME}"

PASS=true
FAIL_REASON=""

fail() {
    PASS=false
    FAIL_REASON="${1}"
}

# Check 1: file exists
if [ ! -f "$HOOK_PATH" ]; then
    echo "FAIL: ${HOOK_NAME} — file not found at ${HOOK_PATH}"
    exit 1
fi

# Check 2: syntax check
if ! bash -n "$HOOK_PATH" 2>/dev/null; then
    fail "bash syntax error (bash -n failed)"
fi

# Check 3: shebang
FIRST_LINE=$(head -1 "$HOOK_PATH")
if [ "$FIRST_LINE" != "#!/bin/bash" ]; then
    fail "missing or wrong shebang (expected #!/bin/bash, got: ${FIRST_LINE})"
fi

# Check 4: trap invariant (gate hooks are exempt — they exit 2 by design)
if ! is_gate_hook "$HOOK_NAME"; then
    if ! grep -q "trap.*exit 0" "$HOOK_PATH" 2>/dev/null; then
        fail "missing trap 'exit 0' EXIT invariant (hook must never block)"
    fi
fi

# Check 5: no yq usage (yq is NOT installed per RESEARCH.md — use python3 yaml instead)
if grep -qE "^[^#]*\byq\b" "$HOOK_PATH" 2>/dev/null; then
    fail "uses 'yq' which is NOT installed — replace with python3 yaml.safe_load"
fi

# Report result
if $PASS; then
    echo "PASS: ${HOOK_NAME}"
    exit 0
else
    echo "FAIL: ${HOOK_NAME} — ${FAIL_REASON}"
    exit 1
fi
