---
name: n8n-code-nodes
description: "Write JavaScript and Python code in n8n Code nodes. Use when writing Code node logic, choosing between JS and Python, using $input/$json/$node (JS) or _input/_items (Python), making HTTP requests with $helpers, working with dates using DateTime/Luxon, troubleshooting Code node errors, or understanding n8n v2.0 task runner changes. Trigger on 'n8n code', 'n8n JavaScript', 'n8n Python', 'n8n Code node', '$input', '$json', '_items', '$helpers', 'httpRequest', 'Code node error', 'task runner', or any request to write custom code in n8n workflows."
---

> **n8n version**: This skill is written for n8n v2.0+. If you're on n8n 1.x, some information (task runners, $env access, Save/Publish, native Python) does not apply.


# n8n Code Nodes

Write JavaScript and Python in n8n Code nodes — updated for n8n v2.0 with task runner isolation.


## When to Use a Different Skill Instead

| If the question is about… | Use this skill instead |
|---------------------------|----------------------|
| `{{ }}` expressions, node config, validation errors | **n8n-node-expert** |
| Workflow architecture, MCP tools, design patterns | **n8n-workflow-architect** |
| GoHighLevel integration (even if n8n is involved) | **ghl-architect** |

## Reference File Routing

| Topic | Reference File | Read When |
|-------|---------------|-----------|
| JS syntax, $input/$json/$helpers, DateTime, $jmespath | `references/javascript.md` | Writing JavaScript in Code nodes |
| Python syntax, _input/_items, native Python, stdlib | `references/python.md` | Writing Python in Code nodes |
| Shared patterns (transform, filter, aggregate, HTTP) | `references/patterns.md` | Looking for code examples in either language |

## n8n v2.0 Breaking Changes (Critical)

### Task Runners (Enabled by Default)
Code nodes now execute in **isolated task runner environments**, not in the main n8n process. This is a security and stability improvement but changes how Code nodes interact with the system.

**What changed:**
- Code nodes run in a sandbox — no direct access to the n8n server process
- `$env` access is **blocked by default** in Code nodes (security hardening)
- ExecuteCommand and LocalFileTrigger nodes are **disabled by default**

**If your workflows use `$env` in Code nodes:**
Set `N8N_BLOCK_ENV_ACCESS_IN_NODE=false` in your n8n environment config to re-enable. For sensitive data, prefer n8n credentials over environment variables.

**If your workflows use ExecuteCommand or LocalFileTrigger:**
Remove them from the disabled nodes list by updating `NODES_EXCLUDE` in your environment config.

### Python: Pyodide → Native Python
The old Pyodide (WebAssembly) implementation is **removed in v2.0**. Python now runs natively via task runners.

**What changed:**
- **Bracket notation only**: `item["json"]["field"]` — dot notation `item.json.field` no longer works
- **Limited built-in variables**: Only `_items` (all-items mode) and `_item` (each-item mode) are supported. Other n8n built-ins (`_input`, `_node`, etc.) are NOT available in native Python.
- **External libraries possible**: If the task runner image includes them AND they're allowlisted in `n8n-task-runners.json`
- **Standard library available**: json, datetime, re, math, collections, etc. still work
- **`_query` for AI tools**: Native Python tools support `_query` for the input string from AI Agents

**Migration from Pyodide:**
```python
# ❌ Old Pyodide (broken in v2.0)
email = _json.email          # Dot notation
data = _input.first().json   # _input built-in

# ✅ New Native Python
email = _items[0]["json"]["email"]  # Bracket notation
data = _items[0]["json"]            # Direct access via _items
```

### Save vs Publish (Workflow Paradigm)
In v2.0, **Save** preserves edits without changing production. **Publish** pushes changes live. This replaces the old behavior where saving an active workflow immediately deployed it.

## Language Selection Guide

### Use JavaScript When:
- You need `$helpers.httpRequest()` for API calls within Code nodes
- You need `DateTime` (Luxon) for date manipulation
- You need `$jmespath()` for complex JSON queries
- You need access to `$input`, `$node`, `$execution`, `$workflow` built-ins
- Performance matters (JS runs faster than Python in n8n)
- **Default choice** — JS has the most mature support in n8n

### Use Python When:
- You're more comfortable with Python and the task is simple
- Data processing with list comprehensions/dict operations
- Statistical analysis with standard library (statistics, math)
- Regex processing (Python's re module is more readable for complex patterns)
- You don't need `$helpers` or other n8n JS built-ins

### Use Other Nodes Instead When:
- Simple field mapping → **Set node** (no code needed)
- Simple conditions → **IF/Switch node**
- Simple data filtering → **Item Lists node**
- Date formatting only → **Date & Time node**

## Essential Rules (Both Languages)

### 1. Always Return an Array of Objects
```javascript
// JavaScript
return [{ json: { key: "value" } }];                    // Single item
return items.map(i => ({ json: { ...i.json, new: 1 } })); // Multiple items

// Python  
return [{"json": {"key": "value"}}]                      # Single item
return [{"json": {**item["json"], "new": 1}} for item in _items]  # Multiple
```

### 2. Mode Selection
**Run Once for All Items** (default, recommended): Process all items in one execution. Access via `$input.all()` (JS) or `_items` (Python).

**Run Once for Each Item**: Runs separately for each input item. Access via `$input.item` (JS) or `_item` (Python). Use when items need independent processing.

### 3. Webhook Data is Nested Under `.body`
See **n8n-node-expert** skill for the canonical reference. In short:
```javascript
// JavaScript: $input.first().json.body.email (NOT .json.email)
// Python:     _items[0]["json"]["body"]["email"]
```

### 4. Null Safety
```javascript
// JavaScript — optional chaining
const city = $input.first().json.address?.city ?? "Unknown";

// Python — .get() with defaults
city = _items[0]["json"].get("address", {}).get("city", "Unknown")
```

## Quick Reference: Data Access

| What | JavaScript | Python |
|------|-----------|--------|
| All items | `$input.all()` | `_items` |
| First item | `$input.first()` | `_items[0]` |
| Current item (each-item mode) | `$input.item` | `_item` |
| Item JSON data | `$input.first().json` | `_items[0]["json"]` |
| Other node's output | `$node["Node Name"].json` | ❌ Not available in native Python |
| Environment variable | `$env.MY_VAR` ⚠️ blocked by default in v2 | ❌ Not available in native Python |
| HTTP request | `$helpers.httpRequest({...})` | ❌ Not available — use HTTP Request node |
| Current timestamp | `DateTime.now()` | `from datetime import datetime; datetime.now()` |
| Execution ID | `$execution.id` | ❌ Not available in native Python |
| AI tool input | N/A | `_query` |

## Error Prevention — Top 5 Mistakes

### 1. Empty Code or Missing Return
Every Code node MUST return data. An empty node or a node that doesn't return causes a silent failure.

### 2. Wrong Return Format
```javascript
// ❌ Returns raw object
return { name: "John" };

// ✅ Returns array of items with json wrapper
return [{ json: { name: "John" } }];
```

### 3. $env Blocked in v2.0
```javascript
// ❌ Fails silently in n8n v2.0 (default config)
const token = $env.API_TOKEN;

// ✅ Use credentials instead, or set N8N_BLOCK_ENV_ACCESS_IN_NODE=false
```

### 4. Python Dot Notation (Broken in v2.0)
```python
# ❌ Pyodide syntax — fails in native Python
name = _json.name

# ✅ Native Python — bracket notation only
name = _items[0]["json"]["name"]
```

### 5. Importing Libraries (Python — all blocked by default in v2.0)
```python
# ❌ ALL imports blocked by default in v2.0 (stdlib AND external)
import json        # blocked unless allowlisted
import pandas      # blocked unless allowlisted

# ✅ To enable imports, configure n8n-task-runners.json:
# Python stdlib:   N8N_RUNNERS_STDLIB_ALLOW="json,re,datetime,math"
# Python external: N8N_RUNNERS_EXTERNAL_ALLOW="numpy,pandas"
# JS builtin:      NODE_FUNCTION_ALLOW_BUILTIN="crypto"
# JS external:     NODE_FUNCTION_ALLOW_EXTERNAL="moment,uuid"
```

## Documentation Lookup Strategy

1. **Built-in references first** — check this skill's reference files
2. **Context7 for unknowns** — if the topic isn't covered or may be outdated, use Context7:
   ```
   Context7:resolve-library-id → libraryName: "n8n"
   Context7:query-docs → query: "<specific question>"
   ```
3. **web_search fallback** — if Context7 is unavailable, search `docs.n8n.io`
4. **Inform the user** — flag when info came from web search vs. built-in reference


## Cross-References

- **n8n-workflow-architect**: For workflow architecture patterns (when to use Code vs other nodes)
- **n8n-node-expert**: For `{{ }}` expressions outside Code nodes, node configuration, validation errors
