---
name: n8n-node-expert
description: "Configure n8n nodes, write expressions, and fix validation errors. Use this skill whenever the user needs help configuring a specific n8n node's parameters, writing or debugging n8n expressions (the {{$json.field}} syntax), interpreting validation errors, understanding property dependencies (displayOptions), choosing validation profiles, or fixing operator structure issues in IF/Switch nodes. Also trigger when the user mentions n8n expressions, $json, $node, $input, validation profiles (minimal/runtime/ai-friendly/strict), missing_required errors, auto-sanitization, or asks why is this field required or why is my expression not working. For workflow-level design and architecture, defer to n8n-workflow-architect. For writing Code node logic (JavaScript/Python), defer to n8n-code-nodes."
---

# n8n Node Expert

Configure nodes correctly, write valid expressions, and resolve validation errors. This skill covers everything at the individual node level.

## When to Use Other Skills

- **Designing workflows, choosing patterns, MCP tool orchestration** → use `n8n-workflow-architect`
- **Writing JavaScript/Python code inside Code nodes** → use `n8n-code-nodes`
- **Configuring individual nodes, writing expressions, fixing errors** → you're in the right place

## n8n v2.0 Changes

### Save vs Publish
n8n v2.0 separates editing from deployment:
- **Save** = stores your edits as a draft. Production keeps running the last published version.
- **Publish** = pushes changes to production.

Node configuration changes only take effect after **publishing**. If changes "aren't working," check if you've published.

### Disabled Nodes
ExecuteCommand and LocalFileTrigger are **disabled by default** in v2.0. If a workflow needs them, update `NODES_EXCLUDE` in environment config.

---

## Expression Syntax

All dynamic content in n8n uses double curly braces: `{{expression}}`

### Core Variables

**$json** — Current node's output data:
```javascript
{{$json.fieldName}}
{{$json['field with spaces']}}
{{$json.nested.property}}
{{$json.items[0].name}}
```

**$node** — Reference any previous node's output:
```javascript
{{$node["Node Name"].json.fieldName}}
{{$node["HTTP Request"].json.data}}
```
Node names are case-sensitive and must be in quotes.

**$now** — Current timestamp (Luxon DateTime):
```javascript
{{$now.toFormat('yyyy-MM-dd')}}
{{$now.plus({days: 7}).toISO()}}
```

**$vars** — n8n Variables (read-only, configured in UI):
```javascript
{{$vars.MY_VARIABLE}}
```

**$env** — Environment variables:
```javascript
{{$env.API_KEY}}
```

### CRITICAL: Webhook Data Structure

The most common mistake in n8n. Webhook data is nested under `.body`, not at root.

```javascript
// Webhook node output structure:
{
  "headers": {...},
  "params": {...},
  "query": {...},
  "body": {           // ← USER DATA IS HERE
    "name": "John",
    "email": "john@example.com"
  }
}

❌ {{$json.name}}         // undefined
❌ {{$json.email}}        // undefined
✅ {{$json.body.name}}    // "John"
✅ {{$json.body.email}}   // "john@example.com"
```

### Expression Contexts

**In regular node fields** — use `{{ }}`:
```javascript
"text": "={{$json.body.name}}"
"url": "https://api.example.com/users/{{$json.body.user_id}}"
```

**In Code nodes** — NO `{{ }}`, use JavaScript directly:
```javascript
❌ const email = '={{$json.email}}';
✅ const email = $json.email;
✅ const email = $input.first().json.email;
```

**In webhook paths and credential fields** — expressions NOT supported, use static values.

### Common Expression Patterns

**Conditional content:**
```javascript
{{$json.status === 'active' ? 'Active' : 'Inactive'}}
{{$json.email || 'no-email@example.com'}}
```

**Date formatting:**
```javascript
{{$now.toFormat('yyyy-MM-dd HH:mm')}}
{{DateTime.fromISO($json.created_at).toFormat('MMMM dd, yyyy')}}
{{$now.minus({hours: 24}).toISO()}}
```

**String operations:**
```javascript
{{$json.name.toLowerCase()}}
{{$json.message.replace('old', 'new')}}
{{$json.email.substring(0, $json.email.indexOf('@'))}}
```

**Array operations:**
```javascript
{{$json.users[0].email}}
{{$json.users.length}}
```

### Quick Fix Reference

| Symptom | Fix |
|---------|-----|
| Expression shows as literal text | Add `{{ }}` around it |
| `$json.name` returns undefined (webhook) | Use `$json.body.name` |
| `{{$node.HTTP Request}}` fails | Use `{{$node["HTTP Request"]}}` (quotes!) |
| Expression in Code node not working | Remove `{{ }}`, use JS directly |
| "Cannot read property of undefined" | Check data path, use optional chaining: `$json?.user?.email` |

For complete error catalog and real workflow examples, see [references/expressions-deep-dive.md](references/expressions-deep-dive.md)

---

## Node Configuration

### The Core Principle: Operation Determines Requirements

Not all fields are always required — it depends on the resource + operation combination.

```javascript
// Slack: "post" operation requires channel + text
{resource: "message", operation: "post", channel: "#general", text: "Hello!"}

// Slack: "update" operation requires messageId + text (NOT channel)
{resource: "message", operation: "update", messageId: "123", text: "Updated!"}
```

Always check requirements when changing operation.

### Configuration Workflow

```
1. Identify node type + desired operation
2. get_node_essentials({nodeType: "nodes-base.name"})  ← start here
3. Configure required fields for that operation
4. validate_node_operation({..., profile: "runtime"})
5. Fix errors, validate again (2-3 cycles is normal)
6. If stuck → get_property_dependencies({nodeType: "..."})
7. If still stuck → get_node_info({nodeType: "..."})
```

### Progressive Discovery

**get_node_essentials** (91.7% success, <10ms, ~5KB) — **Always start here.** Returns operations, required fields, common options, examples. Covers 90% of configuration needs.

**get_property_dependencies** — Shows which fields appear/disappear based on other values. Use when essentials isn't enough to understand conditional requirements.

**get_node_info** (80% success, slow, 100KB+) — Full schema. Only use when essentials + dependencies both insufficient.

### Property Dependencies (displayOptions)

Fields have visibility rules. A field may only appear when other fields have specific values.

**Example: HTTP Request body field**
```
body is visible when:
  sendBody = true AND
  method IN (POST, PUT, PATCH, DELETE)
```

**Example: IF node value2 field**
```
value2 is visible when:
  operation IN (equals, contains, greaterThan, ...)  // binary operators
value2 is hidden when:
  operation IN (isEmpty, isNotEmpty)                   // unary operators
```

Discovering dependencies:
```javascript
get_property_dependencies({nodeType: "nodes-base.httpRequest"})
// Returns: {body: {shows_when: {sendBody: [true], method: ["POST","PUT","PATCH","DELETE"]}}}
```

### Common Node Configuration Patterns

#### Resource/Operation Nodes (Slack, Google Sheets, Airtable)
```javascript
{
  "resource": "<entity>",      // message, channel, user, row...
  "operation": "<action>",     // post, update, delete, get, getAll...
  // ... operation-specific fields
}
```

#### HTTP Method Nodes (HTTP Request, Webhook)
```javascript
{
  "method": "POST",
  "url": "https://api.example.com",
  "authentication": "predefinedCredentialType",
  "sendBody": true,               // POST/PUT/PATCH → body available
  "body": {
    "contentType": "json",
    "content": {"key": "={{$json.value}}"}
  }
}
```

**Dependencies chain:** method=POST → sendBody available → sendBody=true → body required

#### Conditional Logic Nodes (IF, Switch)
```javascript
// IF node — binary operator (two values)
{
  "conditions": {
    "string": [{
      "value1": "={{$json.status}}",
      "operation": "equals",
      "value2": "active"
    }]
  }
}

// IF node — unary operator (one value)
{
  "conditions": {
    "string": [{
      "value1": "={{$json.email}}",
      "operation": "isEmpty"
      // singleValue: true ← added automatically by auto-sanitization
    }]
  }
}
```

#### Database Nodes (Postgres, MySQL, MongoDB)
```javascript
// executeQuery: query required
{operation: "executeQuery", query: "SELECT * FROM users WHERE id = $1", ...}

// insert: table + values required
{operation: "insert", table: "users", columns: "name,email", ...}

// update: table + values + where required
{operation: "update", table: "users", columns: "status", where: "id = $1", ...}
```

---

## Validation

### The Validation Loop

Validation is iterative — expect 2-3 cycles. This is normal workflow:

```
Configure → Validate → Read errors → Fix → Validate again → Deploy
                    (23s thinking)  (58s fixing)
```

### Validation Profiles

Choose based on your stage:

| Profile | Use When | Checks |
|---------|----------|--------|
| `minimal` | Quick checks during editing | Required fields, basic structure |
| `runtime` | **Pre-deployment (recommended)** | Required fields + value types + allowed values |
| `ai-friendly` | AI-generated configurations | Like runtime but fewer false positives |
| `strict` | Production critical workflows | Everything + best practices + security |

```javascript
validate_node_operation({
  nodeType: "nodes-base.slack",
  config: {resource: "message", operation: "post", channel: "#general", text: "Hi"},
  profile: "runtime"  // Always specify explicitly
})
```

### Error Types

**Errors (must fix — blocks execution):**

| Type | Meaning | Fix |
|------|---------|-----|
| `missing_required` | Required field not provided | Add the field (check essentials) |
| `invalid_value` | Value not in allowed options | Check error for valid options |
| `type_mismatch` | Wrong data type | Convert (e.g., string "100" → number 100) |
| `invalid_reference` | Referenced node doesn't exist | Check node name spelling (case-sensitive!) |
| `invalid_expression` | Expression syntax error | Check `{{ }}` wrapping, variable paths |

**Warnings (should fix — won't block but may cause issues):**
- `best_practice` — Recommended improvement (e.g., add error handling)
- `deprecated` — Using old API/feature
- `performance` — Potential performance issue

**Suggestions (optional improvements):**
- `optimization` — Could be more efficient
- `alternative` — Better approach available

### Reading Validation Results

```javascript
const result = validate_node_operation({...});

if (result.valid) {
  // ✅ Ready to deploy
} else {
  // Fix errors first
  result.errors.forEach(err => {
    console.log(`${err.property}: ${err.message}`);
    console.log(`Fix: ${err.fix}`);
  });
  // Then review warnings
  result.warnings.forEach(warn => {
    console.log(`Warning: ${warn.message} → ${warn.suggestion}`);
  });
}
```

### Auto-Sanitization

Every workflow save/update automatically fixes operator structures:

**Binary operators** (equals, contains, greaterThan...): removes `singleValue` property
**Unary operators** (isEmpty, isNotEmpty, true, false): adds `singleValue: true`
**IF/Switch nodes**: adds complete `conditions.options` metadata

Trust auto-sanitization — don't manually fix these issues. Focus on business logic.

**Cannot auto-fix:** broken connections, branch count mismatches, corrupt states. Use `cleanStaleConnections` for broken connections.

### Common False Positives

These warnings are often acceptable:

- "Missing error handling" — OK for simple/test workflows
- "No retry logic" — OK for idempotent operations
- "Missing rate limiting" — OK for low-volume internal APIs
- "Unbounded query" — OK for known small datasets

Use `ai-friendly` profile to reduce noise from false positives.

### Recovery Strategies

**Start fresh** (config severely broken):
1. Get required fields from `get_node_essentials`
2. Build minimal valid config
3. Add features incrementally

**Clean stale connections** (broken node references):
```javascript
n8n_update_partial_workflow({
  id: "workflow-id",
  operations: [{type: "cleanStaleConnections"}]
})
```

**Binary search** (workflow validates but behaves wrong):
1. Remove half the nodes, test
2. Narrow down to broken section
3. Isolate and fix

---

## nodeType Format Rules

**Search/Validate tools** → short prefix:
```
nodes-base.slack
nodes-base.httpRequest
nodes-langchain.agent
```

**Workflow tools** → full prefix:
```
n8n-nodes-base.slack
n8n-nodes-base.httpRequest
@n8n/n8n-nodes-langchain.agent
```

`search_nodes` returns both: `nodeType` (short) and `workflowNodeType` (full).

---

## Reference Files

- **[references/expressions-deep-dive.md](references/expressions-deep-dive.md)** — Complete expression catalog, all methods, error debugging
- **[references/expression-deep-reference.md](references/expression-deep-reference.md)** — $vars, $tool, $execution, data type helpers, debugging
- **[references/expression-examples.md](references/expression-examples.md)** — Real workflow expression examples
- **[references/expression-mistakes.md](references/expression-mistakes.md)** — Common expression mistakes and fixes
- **[references/error-catalog.md](references/error-catalog.md)** — Full error type reference with examples
- **[references/validation-reference.md](references/validation-reference.md)** — v2.0 migration validation, structural errors, recovery strategies
- **[references/operation-patterns.md](references/operation-patterns.md)** — Configuration patterns by node type
- **[references/dependencies.md](references/dependencies.md)** — Property dependency mechanics (displayOptions)
- **[references/false-positives.md](references/false-positives.md)** — When validation warnings are acceptable
