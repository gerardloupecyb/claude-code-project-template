# GHL Security Patterns

Comprehensive security-by-design patterns for GoHighLevel implementations.

## Table of Contents
1. [OAuth2 Implementation](#oauth2-implementation)
2. [API Key Management](#api-key-management)
3. [Webhook Security](#webhook-security)
4. [RBAC & Least Privilege](#rbac--least-privilege)
5. [Data Protection & Compliance](#data-protection--compliance)
6. [Credential Storage](#credential-storage)
7. [Audit Logging](#audit-logging)

---

## OAuth2 Implementation

### Token Lifecycle
GHL OAuth2 tokens expire. Every integration must handle the full lifecycle:

```
1. Initial Authorization
   User clicks "Connect" → Redirect to GHL OAuth consent screen
   → User grants scopes → Redirect back with authorization code
   → Exchange code for access_token + refresh_token

2. Token Usage
   Every API call: Authorization: Bearer {access_token}
   Monitor for 401 responses (token expired)

3. Token Refresh (CRITICAL — automate this)
   POST https://services.leadconnectorhq.com/oauth/token
   Body: {
     "client_id": "YOUR_CLIENT_ID",
     "client_secret": "YOUR_CLIENT_SECRET",
     "grant_type": "refresh_token",
     "refresh_token": "STORED_REFRESH_TOKEN"
   }
   → Store new access_token and refresh_token
   → Old refresh_token is invalidated

4. Token Revocation (on disconnect/offboarding)
   Revoke tokens when a client disconnects or is offboarded
```

### Scope Selection (Least Privilege)
Request ONLY the scopes your integration needs:

| Scope | Grants Access To | Request When |
|-------|-----------------|--------------|
| `contacts.readonly` | Read contacts | Reporting, dashboards |
| `contacts.write` | Create/update/delete contacts, manage tags | Lead sync, enrichment |
| `opportunities.readonly` | Read pipeline data | Reporting |
| `opportunities.write` | Create/update deals | Pipeline automation |
| `calendars.readonly` | Read calendars | Calendar listing |
| `calendars/events.readonly` | Read appointments, blocked slots | Scheduling reports |
| `calendars.write` | Create/modify calendars | Calendar management |
| `calendars/events.write` | Create/modify appointments | Booking automation |
| `conversations.readonly` | Read conversation threads | Conversation history, search |
| `conversations/message.readonly` | Read messages within conversations | Message content access, analytics |
| `conversations/message.write` | Send messages, update status | Automated messaging (SMS, email) |
| `conversations/reports.readonly` | Read conversation analytics | Reporting dashboards only |
| `workflows.readonly` | Read workflows | Audit, monitoring |
| `locations.readonly` | Read location info | Multi-location management |
| `locations/tags.write` | Manage tags | Tagging automation |
| `conversations-ai.readonly` | Read Conversation AI agents & generations | AI reporting, compliance export |
| `conversations-ai.write` | Create/update AI agents and actions | AI agent provisioning at scale |

**Anti-pattern**: Requesting all scopes "just in case." This violates least privilege and may be flagged during GHL marketplace review.

### Token Storage Best Practices

```javascript
// GOOD: Store in environment variable or secret manager
const accessToken = process.env.GHL_ACCESS_TOKEN;

// GOOD: In n8n, use the GHL OAuth2 credential type
// n8n handles token refresh automatically when configured properly

// BAD: Hardcoded in workflow JSON or code
const accessToken = "eyJhbGciOiJSUzI1NiIs..."; // NEVER DO THIS

// BAD: Stored in GHL custom field or note
// Contact records are NOT secure storage
```

---

## API Key Management

### Legacy API Keys vs OAuth2
GHL still supports legacy API keys for some operations, but OAuth2 is the standard for marketplace apps and new integrations.

**When legacy keys are still used:**
- Internal tools that only access one location
- Quick prototyping (migrate to OAuth2 before production)
- Some n8n integrations that use the "Header Auth" credential type

**Key rotation pattern:**
```
1. Generate new API key in GHL settings
2. Update all systems that use the old key (n8n credentials, external apps)
3. Verify all integrations work with new key
4. Revoke old key
5. Document rotation date in ops log
```

**Rotation schedule**: Minimum every 90 days, or immediately if:
- A team member with access leaves
- Key is accidentally exposed (logs, git, Slack)
- Unusual API activity detected

### V1 API Deprecation Notice
GHL V1 APIs have reached **end-of-support**. Existing integrations may continue to work, but no support or updates are provided. The ability to generate new API keys is being removed from accounts that haven't already generated one. All new integrations must use OAuth2 or Private Integration Tokens.

---

## Private Integration Tokens (PIT)

PITs are a newer authentication mechanism — essentially static OAuth2 tokens with scope restrictions. They're the recommended replacement for legacy API keys.

### When to Use PITs
- Internal tools and server-to-server integrations (e.g., n8n → GHL)
- Single-location access without the full OAuth2 authorization flow
- Simpler setup when you don't need marketplace app distribution

### When NOT to Use PITs
- Marketplace apps (must use OAuth2 for distribution and review)
- Multi-location integrations where each location needs its own token (OAuth2 is better for this)
- Situations where automatic token refresh is critical (PITs don't expire like OAuth2 tokens, but this also means they're a longer-lived credential to protect)

### PIT Setup
1. Go to the sub-account → Settings → Private Integrations
2. Create a new integration (name it descriptively: "n8n Contact Sync")
3. Select **only** the scopes your integration needs (least privilege)
4. Save and copy the token — it's shown only once
5. Store the token in your credential manager (n8n credential, environment variable, vault)

### PIT vs OAuth2 Comparison

| Feature | PIT | OAuth2 |
|---------|-----|--------|
| Setup complexity | Simple (generate in settings) | Complex (marketplace app, redirect flow) |
| Token expiry | Does not expire | Expires ~24 hours, requires refresh |
| Scope restriction | Yes (selected at creation) | Yes (requested in auth flow) |
| Multi-location | One PIT per sub-account | One app, authorized per location |
| Marketplace distribution | No | Yes |
| Token refresh needed | No | Yes (critical to automate) |
| Credential risk | Higher (long-lived token) | Lower (short-lived + refresh) |

### PIT in n8n
Create a "Header Auth" credential in n8n:
```
Name: Authorization
Value: Bearer {your-PIT-token}
```
Add `Version: 2021-07-28` as a header in every HTTP Request node.

**Security note**: Since PITs don't expire, protect them with extra care. Rotate them if a team member with access leaves or if you suspect exposure. You can update PIT scopes and regenerate tokens in the sub-account settings without affecting other integrations.

---

## Webhook Security

### Signature Verification (Inbound from GHL)
GHL signs outbound webhook payloads. Always verify before processing.

**Two signature schemes exist during the transition period:**

| Header              | Algorithm  | Status                                 | Deadline         |
|---------------------|------------|----------------------------------------|------------------|
| `X-GHL-Signature`   | Ed25519    | **PREFERRED** — use this               | Current standard |
| `X-WH-Signature`    | RSA-SHA256 | **DEPRECATED** — removed July 1, 2026  | Legacy only      |

**Transition pattern:** Check `X-GHL-Signature` first (Ed25519). Fall back to `X-WH-Signature` (RSA-SHA256) only during the transition period. After July 1, 2026, only Ed25519 will be available.

Source: [GHL Webhook Integration Guide](https://marketplace.gohighlevel.com/docs/webhook/WebhookIntegrationGuide/)

```javascript
const crypto = require('crypto');

// PRIMARY: Ed25519 verification (current standard)
function verifyEd25519Signature(payload, signatureHex, publicKeyHex) {
  const publicKey = Buffer.from(publicKeyHex, 'hex');
  const signature = Buffer.from(signatureHex, 'hex');
  const data = Buffer.from(JSON.stringify(payload));
  return crypto.verify(null, data, { key: publicKey, format: 'der', type: 'ed25519' }, signature);
}

// LEGACY: RSA-SHA256 verification (deprecated — removed July 1, 2026)
function verifyRSASignature(payload, signature, publicKey) {
  const verifier = crypto.createVerify('RSA-SHA256');
  verifier.update(JSON.stringify(payload));
  return verifier.verify(publicKey, signature, 'base64');
}

// In your webhook handler (Express.js / n8n Code node)
function handleWebhook(req) {
  const ed25519Sig = req.headers['x-ghl-signature'];
  const rsaSig = req.headers['x-wh-signature'];

  // Prefer Ed25519 (new standard)
  if (ed25519Sig) {
    if (!verifyEd25519Signature(req.body, ed25519Sig, GHL_ED25519_PUBLIC_KEY)) {
      throw new Error('Invalid Ed25519 webhook signature — possible tampering');
    }
    return processWebhookPayload(req.body);
  }

  // Fall back to RSA-SHA256 (legacy — remove this branch after July 1, 2026)
  if (rsaSig) {
    if (!verifyRSASignature(req.body, rsaSig, GHL_RSA_PUBLIC_KEY)) {
      throw new Error('Invalid RSA webhook signature — possible tampering');
    }
    return processWebhookPayload(req.body);
  }

  throw new Error('Missing webhook signature — neither X-GHL-Signature nor X-WH-Signature present');
}
```

> **Migration note (2026-03-21):** If your integration currently uses `X-WH-Signature` (RSA-SHA256), migrate to `X-GHL-Signature` (Ed25519) before July 1, 2026. During transition, implement the dual-header check above. After the deadline, simplify to Ed25519 only.

### Securing Your Webhook Endpoints (Inbound to n8n)

When GHL sends webhooks to your n8n instance, protect the endpoint:

**Option 1: HMAC signing in GHL Custom Webhook action**
Add a computed HMAC to the outbound payload:
```json
{
  "contact": { "id": "{{contact.id}}", "email": "{{contact.email}}" },
  "timestamp": "{{date.now}}",
  "hmac": "{{hmac_sha256(contact.id + date.now, SHARED_SECRET)}}"
}
```
Then verify in n8n before processing.

**Option 2: Secret path segment**
Use a webhook URL with a random path: `https://n8n.example.com/webhook/a8f3k2x9-ghl-intake`
Not cryptographic security, but adds obscurity. Combine with IP filtering if possible.

**Option 3: Header-based auth**
In GHL Custom Webhook action, add a custom header:
```
X-Webhook-Secret: your-shared-secret-here
```
Verify in n8n's webhook node or a subsequent Code node.

**Recommended**: Use Option 1 (HMAC) + Option 2 (secret path) together.

### Webhook Payload Hygiene
- Only include necessary fields in outbound webhook payloads — don't send entire contact records if you only need an ID and a tag
- Never include API keys or tokens in webhook payloads
- Sanitize template variables — `{{contact.email}}` could contain unexpected characters
- Log webhook deliveries for debugging but redact PII in logs

---

## RBAC & Least Privilege

### GHL User Roles
GHL supports role-based access at the agency and location level:

| Role | Access Level | Use For |
|------|-------------|---------|
| Agency Admin | Full agency + all locations | Agency owner only |
| Agency User | Agency-level with assigned locations | Team leads, managers |
| Location Admin | Full access to one location | Client account managers |
| Location User | Limited access to one location | Sales reps, support staff |

### Role Design Principles
1. **One role per function** — sales reps don't need workflow editing access
2. **Location scoping** — users only see locations they manage
3. **API token scoping** — tokens inherit the permissions of the user who created them
4. **Audit on role changes** — log when roles are granted or revoked

### Custom Permission Mapping
For each user type, define explicit permissions:

```
Sales Rep:
  ✅ View/edit contacts in assigned pipeline
  ✅ Send messages (SMS, email)
  ✅ Create/update opportunities
  ✅ View calendar, book appointments
  ❌ Edit workflows
  ❌ Access API settings
  ❌ Export contact lists
  ❌ Delete contacts

Operations Manager:
  ✅ Everything Sales Rep can do
  ✅ Edit workflows
  ✅ View reports and analytics
  ✅ Manage tags and custom fields
  ❌ Access API settings
  ❌ Manage user roles
  ❌ Access billing

Technical Admin:
  ✅ Everything Operations Manager can do
  ✅ Access API settings and webhooks
  ✅ Manage integrations
  ✅ View audit logs
  ❌ Manage billing (separate concern)
```

---

## Data Protection & Compliance

### Loi 25 (Quebec) / PIPEDA Requirements in GHL

**Consent Management:**
- Track consent with custom fields: `compliance_marketing_consent`, `compliance_consent_date`, `compliance_consent_source`
- Never assume consent — explicit opt-in required for marketing communications
- Provide easy opt-out in every SMS/email (GHL's unsubscribe link + STOP keyword)

**Data Subject Access Requests (DSAR):**
- Build a DSAR workflow: form submission → tag → webhook to n8n → compile data → respond
- GHL API can export all contact data including notes, conversations, opportunities
- Response deadline: 30 days under Loi 25, reasonable time under PIPEDA
- See DSAR automation pattern in SKILL.md

**Data Retention:**
- Set `compliance_data_retention_expiry` on every contact
- Build a scheduled n8n workflow that queries contacts past expiry → archive or delete
- Document retention periods per data type (contact info, conversations, recordings)

**Data Minimization:**
- Only collect fields you actually need — don't create 50 custom fields "just in case"
- Periodically audit custom fields — remove unused ones
- Webhook payloads should send minimum required data

### PII Identification in GHL
Tag these fields as PII in your documentation and handle accordingly:
- `email`, `phone`, `firstName`, `lastName`, `address1`, `city`, `postalCode`
- `date_of_birth`, `companyName` (can be PII in some contexts)
- All conversation content (SMS, email, call recordings)
- Custom fields containing health, financial, or legal information

---

## Credential Storage

### By Environment

| Environment | Storage Method | Example |
|-------------|---------------|---------|
| n8n (self-hosted) | n8n Credential Manager (encrypted at rest) | Create "GHL OAuth2" credential |
| n8n (cloud) | n8n Credential Manager | Same — n8n cloud encrypts credentials |
| Node.js app | Environment variables + `.env` file (gitignored) | `GHL_ACCESS_TOKEN=...` |
| Production server | Secret manager (AWS Secrets Manager, Azure Key Vault, GCP Secret Manager) | Fetch at runtime |
| CI/CD pipeline | Pipeline secrets / vault integration | GitHub Secrets, GitLab CI variables |

### Credential Rotation Checklist
When rotating credentials:
1. Generate new credential in GHL
2. Update in all locations (n8n, apps, scripts)
3. Test each integration with new credential
4. Verify old credential is revoked
5. Update rotation log with date and who performed it
6. Set calendar reminder for next rotation

### Emergency Credential Revocation
If a credential is compromised:
1. **Immediately** revoke the token/key in GHL settings
2. Generate a new credential
3. Update all integrations
4. Review API logs for unauthorized access during exposure window
5. Notify affected clients if their data may have been accessed
6. Document the incident for compliance records

---

## Audit Logging

### What to Log
- All API calls (endpoint, method, status code, timestamp, user/token)
- Webhook deliveries (success/failure, payload hash, destination)
- Contact data changes (field changed, old value → new value, who/what changed it)
- Role changes (user, old role → new role, who made the change)
- Workflow executions (trigger, actions taken, errors)
- Credential events (creation, rotation, revocation)

### Implementation Pattern (n8n-based)
```
Every n8n workflow that touches GHL should:
1. Log the operation start (timestamp, operation type, target entity)
2. Execute the GHL API call
3. Log the result (success/failure, response code, affected entity IDs)
4. On failure: log error details + alert ops team
5. Store logs in: PostgreSQL table, Airtable, or structured log file
```

### Log Retention
- API access logs: 1 year minimum (compliance)
- Contact change logs: match data retention policy
- Security event logs (failed auth, signature failures): 2 years minimum
- Workflow execution logs: 90 days minimum (GHL's built-in logs are limited)
