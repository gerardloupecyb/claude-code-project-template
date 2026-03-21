# GHL API v2 Reference

Quick reference for GoHighLevel API v2 endpoints, payloads, and error handling.

> **For the latest API documentation**, use Context7 first:
> 1. `Context7:resolve-library-id` → libraryName: "GoHighLevel"
> 2. `Context7:query-docs` → query your specific endpoint question
>
> **If Context7 is unavailable**, fall back to `web_search` targeting `marketplace.gohighlevel.com/docs/`.
>
> The reference below is a stable baseline. GHL ships updates frequently — always verify with live docs for new endpoints or changed payloads.

## V1 API Deprecation Notice
GHL V1 APIs have reached **end-of-support**. Existing V1 integrations may still function, but no updates or support are provided. The ability to generate new API keys is being removed from accounts. All new integrations must use **OAuth2** or **Private Integration Tokens (PITs)** with the V2 API. If migrating from V1, see the GHL developer portal for the migration guide.

## Base Configuration
```
Base URL: https://services.leadconnectorhq.com
Auth Header: Authorization: Bearer {access_token}
  (OAuth2 access token OR Private Integration Token)
Version Header: Version: 2021-07-28
Content-Type: application/json
```

## Rate Limits
```
Daily Limit:  200,000 requests/day per marketplace app per location
Burst Limit:  100 requests per 10 seconds per marketplace app per location
```
Monitor these response headers:
- `X-RateLimit-Remaining` — requests left in current window
- `X-RateLimit-Reset` — timestamp when limit resets

**Important**: The burst limit (100/10s) can bite you before the daily limit does. If your n8n workflow fires rapid API calls (e.g., a loop without waits), you'll hit 429 errors even with plenty of daily quota remaining. Always add a small delay between batched calls (200-500ms).

## Core Endpoints

### Contacts
| Operation | Method | Endpoint | Notes |
|-----------|--------|----------|-------|
| Create | POST | `/contacts/` | Returns contact with `id` |
| Get | GET | `/contacts/{contactId}` | Full contact record |
| Update | PUT | `/contacts/{contactId}` | Partial update supported |
| Delete | DELETE | `/contacts/{contactId}` | Permanent — respect retention policy |
| List | GET | `/contacts/?limit=100&startAfter={id}` | Cursor-based pagination |
| Add Tags | POST | `/contacts/{contactId}/tags` | Body: `{"tags": ["tag1"]}` |
| Remove Tags | DELETE | `/contacts/{contactId}/tags` | Body: `{"tags": ["tag1"]}` |
| Search | GET | `/contacts/?query={term}` | Searches name, email, phone |

### Opportunities
| Operation | Method | Endpoint | Notes |
|-----------|--------|----------|-------|
| Create | POST | `/opportunities/` | Requires `pipelineId`, `pipelineStageId` |
| Get | GET | `/opportunities/{id}` | Full opportunity record |
| Update | PUT | `/opportunities/{id}` | Partial update supported |
| Change Stage | PUT | `/opportunities/{id}/status` | Body: `{"pipelineStageId": "..."}` |
| Delete | DELETE | `/opportunities/{id}` | Permanent |
| List | GET | `/opportunities/?pipelineId={id}` | Filter by pipeline |

### Calendar / Appointments
| Operation | Method | Endpoint | Notes |
|-----------|--------|----------|-------|
| Create | POST | `/calendars/events/appointments` | Requires `calendarId`, `contactId` |
| List | GET | `/calendars/events/appointments?startDate=&endDate=` | Date range filter |
| List Calendars | GET | `/calendars` | All calendars in location |

### Messaging
| Operation | Method | Endpoint | Notes |
|-----------|--------|----------|-------|
| Send SMS | POST | `/conversations/messages` | `type: "SMS"`, requires `contactId` |
| Send Email | POST | `/conversations/messages` | `type: "Email"`, supports `html` body |

### Webhooks
| Operation | Method | Endpoint | Notes |
|-----------|--------|----------|-------|
| Register | POST | `/hooks` | Returns webhook `id` + `secret` |
| List | GET | `/hooks` | All registered webhooks |
| Delete | DELETE | `/hooks/{hookId}` | Unsubscribe from events |

## Webhook Events

### Contact Events
- `ContactCreate` — new contact created
- `ContactUpdate` — contact field changed
- `ContactDelete` — contact removed
- `ContactTagUpdate` — tags added or removed

### Opportunity Events
- `OpportunityCreate` — new opportunity
- `OpportunityStageUpdate` — pipeline stage changed (includes `previousStageId`, `currentStageId`)
- `OpportunityStatusUpdate` — status changed (open/won/lost)
- `OpportunityDelete` — opportunity removed

### Appointment Events
- `AppointmentCreated` — appointment booked
- `AppointmentUpdated` — appointment rescheduled
- `AppointmentCancelled` — appointment cancelled
- `AppointmentCompleted` — appointment marked complete

### Communication Events
- `OutboundMessage` — SMS/Email sent (includes `type`, `status`)
- `InboundMessage` — SMS/Email received
- `CallCompleted` — call finished

## Webhook Payload Structure
All webhook payloads follow this structure:
```json
{
  "type": "EventName",
  "locationId": "location_id",
  "id": "event_unique_id",
  "webhookId": "hook_id",
  "data": { ... event-specific data ... },
  "timestamp": "ISO-8601"
}
```

## Custom Webhook Action Payloads (Workflow Outbound)
When using Custom Webhook action in GHL workflows, these template variables are available:

**Always available:**
- `{{contact.id}}`, `{{contact.first_name}}`, `{{contact.last_name}}`, `{{contact.full_name}}`
- `{{contact.email}}`, `{{contact.phone}}`, `{{contact.tags}}`
- `{{contact.address1}}`, `{{contact.city}}`, `{{contact.state}}`, `{{contact.country}}`, `{{contact.postal_code}}`
- `{{contact.company_name}}`, `{{contact.website}}`, `{{contact.date_created}}`, `{{contact.contact_source}}`
- `{{locationId}}`, `{{location.name}}`

**Appointment triggers add:**
- `{{appointment.id}}`, `{{appointment.calendar_id}}`, `{{appointment.start_time}}`, `{{appointment.end_time}}`
- `{{appointment.title}}`, `{{appointment.status}}`

**Opportunity triggers add:**
- `{{opportunity.id}}`, `{{opportunity.name}}`, `{{opportunity.pipeline_id}}`
- `{{opportunity.pipeline_stage_id}}`, `{{opportunity.monetary_value}}`, `{{opportunity.status}}`

## Error Responses

| Code | Meaning | Action |
|------|---------|--------|
| 400 | Bad request (invalid payload) | Check request body structure, validate required fields |
| 401 | Unauthorized (token expired or invalid) | Refresh OAuth2 token, check API key validity |
| 403 | Forbidden (insufficient scope) | Review OAuth2 scopes, check user permissions |
| 404 | Resource not found | Verify entity ID exists, check location context |
| 429 | Rate limit exceeded | Implement exponential backoff, check `Retry-After` header |
| 500 | GHL server error | Retry with backoff, report persistent errors to GHL support |

## Pagination Pattern
```javascript
// Cursor-based pagination for contacts
async function getAllContacts(token, locationId) {
  let contacts = [];
  let startAfter = null;
  
  do {
    const params = new URLSearchParams({ limit: '100' });
    if (startAfter) params.set('startAfter', startAfter);
    
    const response = await fetch(
      `https://services.leadconnectorhq.com/contacts/?${params}`,
      {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Version': '2021-07-28'
        }
      }
    );
    
    if (response.status === 429) {
      const retryAfter = parseInt(response.headers.get('Retry-After') || '60');
      await new Promise(r => setTimeout(r, retryAfter * 1000));
      continue; // Retry same page
    }
    
    const data = await response.json();
    contacts = contacts.concat(data.contacts || []);
    
    const lastContact = data.contacts?.[data.contacts.length - 1];
    startAfter = lastContact?.id || null;
    
    // Rate limit courtesy: small delay between pages
    await new Promise(r => setTimeout(r, 200));
    
  } while (startAfter);
  
  return contacts;
}
```

## Documentation Links
- **Developer Portal**: https://marketplace.gohighlevel.com/docs/
- **Webhook Guide**: https://marketplace.gohighlevel.com/docs/webhook/WebhookIntegrationGuide/
- **API Changelog**: https://ideas.gohighlevel.com/changelog
- **Support**: https://help.gohighlevel.com/support/solutions/articles/48001060529
