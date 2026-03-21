# Validation Deep Reference

Extended reference for n8n validation — content folded from the former `n8n-validation-expert` skill.

## n8n v2.0 Migration Validation

### Migration Report Tool
n8n v2.0 includes a **Migration Report** (Settings → Migration Report). Requires global admin, available on v1.119.0+.

**What it scans:**

*Workflow-level issues* — specific nodes or behaviors that break in v2.0:
- Python Code nodes using Pyodide syntax (dot notation, `_input`, `_json`)
- Code nodes accessing `$env` (blocked by default)
- ExecuteCommand / LocalFileTrigger nodes (disabled by default)
- Sub-workflows with Wait nodes (behavior changed — now returns end-of-workflow data)

*Instance-level issues* — environment and config problems:
- MySQL/MariaDB as storage backend (no longer supported)
- Deprecated env vars (`N8N_CONFIG_FILES`, `QUEUE_WORKER_MAX_STALLED_COUNT`)
- Legacy SQLite driver (replaced by pooling driver)

**Severity levels:** Critical (will break — fix before upgrading), Medium (may cause issues), Low (cleanup).

**Process:** Fix all Critical issues → Refresh report → Clean report = ready to upgrade.

### v2.0 Validation Checklist
When validating workflows for v2.0 compatibility:
- [ ] No Python Code nodes using dot notation (`item.json.field` → `item["json"]["field"]`)
- [ ] No Python Code nodes using `_input`, `_json`, `_node` (use `_items` / `_item` only)
- [ ] No Code nodes depending on `$env` without the override set
- [ ] No ExecuteCommand or LocalFileTrigger without NODES_EXCLUDE override
- [ ] Sub-workflow Wait node behavior reviewed
- [ ] Workflow published after changes (Save ≠ Deploy in v2.0)

## Workflow-Level Validation

### Common Structural Errors

**Broken connections**: A connection references a node that was deleted or renamed.
→ Fix: Reconnect nodes in the editor, or rebuild the connection in workflow JSON.

**Circular dependencies**: Node A → Node B → Node A.
→ Fix: Break the cycle. If you need a loop, use Split In Batches or a scheduled re-trigger.

**Disconnected nodes**: A node exists but has no input connections (orphan).
→ Fix: Connect it or delete it.

**Multiple start nodes**: More than one trigger node in a workflow.
→ Fix: Remove extra triggers. One workflow = one trigger (use sub-workflows for multiple entry points).

## Recovery Strategies

When validation finds issues too complex to fix inline:

**Strategy 1: Start fresh** — Rebuild the broken section from scratch. Often faster than debugging corrupt node state.

**Strategy 2: Binary search** — Disable half the nodes, validate. If it passes, the bug is in the disabled half. Narrow down.

**Strategy 3: Clean stale connections** — Export workflow JSON, remove orphaned connection entries, re-import.

**Strategy 4: Use auto-fix** — Let the validation auto-sanitization handle what it can, then manually fix the rest.
