# GHL Agency & White-Label Governance

Architecture patterns for multi-tenant GoHighLevel deployments with sub-account isolation, snapshot governance, and client data separation.

## Table of Contents
1. [Agency Architecture Overview](#agency-architecture-overview)
2. [Sub-Account Isolation](#sub-account-isolation)
3. [Snapshot Governance](#snapshot-governance)
4. [Client Onboarding Architecture](#client-onboarding-architecture)
5. [Cross-Location Intelligence](#cross-location-intelligence)
6. [Client Offboarding & Data Handling](#client-offboarding--data-handling)

---

## Agency Architecture Overview

### GHL Hierarchy
```
Agency Account (SaaS Mode)
  ├── Location A (Client: Law Firm X)
  │     ├── Contacts
  │     ├── Pipelines
  │     ├── Workflows
  │     ├── Custom Fields
  │     └── Integrations (own API tokens)
  │
  ├── Location B (Client: Clinic Y)
  │     └── [Same structure, completely isolated]
  │
  ├── Location C (Internal: Template/Staging)
  │     └── [Used for snapshot creation and testing]
  │
  └── Agency-Level Settings
        ├── Branding (white-label domain, logo)
        ├── User management (agency users)
        ├── Billing (Stripe integration)
        └── Snapshot library
```

### Design Principles
1. **Location = tenant boundary** — never share data across locations unless explicitly designed
2. **Snapshots = deployment units** — treat snapshots like software releases (versioned, tested, documented)
3. **Agency tokens ≠ location tokens** — use location-scoped tokens for per-client operations
4. **Client data belongs to the client** — architect for data portability from day one

---

## Sub-Account Isolation

### Data Isolation Rules
Each GHL location (sub-account) has its own:
- Contact database (no cross-location contact queries)
- Pipeline configurations
- Workflow definitions
- Custom fields and values
- Calendar settings
- API credentials and webhook registrations
- Conversation history

**Violation to avoid**: Using an agency-level API token to access multiple locations in a single n8n workflow. This creates a security risk — if the token is compromised, all client data is exposed.

### Token Scoping Pattern
```
CORRECT:
  Location A → OAuth2 token scoped to Location A
  Location B → OAuth2 token scoped to Location B
  Each n8n workflow uses the appropriate location token

INCORRECT:
  Agency-level token used for all locations
  Single n8n workflow switches between locations with the same token
```

### n8n Credential Per Location
In n8n, create separate credentials for each GHL location:
```
Credential: "GHL - Law Firm X" → Location A token
Credential: "GHL - Clinic Y" → Location B token
Credential: "GHL - Template" → Staging location token
```

This ensures:
- A bug in one client's workflow can't affect another client's data
- Token rotation is per-client (rotating one doesn't break others)
- Audit trail is clear (which token accessed what)

### Cross-Location Exceptions
Sometimes you legitimately need cross-location data (e.g., agency-wide reporting). Design this carefully:

```
Pattern: Agency Reporting Dashboard
  n8n Schedule Trigger (weekly)
    ↓
  For Each Location (configured list):
    HTTP Request: GHL API with location-specific token
      GET /opportunities/?status=won
    ↓
    Code Node: Extract KPIs (deals won, revenue, lead count)
    ↓
  Merge Node: Combine all location KPIs
    ↓
  Output: Write to agency dashboard (Google Sheets, Retool, etc.)
```

**Security**: Each location is queried with its own token. The n8n workflow has access to all tokens, so protect the n8n instance accordingly (authentication, network isolation, encrypted credentials).

---

## Snapshot Governance

### Snapshot = Deployment Unit
A GHL snapshot captures an entire location's configuration: pipelines, workflows, custom fields, templates, funnels, calendars. Treat them like software releases.

### Versioning Convention
```
{industry}_{tier}_{version}_{date}
```
Examples:
```
lawfirm_standard_v3_2025-03
clinic_premium_v2_2025-01
agency_onboarding_v1_2025-02
```

### Snapshot Lifecycle
```
1. DEVELOP
   Create/modify in the staging location (Location C)
   Test all workflows with test contacts
   Verify custom field taxonomy is complete

2. REVIEW
   Document what's included (workflows, pipelines, fields, templates)
   Review security: no hardcoded credentials in workflows
   Review compliance: consent flows, DSAR workflow included

3. TAG
   Name the snapshot with version convention
   Record in snapshot changelog:
     - Version, date, author
     - What changed from previous version
     - Known limitations

4. DEPLOY
   Apply snapshot to target location
   Post-deployment: verify workflows are published
   Post-deployment: configure location-specific settings (API tokens, webhook URLs, branding)

5. MAINTAIN
   When updating: create new version, don't modify deployed snapshots
   Existing clients on v2 can be upgraded to v3 with a migration plan
```

### Snapshot Contents Checklist
Before deploying a snapshot, verify it includes:

**Required:**
- [ ] Core pipelines with all stages
- [ ] Workflow-per-stage automations
- [ ] Custom field taxonomy (all `{domain}_{entity}_{attribute}` fields)
- [ ] Tag taxonomy documentation (as a GHL document or custom value set)
- [ ] Email/SMS templates
- [ ] Consent management workflow
- [ ] Error handling on all workflows

**Recommended:**
- [ ] DSAR automation workflow
- [ ] Lead scoring system (custom fields + workflows)
- [ ] Reporting webhook (to n8n for analytics)
- [ ] Calendar with appointment types
- [ ] Branded funnel/landing page templates

**Excluded (configure per-location):**
- API tokens and OAuth credentials
- Webhook URLs (point to correct n8n instance)
- DNS/domain settings
- Stripe/payment integration
- Phone number assignments
- Custom branding (logo, colors)

### Post-Deployment Configuration
After applying a snapshot to a new location:

```
1. API & Integrations
   - Create location-specific OAuth2 credential
   - Update all Custom Webhook URLs in workflows to point to correct n8n endpoints
   - Configure n8n credential for this location
   - Test webhook connectivity (send test event)

2. Communication Setup
   - Assign phone numbers for SMS
   - Configure email domain (SPF/DKIM/DMARC)
   - Warm up email sending domain
   - Verify Twilio/Mailgun integration

3. Branding
   - Upload client logo
   - Set brand colors
   - Configure custom domain (if white-labeled)

4. Team Access
   - Create user accounts with appropriate roles
   - Assign users to pipelines and calendars
   - Set round-robin rules for lead assignment

5. Validation
   - Run test contact through each workflow
   - Verify all conditional branches
   - Confirm webhook round-trips (GHL → n8n → GHL)
   - Test appointment booking flow
   - Verify SMS and email delivery
```

---

## Client Onboarding Architecture

### Automated Onboarding Pipeline
```
Stage 1: Contract Signed
  Actions:
    - Create GHL location from snapshot
    - Assign agency user as location admin
    - Tag in agency CRM: "client:onboarding"

Stage 2: Technical Setup
  Actions:
    - Configure DNS (email domain, custom domain)
    - Create n8n credentials for this location
    - Update webhook URLs in GHL workflows
    - Configure payment integration (Stripe)
    - Run connectivity tests

Stage 3: Data Migration
  Actions:
    - Import existing contacts (CSV or API)
    - Map external fields to GHL custom fields
    - Set integration_n8n_sync_id for each imported contact
    - Verify no duplicate contacts

Stage 4: Training & Handoff
  Actions:
    - Create user accounts for client team
    - Schedule training session
    - Provide documentation (workflows, tags, custom fields)
    - Set up support channel

Stage 5: Active
  Actions:
    - Publish all workflows
    - Enable automated reporting
    - Tag: "client:active"
    - Schedule first monthly review
```

### Onboarding Checklist Document
Generate for each new client:

```markdown
# Client Onboarding: {Client Name}
## Location ID: {location_id}
## Snapshot: {snapshot_version}
## Onboarding Date: {date}

### Configuration Status
- [ ] Location created from snapshot {version}
- [ ] DNS configured (SPF/DKIM/DMARC verified)
- [ ] Phone number assigned
- [ ] Stripe connected
- [ ] n8n credentials created
- [ ] Webhook URLs updated (count: {X} workflows)
- [ ] Webhook connectivity verified
- [ ] User accounts created ({X} users)
- [ ] Roles assigned
- [ ] Existing contacts imported ({X} contacts)
- [ ] Dedup verification passed
- [ ] Test contact workflow run completed
- [ ] Training session scheduled ({date})
- [ ] Client documentation delivered
```

---

## Cross-Location Intelligence

### Threat Intelligence Database (for Security-Focused Agencies)
When managing cybersecurity clients, accumulate intelligence across locations:

```
Pattern: Cross-Client Domain Intelligence
  Each client location generates security events
    (phishing alerts, suspicious logins, threat indicators)
  ↓
  GHL Workflow: Custom Webhook → n8n
    ↓
  n8n: Normalize event data
    ↓
  n8n: Write to shared intelligence database
    (PostgreSQL / Supabase — NOT in GHL)
    Schema: { indicator_type, indicator_value, source_client (anonymized), date, severity }
    ↓
  n8n: Query database for cross-client patterns
    "Has this phishing domain been seen at other clients?"
    ↓
  If match: Alert all affected clients proactively
    n8n: For each affected client location:
      HTTP Request → GHL API (location-specific token)
      Add tag: "security:threat-intel:{indicator}"
```

**Data separation**: The intelligence database stores anonymized indicators. Client identity is never shared cross-location — only the threat indicator and detection metadata.

### Agency-Wide Analytics
```
n8n: Weekly scheduled workflow
  ↓
For each active client location:
  1. GET /opportunities/ → pipeline data
  2. GET /contacts/?query= → contact counts
  3. Custom webhook response data → workflow execution stats
  ↓
Aggregate: Total leads, conversion rates, revenue by client
  ↓
Output: Agency dashboard + per-client reports
```

---

## Client Offboarding & Data Handling

### Offboarding Process
When a client leaves:

```
1. Data Export (REQUIRED — client owns their data)
   - Export all contacts (CSV or JSON via API)
   - Export all conversations (email, SMS, call recordings)
   - Export all opportunities and pipeline history
   - Export all notes and custom field data
   - Package and deliver to client

2. Integration Teardown
   - Revoke OAuth2 tokens for this location
   - Remove n8n credentials for this location
   - Delete webhook registrations
   - Remove from cross-location reporting

3. Data Retention Review
   - Check contractual data retention obligations
   - If retention required: archive data, restrict access
   - If no retention required: schedule deletion

4. Location Cleanup
   - Pause all workflows
   - Remove payment integrations
   - If reusable: reset to clean state from snapshot
   - If not reusable: delete location after retention period

5. Documentation
   - Record offboarding date
   - Record data export delivery confirmation
   - Record deletion schedule
   - Update agency CRM: tag "client:offboarded:{date}"
```

### Data Portability Requirements (Loi 25)
Under Quebec's Loi 25, clients have the right to receive their data in a structured, commonly used format. When offboarding:
- Export contacts as CSV with all custom fields
- Export conversations as JSON with timestamps and metadata
- Provide data within 30 days of request
- Document the data transfer for compliance records
