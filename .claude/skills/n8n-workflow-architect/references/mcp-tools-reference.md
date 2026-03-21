# n8n MCP Tools Reference

Complete catalog of n8n-mcp tools with parameters and usage patterns.

---

## Node Discovery Tools

### search_nodes (99.9% success, <20ms)
Find nodes by keyword. Returns both short and full nodeType formats.

```javascript
search_nodes({
  query: "slack",     // Search keyword
  mode: "OR",         // OR (any match) or AND (all must match)
  limit: 20           // Max results
})
// Returns: [{nodeType: "nodes-base.slack", workflowNodeType: "n8n-nodes-base.slack", ...}]
```

**Tips:**
- Use short keywords: "slack", "http", "postgres", "ai agent"
- `nodeType` → for search/validate tools
- `workflowNodeType` → for workflow creation tools

### get_node_essentials (91.7% success, <10ms, ~5KB)
Get operations, required fields, and example configs. **Always use this first.**

```javascript
get_node_essentials({
  nodeType: "nodes-base.slack",  // Short prefix!
  includeExamples: true          // Get real template configs
})
```

### get_node_info (80% success, slow, 100KB+)
Full schema with all properties. **Use only when essentials is insufficient.**

```javascript
get_node_info({
  nodeType: "nodes-base.slack"
})
```

### get_node_documentation
Human-readable documentation for a node.

```javascript
get_node_documentation({
  nodeType: "nodes-base.slack"
})
```

### list_nodes
List nodes by category.

```javascript
list_nodes({
  category: "communication"  // or "data", "utility", "ai", etc.
})
```

### search_node_properties
Find specific properties within a node's schema.

```javascript
search_node_properties({
  nodeType: "nodes-base.httpRequest",
  query: "authentication"
})
```

---

## Validation Tools

### validate_node_minimal (97.4% success, <100ms)
Quick check — only required fields and basic structure.

```javascript
validate_node_minimal({
  nodeType: "nodes-base.slack",
  config: {resource: "message", operation: "post"}
})
```

### validate_node_operation (varies, <100ms)
Full validation with profiles. **Use `runtime` profile for most cases.**

```javascript
validate_node_operation({
  nodeType: "nodes-base.slack",
  config: {
    resource: "message",
    operation: "post",
    channel: "#general",
    text: "Hello"
  },
  profile: "runtime"  // minimal | runtime | ai-friendly | strict
})
```

**Profiles:**
- `minimal` — Only required fields (fast, permissive)
- `runtime` — Values + types (**recommended for pre-deployment**)
- `ai-friendly` — Reduced false positives (for AI-generated configs)
- `strict` — Maximum validation (production deployment)

### validate_workflow (95.5% success, 100-500ms)
Validate complete workflow structure, connections, and expressions.

```javascript
validate_workflow({
  workflow: {nodes: [...], connections: {...}},
  options: {
    validateNodes: true,
    validateConnections: true,
    validateExpressions: true,
    profile: "runtime"
  }
})
```

### get_property_dependencies
Show which fields depend on other field values (displayOptions).

```javascript
get_property_dependencies({
  nodeType: "nodes-base.httpRequest"
})
// Returns: {body: {shows_when: {sendBody: [true], method: ["POST","PUT","PATCH"]}}}
```

---

## Workflow Management Tools

**All require n8n API (N8N_API_URL + N8N_API_KEY)**

### n8n_create_workflow (96.8% success, 100-500ms)
Create a new workflow. Uses FULL nodeType prefix.

```javascript
n8n_create_workflow({
  name: "My Workflow",
  nodes: [
    {
      name: "Webhook",
      type: "n8n-nodes-base.webhook",  // Full prefix!
      position: [250, 300],
      parameters: {
        path: "my-webhook",
        httpMethod: "POST"
      }
    }
  ],
  connections: {
    "Webhook": {
      main: [[{node: "Next Node", type: "main", index: 0}]]
    }
  }
})
```

### n8n_update_partial_workflow (99.0% success, 50-200ms)
Edit workflows incrementally. Supports 15 operation types.

**Add node:**
```javascript
n8n_update_partial_workflow({
  id: "workflow-id",
  operations: [{
    type: "addNode",
    node: {
      name: "Slack Alert",
      type: "n8n-nodes-base.slack",
      position: [500, 300],
      parameters: {resource: "message", operation: "post"}
    }
  }]
})
```

**Add connection:**
```javascript
{
  type: "addConnection",
  source: "Webhook",
  target: "Slack Alert",
  sourceIndex: 0  // or use smart params below
}
```

**Smart connection parameters (preferred):**
```javascript
// IF node branches
{type: "addConnection", source: "IF", target: "True Handler", branch: "true"}
{type: "addConnection", source: "IF", target: "False Handler", branch: "false"}

// Switch node cases
{type: "addConnection", source: "Switch", target: "Case A Handler", case: 0}
{type: "addConnection", source: "Switch", target: "Case B Handler", case: 1}
```

**Update node parameters:**
```javascript
{
  type: "updateNodeParameters",
  name: "Slack Alert",
  parameters: {channel: "#alerts", text: "New event!"}
}
```

**Clean stale connections:**
```javascript
{type: "cleanStaleConnections"}
```

### n8n_validate_workflow
Validate a saved workflow by ID.

```javascript
n8n_validate_workflow({id: "workflow-id"})
```

### n8n_list_workflows / n8n_get_workflow
List or fetch workflow details.

```javascript
n8n_list_workflows()
n8n_get_workflow({id: "workflow-id"})
```

---

## Template Tools

### search_templates
Search 2,653+ community templates.

```javascript
search_templates({query: "webhook slack", limit: 20})
```

### get_template
Get template details.

```javascript
get_template({
  templateId: 2947,
  mode: "structure"  // or "full" for complete JSON
})
```

### list_node_templates
Find templates using a specific node.

```javascript
list_node_templates({
  nodeType: "n8n-nodes-base.slack"  // Full prefix!
})
```

---

## Utility Tools

### tools_documentation
Self-documenting tool catalog.

```javascript
tools_documentation()
tools_documentation({topic: "search_nodes", depth: "full"})
```

### n8n_health_check
Verify MCP server connectivity.

```javascript
n8n_health_check()
// Returns: status, features, API availability, version
```

### get_database_statistics
Node and template counts.

```javascript
get_database_statistics()
// Returns: ~537 nodes, ~270 AI tools, ~2653 templates
```

---

## Common Tool Sequences

### Building a new workflow
```
1. search_nodes → find required nodes
2. get_node_essentials → understand configuration
3. n8n_create_workflow → create with initial nodes
4. n8n_validate_workflow → check for issues
5. n8n_update_partial_workflow → add more nodes iteratively
6. validate_workflow → final check
```

### Debugging a broken workflow
```
1. n8n_get_workflow → see current state
2. validate_workflow → find issues
3. get_node_essentials → understand correct config
4. n8n_update_partial_workflow → fix issues
5. cleanStaleConnections → remove broken links
6. n8n_validate_workflow → verify fix
```

### Finding the right node for a task
```
1. search_nodes({query: "email"}) → find candidates
2. get_node_essentials → compare capabilities
3. search_templates({query: "email notification"}) → see real examples
4. get_template → study implementation
```
