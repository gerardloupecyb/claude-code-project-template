---
name: n8n-workflow-architect
description: "Design, build, and optimize n8n automation workflows from scratch or improve existing ones. Use this skill whenever the user mentions n8n, workflow automation, or asks to build any integration -- even if they don't say n8n explicitly but describe webhook processing, scheduled tasks, API orchestration, multi-step automations, or connecting services together. Also trigger when the user asks about n8n MCP tools (search_nodes, get_node_essentials, validate_workflow, n8n_create_workflow, n8n_update_partial_workflow), n8n templates, workflow architecture, or workflow debugging. This is the primary entry point for all n8n workflow design and creation tasks. For node-level configuration and expression syntax, defer to n8n-node-expert. For writing Code node logic, defer to n8n-code-nodes."
---

# n8n Workflow Architect

Design and build production-ready n8n workflows. This skill covers architecture, pattern selection, MCP tool orchestration, and real-world integration patterns.

## When to Use Other Skills

- **Configuring nodes, writing expressions, fixing validation errors** → use `n8n-node-expert`
- **Writing JavaScript or Python inside a Code node** → use `n8n-code-nodes`
- **Everything else about n8n workflows, MCP tools, architecture** → you're in the right place

---

## Workflow Design Process

Every workflow follows this sequence. Don't skip steps — the 30 seconds spent planning saves 30 minutes debugging.

### 1. Clarify Requirements

Before touching n8n, answer these questions:

- **Trigger**: What starts this? (webhook, schedule, manual, email, service event)
- **Data sources**: What systems do you read from?
- **Transformations**: What processing is needed?
- **Actions**: What systems do you write to?
- **Error cases**: What can fail? What's the consequence?
- **Volume**: How many items per execution? How often?

### 2. Select the Right Pattern

Five core patterns cover 90%+ of real-world workflows. Pick the one that matches your trigger and data flow, then consult the detailed reference file.

**Webhook Processing** — Real-time event handling
```
Webhook → Validate → Transform → Act → Respond
```
Use when: Receiving data from external systems (Stripe payments, form submissions, email security alerts, GitHub webhooks, chat commands). Respond quickly (< 5 seconds) and process asynchronously if heavy work is needed.
→ See [references/webhook-patterns.md](references/webhook-patterns.md)

**Scheduled Batch Processing** — Recurring automation
```
Schedule → Fetch → Transform → Batch Process → Deliver → Log
```
Use when: Daily reports, periodic syncs, cleanup tasks, monitoring sweeps. Handle partial failures — process what you can, report what failed.
→ See [references/scheduled-patterns.md](references/scheduled-patterns.md)

**API Integration Pipeline** — Cross-system synchronization
```
Trigger → HTTP Request → Transform → Action → Error Handler
```
Use when: Syncing data between services (CRM ↔ accounting, ticketing ↔ monitoring). Respect rate limits, implement pagination, use upsert logic.
→ See [references/api-patterns.md](references/api-patterns.md)

**AI Agent Workflow** — Intelligent automation with reasoning
```
Trigger → AI Agent (Model + Tools + Memory) → Output
```
Use when: Workflows that need judgment — email triage, content generation, ambiguous-case reasoning, classification with confidence thresholds. This pattern powers agentic security architectures and intelligent routing.
→ See [references/ai-agent-patterns.md](references/ai-agent-patterns.md)

**Sub-Workflow / Modular** — Reusable building blocks
```
Main Workflow → Execute Workflow (sub-1) → Process Result
             → Execute Workflow (sub-2) → Merge Data
```
Use when: Shared logic across workflows, complex multi-step processes. Pass data via parameters, not globals. Document input/output contracts.

### 3. Build Iteratively

n8n workflows are built incrementally, not in one shot. The typical editing rhythm is ~56 seconds between changes.

1. Create trigger node, test it fires
2. Add first integration, verify data retrieval
3. Add one transformation, check output
4. Continue node by node
5. Add error handling after core flow works
6. Validate complete workflow before activation

### 4. Implement Error Handling

Every production workflow needs error handling. Design it from the start.

**Required elements:**
- Error trigger nodes after HTTP requests, database ops, and file operations
- Conditional branching for different error types (4xx client error vs 5xx server error vs timeout)
- Notifications for critical failures (Slack, email, SMS)
- Retry logic with backoff for transient failures
- Idempotency checks (don't duplicate actions on re-execution)

**Error handler pattern:**
```
Main Flow → [Success Path]
         └→ [Error Trigger → Log Error → Classify → Retry or Alert]
```

### 5. Validate and Deploy

- Validate each node: `validate_node_operation` with `profile: "runtime"`
- Validate complete workflow: `validate_workflow`
- Test happy path, edge cases, and error scenarios
- Activate via n8n UI or REST API (`PATCH /rest/workflows/{id}` with `{"active": true}`)
- Monitor first executions

---

## MCP Tool Orchestration

n8n-mcp provides 40+ tools. Here's how to use them effectively.

### Critical: nodeType Format Rules

Two different formats exist — using the wrong one causes "node not found" errors.

**Search/Validate tools** → short prefix:
```
nodes-base.slack
nodes-base.httpRequest
nodes-langchain.agent
```

**Workflow creation tools** → full prefix:
```
n8n-nodes-base.slack
n8n-nodes-base.httpRequest
@n8n/n8n-nodes-langchain.agent
```

The `search_nodes` tool returns both formats:
```json
{
  "nodeType": "nodes-base.slack",              // For search/validate
  "workflowNodeType": "n8n-nodes-base.slack"   // For workflow tools
}
```

### Tool Selection Workflow

**Finding nodes:**
```
search_nodes({query: "keyword"})
  → get_node_essentials({nodeType: "nodes-base.name"})
  → [Optional] get_node_documentation({nodeType: "..."})
```

Always start with `get_node_essentials` (91.7% success, ~5KB, <10ms) over `get_node_info` (80% success, 100KB+, slow). Only escalate to `get_node_info` when essentials isn't sufficient.

**Building workflows:**
```
n8n_create_workflow({name, nodes, connections})
  → n8n_validate_workflow({id})
  → n8n_update_partial_workflow({id, operations: [...]})
  → n8n_validate_workflow({id})
```

Iterate with `n8n_update_partial_workflow` — 99.0% success rate, supports 15 operation types.

**Smart connection parameters** — use semantic names instead of sourceIndex:
```json
{"type": "addConnection", "source": "IF", "target": "Handler", "branch": "true"}
{"type": "addConnection", "source": "Switch", "target": "Case A", "case": 0}
```

### Tool Availability

**Always available** (no n8n API needed): search_nodes, get_node_essentials, validate_node_minimal, validate_node_operation, validate_workflow, search_templates, get_template

**Requires n8n API** (N8N_API_URL + N8N_API_KEY): n8n_create_workflow, n8n_update_partial_workflow, n8n_validate_workflow (by ID), n8n_list_workflows

### Auto-Sanitization

Every workflow save/update triggers auto-sanitization on ALL nodes:
- Binary operators (equals, contains) → removes singleValue
- Unary operators (isEmpty, isNotEmpty) → adds singleValue: true
- IF/Switch nodes → adds missing metadata

Cannot auto-fix: broken connections (use `cleanStaleConnections`), branch count mismatches, corrupt states.

---

## Real-World Architecture Patterns

Patterns drawn from production cybersecurity, GRC, and business automation deployments.

### Agentic Security Pipeline

Architecture for automated email threat response:
```
Email Security Webhook (suspicious email alert)
  → n8n Classify Threat (rules + AI)
  → IF confidence > threshold
    → TRUE: Auto-remediate (RMM quarantine + user notify)
    → FALSE: AI reasoning (ambiguous case analysis)
      → IF malicious: Remediate
      → IF benign: Release + log
      → IF uncertain: Escalate to analyst
  → Log to SIEM / incident tracker
```

Key design decisions:
- Two-tier classification: fast rules first, expensive AI only for ambiguous cases
- Confidence thresholds are configurable per client
- Every decision is logged with reasoning for audit trail
- Sub-workflow for remediation actions (reusable across trigger types)

### Compliance Automation (DSAR / Loi 25)

Data Subject Access Request processing:
```
Microsoft Forms Trigger (DSAR submission)
  → Validate request (identity verification)
  → Create SharePoint tracking record
  → Fan-out: Search data across systems
    → Branch 1: Query CRM
    → Branch 2: Query email archives
    → Branch 3: Query file storage
  → Merge results
  → Claude: Classify and redact sensitive data
  → Generate response package
  → Notify requester + log compliance
  → Schedule: 25-day deadline reminder
```

### Automated Reporting Pipeline

Monthly security report generation:
```
Schedule (1st of month)
  → Fetch security platform stats (HTTP Request)
  → Fetch awareness training results (HTTP Request)
  → Code Node: Parse PDFs, aggregate metrics
  → Claude: Generate executive summary
  → Code Node: Build HTML report template
  → Convert to PDF
  → Email to client
  → Log delivery
```

### QuickBooks Accounting Automation

Expense processing with Quebec tax handling:
```
Webhook (receipt uploaded)
  → AI Classification: Vendor type, expense category
  → IF Quebec restaurant receipt
    → TRUE: Split TPS (5%) + TVQ (9.975%) separately
    → FALSE: Standard GST/HST handling
  → IF Foreign SaaS vendor
    → TRUE: Record as foreign purchase, no input tax credit
    → FALSE: Standard Canadian vendor treatment
  → Create QuickBooks entry
  → Attach receipt image
  → IF shareholder expense → Tag for shareholder loan account
```

### Lead Intelligence Pipeline

Real estate or business intelligence:
```
Schedule (daily)
  → Fetch market data (HTTP Request to multiple sources)
  → Code Node: Normalize and score opportunities
  → AI Agent: Analyze against investment criteria
  → IF score > threshold
    → TRUE: Create GoHighLevel contact + trigger nurture sequence
    → FALSE: Archive in Supabase for trend analysis
  → Weekly: Generate market intelligence report
```

---

## Data Flow Patterns

### Linear Flow
```
Trigger → Transform → Action → End
```
Simple, single-path workflows. Use for straightforward integrations.

### Branching Flow
```
Trigger → IF → [True Path]
             └→ [False Path]
```
Different actions based on conditions. Keep branches balanced in complexity.

### Parallel Processing
```
Trigger → [Branch 1] → Merge
       └→ [Branch 2] ↗
```
Independent operations that run simultaneously. Use for multi-source data fetching.

### Loop Pattern
```
Trigger → Split in Batches → Process → Loop (until done)
```
Large dataset processing. Set appropriate batch sizes to respect rate limits.

### Error Handler Pattern
```
Main Flow → [Success Path]
         └→ [Error Trigger → Error Handler]
```
Separate error handling workflow. Essential for production.

---

## Templates

Use templates as starting points, not final solutions.

```javascript
// Search templates by keyword
search_templates({query: "webhook slack", limit: 20})

// Get template details
get_template({templateId: 2947, mode: "structure"})
```

Templates include complexity rating, setup time estimate, and required services.

---

## Production Checklist

### Before Activation

- [ ] Every external call has error handling
- [ ] Credentials in n8n credential manager (never hardcoded)
- [ ] Webhook endpoints require authentication
- [ ] Input validation on all external data
- [ ] Descriptive node names (not "HTTP Request 1")
- [ ] Sticky notes on complex logic
- [ ] Idempotency checks for webhooks and scheduled tasks
- [ ] Rate limiting respected for external APIs
- [ ] Tested: happy path, edge cases, error scenarios
- [ ] Workflow validated with `validate_workflow`

### Naming Conventions
- Workflows: `[Client] - [Purpose] - [Trigger Type]`
- Nodes: Verb + noun format (`Fetch Customer Data`, `Send Alert Email`)
- Sub-workflows: `[Shared] - [Function Name]`

### Performance
- Batch operations when APIs support it
- Pagination for large datasets (cursor-based preferred)
- Split In Batches for heavy processing
- Appropriate timeouts (default 5 min may be too long or short)
- Connection reuse for databases

---

## Troubleshooting Quick Reference

**Workflow not triggering:** Check trigger config, verify workflow is active (toggle switch), check execution history, test manually

**Data not passing between nodes:** Check node output in execution view, verify expression syntax (`{{$json.field}}` not `{$json.field}`), ensure previous node has output

**API errors (4xx/5xx):** Check credentials, verify endpoint URL, review request format, check rate limits, test outside n8n

**Performance issues:** Identify slow nodes in execution history, reduce data volume (pagination/batching), split into sub-workflows, add delays for rate limiting

For deeper debugging, see [references/debugging.md](references/debugging.md)

---

## Reference Files

Detailed guides loaded as needed:

- **[references/webhook-patterns.md](references/webhook-patterns.md)** — Webhook data structure, signature validation, async processing
- **[references/scheduled-patterns.md](references/scheduled-patterns.md)** — Cron expressions, batch processing, partial failure handling
- **[references/api-patterns.md](references/api-patterns.md)** — REST integration, pagination, rate limiting, authentication
- **[references/ai-agent-patterns.md](references/ai-agent-patterns.md)** — AI agents, tools, memory, langchain nodes, Claude integration
- **[references/mcp-tools-reference.md](references/mcp-tools-reference.md)** — Complete MCP tool catalog, parameters, patterns
- **[references/mcp-search-guide.md](references/mcp-search-guide.md)** — Node discovery and search strategies
- **[references/mcp-validation-guide.md](references/mcp-validation-guide.md)** — Validation tools and profiles via MCP
- **[references/mcp-workflow-guide.md](references/mcp-workflow-guide.md)** — Workflow creation, editing, management via MCP
- **[references/security.md](references/security.md)** — Credential management, input validation, encryption
- **[references/debugging.md](references/debugging.md)** — Troubleshooting, logging strategies, testing
