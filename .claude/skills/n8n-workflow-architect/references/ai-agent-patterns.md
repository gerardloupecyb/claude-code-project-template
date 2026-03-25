# AI Agent Workflow Patterns

## Core AI Connection Types

n8n supports 8 AI connection types for agent workflows:

1. **ai_languageModel** — The LLM (OpenAI, Anthropic Claude, Google Gemini, Ollama)
2. **ai_tool** — Functions the agent can call (ANY n8n node can be a tool)
3. **ai_memory** — Conversation context (Buffer, Window Buffer, Summary)
4. **ai_outputParser** — Parse structured outputs (JSON, lists)
5. **ai_embedding** — Vector embeddings for semantic search
6. **ai_vectorStore** — Vector database (Qdrant, Pinecone, Supabase pgvector)
7. **ai_document** — Document loaders (files, web pages, PDFs)
8. **ai_textSplitter** — Text chunking for embedding pipelines

**Critical**: Connect tools via `ai_tool` port, NOT the main port. This is the most common mistake with agent workflows.

---

## Agent Types

### Conversational Agent
Best for: chat interfaces, interactive tools, customer support
```javascript
{
  agent: "conversationalAgent",
  promptType: "define",
  text: "System prompt defining agent role and capabilities"
}
```

### OpenAI Functions Agent
Best for: structured tool calling, deterministic workflows
```javascript
{
  agent: "openAIFunctionsAgent",
  // Works with OpenAI function calling API
  // More precise tool invocation
}
```

---

## Making ANY Node an AI Tool

Any n8n node becomes an AI tool when connected via `ai_tool` port.

**Requirements:**
1. Connect to AI Agent's `ai_tool` input (not main input)
2. Provide clear tool name and description
3. The AI uses the description to decide when to invoke the tool

**HTTP Request as tool:**
```javascript
{
  name: "search_knowledge_base",
  description: "Search the company knowledge base by keyword. Returns relevant articles with titles and summaries. Use when the user asks about company policies, procedures, or product information.",
  method: "GET",
  url: "https://api.example.com/search",
  sendQuery: true,
  queryParameters: {"q": "={{$json.query}}", "limit": "5"}
}
```

**Database as tool:**
```javascript
{
  name: "query_client_data",
  description: "Query client database by email, name, or client ID. Returns client profile, subscription status, and recent activity. IMPORTANT: Use SELECT queries only.",
  operation: "executeQuery",
  query: "={{$json.sql}}"
}
```

**Security**: Always use read-only database credentials for AI tools.

---

## Memory Configuration

### Window Buffer Memory (Recommended)
```javascript
{
  memoryType: "windowBufferMemory",
  contextWindowLength: 10,  // Last 10 messages
  sessionKey: "={{$json.body.session_id}}"  // Per-session memory
}
```

### When to Use Each Type

- **Buffer Memory** — Short conversations, testing (stores everything, grows unbounded)
- **Window Buffer Memory** — Production chat (stores last N messages, predictable cost)
- **Summary Memory** — Long conversations (summarizes older messages, saves tokens)

---

## Two-Tier Classification Pattern

For high-volume processing where AI reasoning is expensive, use fast rules first and AI only for ambiguous cases.

### Architecture
```
Event Trigger
  → Code Node: Apply rules-based classification
  → IF confidence >= threshold
    → TRUE (high confidence): Execute action directly
    → FALSE (ambiguous): Send to AI Agent for reasoning
      → AI Agent (Claude Opus / GPT-4)
        ├─ Context retrieval tool
        ├─ Action execution tool
        └─ Escalation tool (for uncertain cases)
  → Log decision + reasoning for audit
```

### Implementation — Email Threat Triage
```
Email Security Webhook (suspicious email alert)
  → Code Node: Score threat indicators
    - Known malicious domains → score: 0.95
    - Suspicious attachments → score: 0.8
    - URL reputation check → score: variable
    - SPF/DKIM failures → score: 0.7
  → Switch (by confidence band)
    → Case "high" (score > 0.9): Auto-quarantine via RMM
    → Case "medium" (0.5-0.9): AI Agent analysis
      ├─ Claude (Opus-class): Analyze email context + intent
      ├─ HTTP Tool: Check URL/domain reputation APIs
      ├─ HTTP Tool: Query past incidents for this sender
      └─ Decision: quarantine / release / escalate
    → Case "low" (< 0.5): Release with monitoring tag
  → Log to incident tracker (every decision)
```

### Implementation — Data Classification (LAI)
```
Schedule Trigger (batch processing)
  → Fetch unclassified records
  → Split In Batches (100 records per batch)
  → Pass 1: Claude Sonnet — bulk classification
    - Classify sensitivity level
    - Tag with category codes
    - Flag uncertain items (confidence < 0.85)
  → IF flagged as uncertain
    → TRUE: Pass 2: Claude Opus — deep validation
      - Analyze context
      - Apply sensitivity rules
      - Generate classification justification
    → FALSE: Accept Sonnet classification
  → Write results to database
  → Generate classification report
```

---

## Prompt Engineering for Agent Workflows

### System Prompt Template
```
You are [ROLE] for [ORGANIZATION/CONTEXT].

You have access to these tools:
- [tool_name]: [when and how to use it]
- [tool_name]: [when and how to use it]

Guidelines:
- [Key behavioral rules]
- [Safety constraints]
- [Output format preferences]

When uncertain, [escalation behavior].
```

### Tool Description Best Practices

**Vague (AI won't know when to use):**
```
description: "Get data"
```

**Clear (AI makes good decisions):**
```
description: "Query the customer database by email address or customer ID. Returns customer name, subscription tier, last login date, and open support tickets. Use when the user asks about a specific customer's account status or history."
```

---

## Error Handling

### Tool Execution Errors
```
AI Agent (set continueOnFail on tool nodes)
  → IF (check for tool error)
    → TRUE: Return graceful error message to user
    → FALSE: Process normal response
```

### LLM API Errors
```
Error Trigger
  → IF (rate limit / 429 error)
    → TRUE: Wait 30s → Retry
    → FALSE: Log error → Notify admin → Return fallback response
```

### Cost Control
- Set `maxTokens` on LLM nodes
- Use Window Buffer Memory (bounded context)
- Choose model tier appropriate to task (Haiku for simple, Opus for complex)
- Monitor token usage and set budget alerts

---

## Security Checklist

- [ ] Read-only database credentials for all AI tool connections
- [ ] Input sanitization (trim, length limit, strip injection attempts)
- [ ] Rate limiting per user/session
- [ ] SQL validation (reject DROP, DELETE, UPDATE in query tools)
- [ ] Tool output size limits (prevent token overflow)
- [ ] Audit logging for all AI decisions
- [ ] Model output filtering (prevent sensitive data leakage)
- [ ] Session isolation (memory scoped to user/session)
