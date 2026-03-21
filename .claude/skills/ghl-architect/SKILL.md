---
name: ghl-architect
description: "Expert architect for GoHighLevel CRM with security-by-design, workflow architecture, and integration engineering. Use for: (1) API integration (OAuth2, scoping, key rotation, webhook verification), (2) Workflow architecture (error handling, idempotency, rollback, naming), (3) n8n ↔ GHL integration (webhooks, HTTP nodes, credentials), (4) Custom field/pipeline design, (5) Agency white-label (snapshots, sub-account isolation), (6) Security hardening (RBAC, least-privilege, Loi 25/PIPEDA), (7) GHL API v2 usage. Trigger on 'GoHighLevel', 'GHL', 'LeadConnector', 'HighLevel API', 'GHL workflow', 'GHL webhook', 'GHL n8n', 'GHL security', 'GHL custom fields', 'GHL snapshot', 'GHL OAuth', or any GHL architecture/integration/security task."
---

# GHL Architect

Expert system for designing secure, production-grade GoHighLevel implementations with emphasis on architecture patterns, security-by-design, and integration engineering.


## When to Use a Different Skill Instead

| If the question is about… | Use this skill instead |
|---------------------------|----------------------|
| n8n workflow design, architecture, MCP tools | **n8n-workflow-architect** |
| n8n node config, expressions, validation | **n8n-node-expert** |
| n8n Code node processing of GHL payloads (JS/Python) | **n8n-code-nodes** |

## When to Read Reference Files

This skill uses a progressive-disclosure approach. The SKILL.md covers decision-making, architecture principles, and quick-reference patterns. For deep implementation details, read the appropriate reference file:

| Topic | Reference File | Read When |
|-------|---------------|-----------|
| OAuth2, API keys, RBAC, webhook verification, data protection | `references/security_patterns.md` | Any security, auth, or compliance question |
| Workflow error handling, idempotency, rollback, naming | `references/workflow_architecture.md` | Building or debugging GHL workflows |
| n8n ↔ GHL webhook pipelines, HTTP nodes, credentials | `references/n8n_integration.md` | Any n8n + GHL integration work |
| API v2 endpoints, payloads, rate limits, pagination | `references/api_reference.md` | API calls, endpoint specifics, error codes |
| Snapshot governance, sub-account isolation, agency ops | `references/agency_governance.md` | White-label, multi-tenant, agency architecture |

## Documentation Lookup Strategy

1. **Built-in references first** — check this skill's reference files
2. **Context7 for unknowns** — if the topic isn't covered or may be outdated, use Context7:
   ```
   Context7:resolve-library-id → libraryName: "GoHighLevel"
   Context7:query-docs → query: "<specific question>"
   ```
3. **web_search fallback** — if Context7 is unavailable, search `marketplace.gohighlevel.com/docs/` and `help.gohighlevel.com`
4. **Inform the user** — flag when info came from web search vs. built-in reference


## Architecture Decision Framework

When a user asks to build something in GHL, follow this decision sequence:

### 1. Threat Model First
Before designing any workflow, API integration, or customization:
- What data flows through this system? (PII, financial, health — triggers compliance requirements)
- Who has access? (Map roles → minimum required permissions)
- What happens if this breaks? (Identify blast radius, design rollback)
- What external systems touch this? (Each integration = attack surface)

### 2. Choose the Right Integration Pattern

| Need | Pattern | Security Implication |
|------|---------|---------------------|
| Real-time event processing | GHL Webhook → n8n | Verify signatures, validate payloads |
| Scheduled data sync | n8n Cron → GHL API | Use OAuth2 with auto-refresh or PIT, not legacy keys |
| User-triggered action | GHL Workflow → Custom Webhook → n8n | Authenticate the webhook endpoint |
| Bi-directional sync | GHL Webhook + n8n HTTP Request | Idempotency keys on both sides |
| Bulk data operations | n8n scheduled batch → GHL API | Burst rate limit awareness (100/10s), pagination |

### 3. Security-by-Design Checklist

Every GHL implementation should satisfy these before going live:

**Authentication & Authorization**
- [ ] OAuth2 tokens or Private Integration Tokens (PITs) used — NOT legacy API keys
- [ ] If OAuth2: token refresh flow automated (tokens expire ~24hrs — handle gracefully)
- [ ] If PIT: token stored securely and rotation scheduled (PITs don't expire but are long-lived credentials)
- [ ] Minimum required scopes selected (least privilege)
- [ ] Webhook signatures verified on every inbound webhook
- [ ] API credentials stored in environment variables or vault (never in workflow JSON)
- [ ] Sub-account access scoped to location (no agency-wide tokens for location-specific work)

**Data Protection**
- [ ] PII fields identified and tagged in custom field taxonomy
- [ ] Data retention policy configured (especially for Loi 25 / PIPEDA compliance)
- [ ] Contact deletion workflow supports DSAR (Data Subject Access Request) automation
- [ ] Webhook payloads don't leak sensitive data to unnecessary endpoints
- [ ] Conversation/call recordings have documented retention and access controls

**Workflow Security**
- [ ] No hardcoded credentials in workflow actions or custom webhook bodies
- [ ] Error branches exist on every workflow (failures don't silently drop contacts)
- [ ] Workflow-per-stage architecture prevents contacts from being in multiple active sequences
- [ ] Rate limits respected (200k/day/location) with backoff logic in external integrations
- [ ] Test contacts use a dedicated tag — never production data in test workflows

**Audit & Monitoring**
- [ ] Webhook delivery failures monitored (GHL retries 3x then drops)
- [ ] API error rates tracked (429s, 401s, 500s)
- [ ] Workflow execution logs reviewed on a schedule
- [ ] Contact tag changes logged for compliance audit trail

## Core Platform Concepts

### API Architecture (v2)
- **Base URL**: `https://services.leadconnectorhq.com`
- **Auth**: OAuth2 Bearer token or Private Integration Token (PIT), with `Version: 2021-07-28` header
- **Rate Limits**: 200,000 requests/day/location AND 100 requests/10 seconds (burst). Both limits apply — the burst limit often bites first in batched operations.
- **Pagination**: Cursor-based (`startAfter` parameter), max 100 per page
- **Scopes**: Granular per resource (contacts, opportunities, calendars, conversations, etc.)
- **V1 Deprecation**: V1 APIs are end-of-support. All new integrations must use V2 with OAuth2 or PITs.

### Workflow Engine
GHL's visual workflow builder supports triggers (form submit, tag added, pipeline stage change, appointment events, custom webhook inbound) and actions (send SMS/email, add tag, create opportunity, HTTP webhook out, conditional branch, wait, math operations on custom fields).

**Key constraint**: Workflows are per-location (sub-account). Agency-level automation requires cross-location patterns — see `references/agency_governance.md`.

### Custom Fields & Values
Custom fields are the backbone of any serious GHL implementation. They store lead scores, lifecycle stages, compliance flags, and integration sync IDs.

**Field types**: text, number, date, dropdown, checkbox, textarea, phone, monetary, file upload.

**Naming convention** (enforced in this skill):
```
{domain}_{entity}_{attribute}
```
Examples:
- `security_consent_date` — when the contact gave marketing consent
- `integration_n8n_sync_id` — unique ID for n8n dedup
- `scoring_lead_score` — behavioral lead score
- `compliance_dsar_requested` — DSAR flag for Loi 25

### Webhook Architecture
GHL supports both inbound (external → GHL via Custom Webhook trigger) and outbound (GHL → external via Custom Webhook action) webhooks.

**Outbound webhook payloads** include contact data plus trigger-specific data (appointment, opportunity, etc.). The payload structure uses `{{contact.field}}` template variables — see `references/api_reference.md` for full payload schemas.

**Inbound webhooks** require the workflow to have a Custom Webhook trigger, which generates a unique URL. External systems (n8n, Zapier) POST JSON to this URL to trigger the workflow.

## Quick-Reference Patterns

### Pattern: Secure Webhook Pipeline (GHL → n8n)
```
GHL Workflow Trigger (e.g., Opportunity Stage Change)
  ↓
Custom Webhook Action → POST to n8n webhook URL
  Headers: X-GHL-Signature (Ed25519 — see security_patterns.md)
  Body: { contact, opportunity, location, timestamp }
  ↓
n8n Webhook Node receives POST (native webhook auth or header validation)
  ↓
n8n Code Node: Process payload (no crypto in v2.0 sandbox — signature verified at webhook level)
  ↓
n8n processes data (enrich, route, sync to external system)
  ↓
(Optional) n8n HTTP Request → GHL API to update contact/tag
```

### Pattern: Idempotent Contact Sync (n8n → GHL)
```
n8n receives data from external source
  ↓
Generate deterministic sync_id (hash of source + external_id)
  ↓
GHL API: Search contact by custom field "integration_n8n_sync_id"
  ↓
If exists → PUT /contacts/{id} (update)
If not → POST /contacts/ (create with sync_id in custom fields)
  ↓
Log operation for audit trail
```

### Pattern: DSAR Automation (Loi 25 / PIPEDA)
```
GHL Form: "Data Access Request" submitted
  ↓
Workflow: Tag contact "compliance_dsar_pending"
  ↓
Custom Webhook → n8n
  ↓
n8n: Query GHL API for all contact data
n8n: Query external systems (email platform, analytics)
n8n: Compile data package
  ↓
n8n: POST to GHL API → create note on contact with summary
n8n: Send email to contact with data export
  ↓
n8n: Update GHL custom field "compliance_dsar_completed_date"
n8n: Remove tag "compliance_dsar_pending", add "compliance_dsar_fulfilled"
```

### Pattern: Error-Resilient Workflow
```
Trigger: Any
  ↓
Action: Primary operation
  ↓
Conditional: Did action succeed? (check via If/Else or webhook response)
├─ YES → Continue normal flow
│         Tag: "workflow_{name}_completed"
└─ NO → Error branch
          Tag: "workflow_{name}_error"
          Internal notification (Slack/email to ops team)
          Log error context to custom field or note
          DO NOT silently continue — failed contacts need attention
```

## Custom Field Taxonomy Template

When setting up a new GHL location, establish these field groups:

**Identity & Contact** (built-in — extend with):
- `identity_preferred_language` (dropdown: fr, en) — critical for Quebec bilingual compliance

**Scoring & Lifecycle**:
- `scoring_lead_score` (number)
- `scoring_last_engagement_date` (date)
- `lifecycle_stage` (dropdown: Subscriber → Lead → MQL → SQL → Customer → Churned)

**Integration Sync**:
- `integration_n8n_sync_id` (text) — dedup key for external sync
- `integration_external_crm_id` (text) — if syncing to another CRM
- `integration_last_sync_date` (date)

**Compliance & Consent**:
- `compliance_marketing_consent` (checkbox)
- `compliance_consent_date` (date)
- `compliance_consent_source` (text — e.g., "web-form-2025-01")
- `compliance_dsar_requested` (checkbox)
- `compliance_data_retention_expiry` (date)

**Business-Specific** (customize per client):
- `business_{attribute}` — always prefix with `business_` for client-specific fields

## Pipeline Design Principles

1. **One pipeline per journey type** — don't mix lead qualification and onboarding in the same pipeline
2. **Stages are states, not actions** — name stages as statuses ("Qualified", "Proposal Sent") not actions ("Send Proposal")
3. **Every stage has an automation** — workflow-per-stage architecture prevents manual gaps
4. **Include exit stages** — "Closed Lost" and "Closed Won" with reason tags for analytics
5. **Monetary value at creation** — set estimated deal value when creating the opportunity, update as it refines

## Troubleshooting Decision Tree

**Webhook not firing?**
→ Is the workflow published (not draft)?
→ Is the trigger filter correct (right form/page/pipeline)?
→ Is the contact already in the workflow (duplicate prevention)?
→ Check execution logs for the specific contact

**API returning 401?**
→ Is the token expired? (OAuth2 tokens have TTL — implement refresh)
→ Is the scope sufficient for this endpoint?
→ Are you using the correct location ID?

**API returning 429?**
→ Check which limit you hit: daily (200k/day) or burst (100/10 seconds)
→ Burst limit is the most common cause — add 200-500ms delays between batched API calls
→ Implement exponential backoff with jitter
→ Batch operations where possible (fewer calls)
→ Consider spreading large operations across time windows

**n8n webhook not receiving GHL data?**
→ Is the n8n webhook URL publicly accessible (not localhost)?
→ Is the GHL Custom Webhook action using POST (not GET)?
→ Check n8n execution log — is the webhook node listening?
→ Verify the payload structure matches what n8n expects

## Response Calibration

Adapt response depth to the user's expertise level:

**Expert user signals** (uses GHL/n8n jargon, references specific endpoints, mentions OAuth scopes by name):
→ Skip platform overview, go straight to the specific answer. Use code/config snippets, not explanations of what GHL is.

**Intermediate user signals** (knows what GHL is, asks "how do I" questions, mentions workflows generically):
→ Provide the pattern + implementation steps. Include the "why" briefly but focus on the "how."

**Beginner user signals** (vague questions, no platform terminology, asks what things mean):
→ Start with the relevant concept, then walk through step by step. Link to reference files for deeper reading.

When in doubt, match the user's vocabulary and depth. If they ask a one-line question, don't write a 500-line response.

## Resources & Links
- GHL Developer Portal: https://marketplace.gohighlevel.com/docs/
- GHL Webhook Guide: https://marketplace.gohighlevel.com/docs/webhook/WebhookIntegrationGuide/
- GHL Changelog: https://ideas.gohighlevel.com/changelog
- GHL Support: https://help.gohighlevel.com/support/solutions/articles/48001060529
