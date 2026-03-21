# n8n ↔ GHL Integration Patterns

Production-ready patterns for connecting n8n workflows with GoHighLevel.

## Table of Contents
1. [Credential Setup](#credential-setup)
2. [GHL → n8n Patterns (Webhook Outbound)](#ghl--n8n-patterns)
3. [n8n → GHL Patterns (API Calls)](#n8n--ghl-patterns)
4. [Bi-Directional Sync](#bi-directional-sync)
5. [Error Handling in Integration Flows](#error-handling)
6. [Real-World Pipeline Examples](#real-world-pipeline-examples)
7. [Rate Limit Management](#rate-limit-management)

---

## Credential Setup

### Option A: OAuth2 Credential (Recommended for marketplace apps)
In n8n, create a credential of type "OAuth2 API":
```
Client ID: [from GHL Marketplace app]
Client Secret: [from GHL Marketplace app]
Authorization URL: https://marketplace.gohighlevel.com/oauth/chooselocation
Token URL: https://services.leadconnectorhq.com/oauth/token
Scope: contacts.readonly contacts.write opportunities.write [etc.]
Auth URI Query Parameters: response_type=code
```
n8n handles token refresh automatically with this setup. Best for: marketplace apps, multi-location deployments.

### Option B: Private Integration Token (Recommended for internal/server-to-server)
PITs are static OAuth2 tokens with scope restrictions — simpler than full OAuth2, more secure than legacy keys.

1. Go to the client's sub-account → Settings → Private Integrations
2. Create a new integration (name: "n8n - [Purpose]")
3. Select only the scopes your integration needs
4. Save and copy the token (shown only once)

In n8n, create a credential of type "Header Auth":
```
Name: Authorization
Value: Bearer {your-PIT-token}
```
Add `Version: 2021-07-28` as a header in every HTTP Request node.

Best for: internal tools, single-location integrations, n8n workflows that don't need marketplace distribution. PITs don't expire, so no token refresh logic needed — but protect them carefully since they're long-lived credentials.

### Option C: Legacy API Key (Deprecated — migrate away)
In n8n, create a credential of type "Header Auth":
```
Name: Authorization
Value: Bearer {your-api-key}
```
Add a second header in the HTTP Request node:
```
Version: 2021-07-28
```

**Deprecation warning**: GHL is removing the ability to generate new API keys. Existing keys may continue to work but receive no support. Migrate to Option A (OAuth2) or Option B (PIT) for all new and existing integrations.

### Option D: Custom Auth (for n8n Code nodes)
When using n8n Code nodes to call GHL API:
```javascript
// Access credentials from n8n's credential store
const credentials = await this.getCredentials('httpHeaderAuth');
const token = credentials.value; // The Bearer token (OAuth2 or PIT)

// Or use environment variables (set in n8n config)
const token = $env.GHL_API_TOKEN;
```

**Never hardcode tokens in Code node JavaScript.** Use n8n's credential system or environment variables.

---

## GHL → n8n Patterns

### Pattern 1: Simple Webhook Relay
GHL workflow fires a Custom Webhook action that n8n receives.

**GHL Workflow:**
```
Trigger: [Any GHL event]
  ↓
Action: Custom Webhook
  URL: https://n8n.yourdomain.com/webhook/{random-path-id}
  Method: POST
  Headers:
    Content-Type: application/json
    X-Webhook-Secret: {shared-secret}
  Body:
    {
      "event": "contact_qualified",
      "contact_id": "{{contact.id}}",
      "contact_email": "{{contact.email}}",
      "contact_name": "{{contact.full_name}}",
      "pipeline_stage": "{{opportunity.pipeline_stage_id}}",
      "location_id": "{{locationId}}",
      "timestamp": "{{date.now}}"
    }
```

**n8n Workflow:**
```
Webhook Node (POST, path: /{random-path-id})
  ↓
Code Node: Validate webhook
  // Verify the shared secret
  const secret = $input.first().headers['x-webhook-secret'];
  if (secret !== $env.GHL_WEBHOOK_SECRET) {
    throw new Error('Invalid webhook secret');
  }
  return $input.all();
  ↓
[Processing nodes]
```

### Pattern 2: Event-Driven Pipeline Processing
Multiple GHL events feed into a single n8n webhook with routing.

**GHL Side** (multiple workflows, same webhook URL):
- Workflow A: Contact Created → webhook with `"event": "contact_created"`
- Workflow B: Stage Changed → webhook with `"event": "stage_changed"`
- Workflow C: Appointment Booked → webhook with `"event": "appointment_booked"`

**n8n Side:**
```
Webhook Node (receives all events)
  ↓
Switch Node: Route by $.body.event
  ├─ "contact_created" → Contact processing branch
  ├─ "stage_changed" → Pipeline sync branch
  ├─ "appointment_booked" → Calendar sync branch
  └─ Default → Log unknown event + alert
```

### Pattern 3: Enrichment Loop (GHL → n8n → GHL)
GHL triggers n8n, which enriches data and writes back to GHL.

```
GHL: Contact Created
  ↓
Custom Webhook → n8n
  Body: { contact_id, email, company_name }
  ↓
n8n: Clearbit/Apollo/LinkedIn enrichment
  ↓
n8n: HTTP Request → GHL API
  PUT /contacts/{contact_id}
  Body: {
    "customFields": {
      "enrichment_company_size": "50-200",
      "enrichment_industry": "SaaS",
      "enrichment_linkedin_url": "https://...",
      "scoring_lead_score": 35
    },
    "tags": ["enriched", "source:enrichment-auto"]
  }
```

---

## n8n → GHL Patterns

### Pattern 4: Scheduled Contact Sync
Pull data from external source and create/update contacts in GHL.

```
n8n Schedule Trigger (e.g., every 6 hours)
  ↓
HTTP Request: Fetch data from external CRM/source
  ↓
Code Node: Transform to GHL format
  const items = $input.all().map(item => ({
    json: {
      email: item.json.email,
      firstName: item.json.first_name,
      lastName: item.json.last_name,
      phone: item.json.phone,
      tags: ['source:external-crm', 'sync:auto'],
      customFields: {
        integration_n8n_sync_id: `ext_${item.json.external_id}`,
        integration_last_sync_date: new Date().toISOString()
      }
    }
  }));
  return items;
  ↓
Split In Batches: Process 10 at a time (respect rate limits)
  ↓
HTTP Request: Upsert to GHL
  For each contact:
    1. GET /contacts/?query={email} → check if exists
    2. If exists: PUT /contacts/{id} with updated data
    3. If not: POST /contacts/ with full data
  ↓
Wait: 500ms between batches (rate limit courtesy)
```

### Pattern 5: Bulk Tag Operations
Apply or remove tags in bulk based on external criteria.

```
n8n Schedule Trigger
  ↓
HTTP Request: GET /contacts/?limit=100 (with pagination loop)
  ↓
Code Node: Filter contacts matching criteria
  // Example: tag stale leads (no engagement in 90 days)
  const staleContacts = items.filter(item => {
    const lastEngagement = new Date(item.json.customFields?.scoring_last_engagement_date);
    const daysSince = (Date.now() - lastEngagement) / (1000 * 60 * 60 * 24);
    return daysSince > 90 && !item.json.tags.includes('status:customer');
  });
  return staleContacts;
  ↓
Split In Batches: 10 at a time
  ↓
HTTP Request: POST /contacts/{id}/tags
  Body: { "tags": ["status:lead:stale"] }
```

### Pattern 6: Pipeline Reporting Export
Export pipeline data from GHL to external analytics.

```
n8n Schedule Trigger (weekly)
  ↓
HTTP Request: GET /opportunities/?pipelineId={id}&limit=100
  (loop with pagination until all fetched)
  ↓
Code Node: Transform for analytics
  // Calculate pipeline velocity, conversion rates, etc.
  ↓
Google Sheets Node: Write to reporting spreadsheet
  OR
PostgreSQL Node: Insert into data warehouse
  ↓
HTTP Request: GHL API → update custom field on location
  "last_report_generated": new Date().toISOString()
```

---

## Bi-Directional Sync

### Pattern 7: Two-Way Contact Sync
Keep GHL and an external system in sync without infinite loops.

```
KEY PRINCIPLE: Use a sync_id and last_modified timestamp to prevent loops.

Direction 1: GHL → External
  GHL Webhook: ContactUpdate
    ↓
  n8n: Check custom field "integration_last_sync_source"
    ├─ If "external" → SKIP (this update came FROM external, don't echo back)
    └─ If "ghl" or empty → Process
         1. Map GHL fields → external format
         2. Upsert in external system
         3. Update GHL: integration_last_sync_date, integration_last_sync_source = "ghl"

Direction 2: External → GHL
  n8n: Webhook from external system
    ↓
  n8n: Find GHL contact by integration_n8n_sync_id
    ↓
  n8n: Update GHL contact
    Include: integration_last_sync_source = "external"
```

**Loop prevention relies on the `integration_last_sync_source` field.** Without it, an update from System A triggers a webhook to System B, which updates and triggers a webhook back to System A, infinitely.

---

## Error Handling

### n8n Error Workflow Pattern
Every n8n workflow that calls GHL API should have an error workflow:

```
Main Workflow:
  [Normal nodes]
  ↓
  On error → trigger Error Workflow

Error Workflow:
  Error Trigger Node
    ↓
  Code Node: Extract error details
    const error = $input.first().json;
    return [{
      json: {
        workflow: error.workflow?.name,
        node: error.execution?.lastNodeExecuted,
        message: error.execution?.error?.message,
        timestamp: new Date().toISOString(),
        contact_id: error.execution?.data?.resultData?.runData?.Webhook?.[0]?.data?.main?.[0]?.[0]?.json?.contact_id
      }
    }];
    ↓
  Slack/Email Node: Alert ops team
    ↓
  (Optional) HTTP Request: Tag contact in GHL
    POST /contacts/{contact_id}/tags
    Body: { "tags": ["error:n8n:{workflow_name}"] }
```

### Retry Logic for GHL API Calls
```javascript
// n8n Code Node: GHL API call with retry
const MAX_RETRIES = 3;
const BASE_DELAY = 1000;

async function callGHLWithRetry(endpoint, method, body) {
  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    const response = await $helpers.httpRequest({
      method: method,
      url: `https://services.leadconnectorhq.com${endpoint}`,
      headers: {
        'Authorization': `Bearer ${$env.GHL_ACCESS_TOKEN}`,
        'Content-Type': 'application/json',
        'Version': '2021-07-28'
      },
      body: body ? JSON.stringify(body) : undefined,
      returnFullResponse: true
    });

    if (response.statusCode === 200 || response.statusCode === 201) {
      return JSON.parse(response.body);
    }

    if (response.statusCode === 429) {
      // Rate limited — exponential backoff with jitter
      const delay = BASE_DELAY * Math.pow(2, attempt) + Math.random() * 500;
      await new Promise(resolve => setTimeout(resolve, delay));
      continue;
    }

    if (response.statusCode === 401) {
      throw new Error('GHL auth failed — token may be expired. Check OAuth2 credential.');
    }

    if (response.statusCode >= 500) {
      // GHL server error — retry
      const delay = BASE_DELAY * Math.pow(2, attempt);
      await new Promise(resolve => setTimeout(resolve, delay));
      continue;
    }

    // 400-level errors (not 401/429) — don't retry, it's a bad request
    throw new Error(`GHL API ${response.statusCode}: ${response.body}`);
  }

  throw new Error(`GHL API failed after ${MAX_RETRIES} retries`);
}
```

---

## Real-World Pipeline Examples

### Email Security Alert → GHL Contact Tagging
```
n8n: Email security webhook (phishing detected)
  ↓
Code Node: Extract target email from alert
  ↓
HTTP Request: GHL API → search contact by email
  GET /contacts/?query={email}
  ↓
Conditional: Contact found?
  ├─ YES → Tag contact: "security:phishing-target:{date}"
  │         Add note: "Phishing email detected on {date}. Subject: {subject}"
  │         (Optional) Trigger GHL workflow to notify account manager
  └─ NO → Log: "Phishing target not in GHL: {email}"
```

### RMM Ticket → GHL Opportunity Update
```
n8n: RMM webhook (ticket resolved)
  ↓
Code Node: Extract client identifier + resolution
  ↓
HTTP Request: GHL API → find opportunity by custom field
  ↓
HTTP Request: GHL API → update opportunity
  PUT /opportunities/{id}
  Body: {
    "customFields": {
      "support_last_ticket_resolved": "{date}",
      "support_ticket_count": {incremented}
    }
  }
  ↓
HTTP Request: GHL API → add tag
  POST /contacts/{contact_id}/tags
  Body: { "tags": ["support:ticket-resolved"] }
```

### QuickBooks Invoice → GHL Pipeline Stage
```
n8n: QuickBooks webhook (invoice paid)
  ↓
Code Node: Extract customer email + amount
  ↓
HTTP Request: GHL API → search contact by email
  ↓
HTTP Request: GHL API → update opportunity stage
  PUT /opportunities/{id}/status
  Body: { "pipelineStageId": "stage_payment_received" }
  ↓
HTTP Request: GHL API → update monetary value
  PUT /opportunities/{id}
  Body: { "monetaryValue": {invoice_amount} }
  ↓
Tag: "billing:paid:{invoice_id}"
```

---

## Rate Limit Management

### Understanding GHL Limits
- **Daily limit**: 200,000 requests/day per marketplace app per location
- **Burst limit**: 100 requests per 10 seconds per marketplace app per location
- Headers: `X-RateLimit-Remaining`, `X-RateLimit-Reset`
- 429 response when either limit is hit

**The burst limit is the one that catches people off guard.** A tight loop of API calls in n8n (e.g., updating 50 contacts without waits) will hit 100/10s long before touching the daily limit. Always add delays between batched calls.

### n8n Rate Limit Strategies

**Strategy 1: Split In Batches + Wait**
```
Split In Batches: 10 items per batch
  ↓
[API call node]
  ↓
Wait: 500ms
  ↓
[Loop back to Split In Batches]
```

**Strategy 2: Monitor remaining quota**
```javascript
// In Code Node after API call
const remaining = $input.first().headers?.['x-ratelimit-remaining'];
if (remaining && parseInt(remaining) < 1000) {
  // Getting close to limit — slow down
  await new Promise(resolve => setTimeout(resolve, 5000));
}
```

**Strategy 3: Time-window spreading**
For large batch operations, schedule across the day:
```
Batch 1: Run at 2 AM (overnight processing)
Batch 2: Run at 6 AM
Batch 3: Run at 10 AM
```
This distributes load and leaves quota for real-time operations during business hours.

### Calculating Quota Needs
Before deploying a new integration, estimate daily API calls:

```
Example calculation:
  Real-time webhooks: ~50 contacts/day × 2 API calls each = 100
  Scheduled sync: 500 contacts × 3 calls each (search + upsert + tag) = 1,500
  Pipeline reporting: 200 opportunities × 1 call = 200
  Maintenance workflows: ~50 calls/day

  Total: ~1,850 calls/day (well within 200k limit)
```

If your estimate exceeds 150k/day, consider:
- Caching contact lookups (reduce redundant searches)
- Batching tag operations (fewer calls)
- Using webhooks instead of polling (eliminates scheduled search calls)
