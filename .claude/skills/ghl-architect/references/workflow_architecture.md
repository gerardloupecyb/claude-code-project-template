# GHL Workflow Architecture Patterns

Design patterns for building reliable, maintainable, and secure GoHighLevel workflows.

## Table of Contents
1. [Naming Conventions](#naming-conventions)
2. [Workflow Structural Patterns](#workflow-structural-patterns)
3. [Error Handling](#error-handling)
4. [Idempotency](#idempotency)
5. [Rollback & Recovery](#rollback--recovery)
6. [Workflow Lifecycle Management](#workflow-lifecycle-management)
7. [Testing & Validation](#testing--validation)

---

## Naming Conventions

### Workflow Names
Format: `{CATEGORY}_{TRIGGER}_{PURPOSE}_{VERSION}`

```
Examples:
  LEAD_FormSubmit_InstantResponse_v2
  PIPE_StageChange_QualifiedNotify_v1
  NURTURE_Tag_ReactivationDrip_v3
  COMPLIANCE_Form_DSARProcess_v1
  ONBOARD_Appointment_WelcomeSequence_v1
  SYNC_Webhook_N8NContactUpdate_v1
```

**Categories:**
- `LEAD` — lead capture and initial response
- `PIPE` — pipeline stage-driven automation
- `NURTURE` — email/SMS nurture sequences
- `COMPLIANCE` — data protection, consent, DSAR
- `ONBOARD` — customer onboarding flows
- `SYNC` — integration sync workflows
- `ADMIN` — internal operations, notifications
- `REACTIVATE` — dormant lead reactivation

### Tag Names
Format: `{domain}:{category}:{value}`

```
Examples:
  source:facebook:campaign-winter-2025
  status:lead:qualified
  workflow:nurture:day3-complete
  compliance:consent:marketing-opt-in
  integration:n8n:synced
  error:workflow:instant-response-failed
```

### Custom Field Names
Format: `{domain}_{entity}_{attribute}` (snake_case, always prefixed)

```
Examples:
  scoring_lead_score
  compliance_consent_date
  integration_n8n_sync_id
  lifecycle_stage
  business_service_interest
```

---

## Workflow Structural Patterns

### Pattern 1: Linear Sequence with Checkpoints
Use for nurture campaigns and onboarding flows.

```
Trigger: [Event]
  ↓
Checkpoint: Tag "workflow:{name}:started"
  ↓
Action 1
  ↓
Wait: [Duration]
  ↓
Action 2
  ↓
Wait: [Duration]
  ↓
Action 3
  ↓
Checkpoint: Tag "workflow:{name}:completed"
  Remove tag "workflow:{name}:started"
```

The checkpoint tags enable:
- Querying "who is currently in this workflow?"
- Preventing duplicate enrollment (trigger filter: does NOT have tag `workflow:{name}:started`)
- Auditing workflow completion rates

### Pattern 2: Workflow-Per-Stage (Pipeline Architecture)
Use for sales processes with stage-specific automation.

```
WORKFLOW A: PIPE_Stage_NewLead_v1
  Trigger: Opportunity Stage = "New Lead"
  Filter: Tag does NOT contain "workflow:pipe:new-lead:started"
  Actions:
    1. Tag: "workflow:pipe:new-lead:started"
    2. Send welcome SMS
    3. Create task: "Call within 24hrs"
    4. Internal notification
    5. Tag: "workflow:pipe:new-lead:completed"

WORKFLOW B: PIPE_Stage_Qualified_v1
  Trigger: Opportunity Stage = "Qualified"
  Actions:
    1. Remove tag "workflow:pipe:new-lead:started" (stop Workflow A)
    2. Tag: "workflow:pipe:qualified:started"
    3. Send calendar link
    4. Update lead score +20
    5. Assign to senior closer

WORKFLOW C: PIPE_Stage_ClosedWon_v1
  Trigger: Opportunity Stage = "Closed Won"
  Actions:
    1. Remove all pipeline workflow tags
    2. Tag: "status:customer"
    3. Trigger onboarding sequence
    4. Internal celebration notification
```

**Critical rule**: Each new stage workflow REMOVES tags from the previous stage workflow. This prevents contacts from being in multiple automations simultaneously.

### Pattern 3: Conditional Fan-Out
Use when different paths are needed based on contact attributes or behavior.

```
Trigger: [Event]
  ↓
Conditional: Check attribute/behavior
  ├─ Branch A (e.g., High Score)
  │    → Hot lead sequence
  │    → Priority assignment
  ├─ Branch B (e.g., Medium Score)
  │    → Nurture sequence
  │    → Standard assignment
  └─ Branch C (e.g., Low Score / Default)
       → Long-term drip
       → No assignment (automated only)
```

**Always include a default branch.** Never assume all contacts will match Branch A or B — unmatched contacts silently exit the workflow with no action taken.

### Pattern 4: Webhook Relay (GHL → External → GHL)
Use for n8n integrations and external processing.

```
Trigger: [GHL Event]
  ↓
Action: Custom Webhook OUT → n8n
  Body: { contact_id, event_type, timestamp, relevant_data }
  ↓
[n8n processes externally]
  ↓
n8n: Custom Webhook IN → GHL (different workflow)
  Body: { contact_id, action, data }
  ↓
GHL Workflow: Process return data
  Update contact, add tags, move pipeline stage
```

**Security note**: Both the outbound and inbound webhooks must be authenticated. See `references/security_patterns.md` for HMAC and header auth patterns.

### Pattern 5: Scheduled Maintenance Workflow
Use for database hygiene, compliance checks, and reporting.

```
Trigger: Date/Time (recurring — e.g., every Monday at 6 AM)
  ↓
Action: Custom Webhook → n8n
  Body: { action: "maintenance", type: "stale_lead_check" }
  ↓
n8n: Query GHL API for contacts matching criteria
  (e.g., last_engagement_date > 90 days, no "customer" tag)
  ↓
n8n: For each matching contact:
  POST tag "status:lead:stale"
  ↓
Back in GHL: Tag-triggered workflow handles stale leads
  (reactivation sequence or archive)
```

---

## Error Handling

### The Error Branch Pattern
Every production workflow must have error handling. GHL doesn't have native try/catch, so use conditional branches:

```
Trigger: [Event]
  ↓
Action: Primary operation
  ↓
Conditional: Was the action successful?
  ├─ YES → Continue normal flow
  └─ NO → Error branch
            1. Tag: "error:workflow:{name}"
            2. Add note with error context
            3. Internal notification (Slack/email)
            4. DO NOT continue the normal flow
```

### Webhook Error Handling
When using Custom Webhook actions that call n8n or external systems:

**GHL-side:**
- GHL retries failed webhooks 3 times, then gives up
- No built-in way to check if webhook delivery succeeded
- Mitigation: n8n should call back to GHL (update tag/field) on successful processing — if no callback within X minutes, the contact is likely stuck

**n8n-side:**
- Always respond 200 to GHL webhook immediately (before processing)
- Process asynchronously to avoid timeout
- On processing failure: call GHL API to tag contact with error tag
- Implement dead-letter queue (log failed items for manual review)

### Common Error Scenarios

| Error | Cause | Resolution |
|-------|-------|------------|
| Contact stuck in workflow | Wait step + condition never met | Add timeout waits with fallback branches |
| Duplicate contacts created | Race condition on form submit | Use dedup by email/phone before creating |
| Wrong pipeline stage | Multiple workflows updating simultaneously | Use workflow-per-stage with tag guards |
| Webhook timeout | n8n takes too long to respond | Return 200 immediately, process async |
| SMS not delivered | Invalid phone number or carrier block | Check phone validation before sending |

---

## Idempotency

### Why It Matters
GHL workflows can re-trigger due to tag updates, field changes, or webhook retries. Without idempotency, you get duplicate SMS, duplicate contacts, and duplicate pipeline entries.

### Implementation Patterns

**Tag-Based Idempotency Guard:**
```
Trigger: [Event]
  ↓
Conditional: Has tag "workflow:{name}:processed"?
  ├─ YES → Exit (already processed)
  └─ NO → Continue
            1. Tag: "workflow:{name}:processed"
            2. Execute actions
```

**Custom Field Idempotency Key:**
For API integrations, store a unique processing ID:
```
Custom Field: integration_last_processed_event (text)
  ↓
Before processing: Check if event_id matches last_processed_event
  ├─ Match → Skip (already processed)
  └─ No match → Process, then update field with current event_id
```

**Timestamp-Based Guard (for scheduled workflows):**
```
Custom Field: workflow_{name}_last_run (date)
  ↓
Before processing: Check if last_run is within the recurrence window
  ├─ Already ran today → Skip
  └─ Not yet → Process, then update last_run
```

---

## Rollback & Recovery

### Rollback Pattern (Tag-Based State Machine)
Since GHL workflows can't natively undo actions, use tags as a state machine:

```
State Tags:
  workflow:{name}:step1_complete
  workflow:{name}:step2_complete
  workflow:{name}:step3_complete

Rollback Workflow:
  Trigger: Tag "workflow:{name}:rollback" added
  ↓
  Conditional: Which step was last completed?
  ├─ Step 3 → Undo step 3 actions (remove tags, revert pipeline stage)
  ├─ Step 2 → Undo step 2 actions
  └─ Step 1 → Undo step 1 actions
  ↓
  Remove all step completion tags
  Tag: "workflow:{name}:rolled_back"
  Internal notification
```

### Recovery Pattern (for stuck contacts)
Build a "sweep" workflow that runs periodically:

```
Trigger: Scheduled (daily)
  ↓
Custom Webhook → n8n
  ↓
n8n: Query contacts with "workflow:*:started" tags
     older than expected completion time
  ↓
For each stuck contact:
  Option A: Re-trigger the workflow
  Option B: Move to error queue for manual review
  Option C: Force-complete with notification
  ↓
Log all recovery actions
```

---

## Workflow Lifecycle Management

### Version Control
GHL doesn't have native workflow versioning. Compensate:

1. **Name includes version**: `LEAD_FormSubmit_InstantResponse_v2`
2. **Before editing**: Clone the workflow as a backup (append `_backup_YYYY-MM-DD`)
3. **After major changes**: Test in a staging location before deploying to production
4. **Document changes**: Keep a changelog in your ops documentation

### Deployment Checklist
Before publishing a workflow:
- [ ] Workflow name follows naming convention
- [ ] Trigger filters are set (prevent unintended contacts from entering)
- [ ] Idempotency guard is in place (tag or field check)
- [ ] Error branch exists on all action paths
- [ ] Tags follow naming convention
- [ ] Custom webhook URLs point to production (not staging/localhost)
- [ ] Credentials are not hardcoded in any action
- [ ] Wait steps have reasonable timeouts
- [ ] Test contact has been run through successfully
- [ ] Previous workflow version is backed up (cloned)

### Retirement Process
When deprecating a workflow:
1. Create new version and publish it
2. Pause the old workflow (don't delete yet)
3. Wait for all contacts to exit the old workflow (check "in workflow" count)
4. After all contacts have exited: rename old workflow to `DEPRECATED_{original_name}`
5. Keep for 90 days for reference, then delete

---

## Testing & Validation

### Test Contact Protocol
- Create dedicated test contacts with tag `test:contact`
- Use recognizable data: `test+ghl@yourdomain.com`, phone `+15555550100`
- After testing: remove test contacts or archive them
- **Never test with real customer data**

### Pre-Launch Validation
```
1. Trigger test:
   - Create test contact matching trigger criteria
   - Verify workflow activates
   - Verify trigger filters exclude non-matching contacts

2. Branch test:
   - Test each conditional branch with appropriate data
   - Verify default/fallback branch works

3. Webhook test:
   - Verify outbound webhooks reach destination
   - Verify inbound webhooks trigger correctly
   - Test with malformed payloads (should be handled gracefully)

4. Timing test:
   - Verify wait steps have correct durations
   - Check timezone handling (GHL uses the location's timezone)

5. Error test:
   - Simulate a failure (e.g., invalid phone for SMS)
   - Verify error branch activates
   - Verify notifications are sent

6. Idempotency test:
   - Re-trigger the same event for the same contact
   - Verify no duplicate actions occur
```
