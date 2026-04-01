# JavaScript in n8n Code Nodes

## Data Access

### $input.all() — Get All Items (Most Common)
```javascript
const items = $input.all();
// items = [{ json: { name: "John" } }, { json: { name: "Jane" } }]

// Process all items
return items.map(item => ({
  json: {
    ...item.json,
    processed: true,
    processedAt: new Date().toISOString()
  }
}));
```

### $input.first() — Get First Item
```javascript
const data = $input.first().json;
const email = data.email;
const name = data.body?.contact?.name ?? "Unknown"; // Webhook data is nested under body
```

### $input.item — Each-Item Mode Only
```javascript
// Only works in "Run Once for Each Item" mode
const item = $input.item.json;
return [{ json: { ...item, doubled: item.value * 2 } }];
```

### $node — Reference Other Nodes
```javascript
const previousData = $node["Fetch Contacts"].json;
const webhookHeaders = $node["Webhook"].json.headers;
```

### $env — Environment Variables (⚠️ Blocked by Default in v2.0)
```javascript
// Requires N8N_BLOCK_ENV_ACCESS_IN_NODE=false in n8n v2.0
const apiUrl = $env.API_BASE_URL;
const debug = $env.DEBUG_MODE === 'true';
```

## Return Format

```javascript
// ✅ Single item
return [{ json: { result: "success" } }];

// ✅ Multiple items
return $input.all().map(item => ({ json: { ...item.json, extra: true } }));

// ✅ Filter (return subset)
return $input.all().filter(item => item.json.score > 50);

// ✅ Empty (stops downstream nodes)
return [];

// ❌ WRONG — missing array wrapper
return { json: { result: "fail" } };

// ❌ WRONG — missing json key
return [{ result: "fail" }];
```

## Built-in: $helpers.httpRequest()

> **WARNING (n8n v2.0+ with task runners):** `$helpers.httpRequest()` is **BLOCKED** in the
> isolated task runner sandbox. Use HTTP Request nodes instead for all HTTP calls.
> This section remains for n8n instances running WITHOUT task runners (legacy mode).

Make HTTP requests from within Code nodes:
```javascript
const response = await $helpers.httpRequest({
  method: 'GET',
  url: 'https://api.example.com/users',
  headers: {
    'Authorization': 'Bearer my-token',
    'Content-Type': 'application/json'
  },
  returnFullResponse: false  // true to get statusCode + headers
});

return [{ json: response }];
```

**POST with body:**
```javascript
const response = await $helpers.httpRequest({
  method: 'POST',
  url: 'https://api.example.com/contacts',
  body: JSON.stringify({
    email: $input.first().json.body.email,
    name: $input.first().json.body.name
  }),
  headers: { 'Content-Type': 'application/json' }
});
return [{ json: response }];
```

**With full response (for status code checking):**
```javascript
const response = await $helpers.httpRequest({
  method: 'GET',
  url: 'https://api.example.com/health',
  returnFullResponse: true
});

if (response.statusCode !== 200) {
  throw new Error(`API returned ${response.statusCode}`);
}
return [{ json: JSON.parse(response.body) }];
```

## Built-in: DateTime (Luxon)

n8n exposes Luxon as `DateTime`:
```javascript
// Current time
const now = DateTime.now();
const iso = now.toISO();                          // "2025-03-11T14:30:00.000-05:00"
const formatted = now.toFormat('yyyy-MM-dd');      // "2025-03-11"

// Timezone conversion
const montreal = now.setZone('America/Montreal');

// Arithmetic
const nextWeek = now.plus({ days: 7 });
const lastMonth = now.minus({ months: 1 });

// Parse dates
const parsed = DateTime.fromISO('2025-01-15T10:00:00Z');
const daysSince = now.diff(parsed, 'days').days;

// Relative
const relative = parsed.toRelative(); // "2 months ago"

// Format for display
const display = parsed.toFormat('dd MMM yyyy HH:mm'); // "15 Jan 2025 10:00"
```

## Built-in: $jmespath()

Query JSON with JMESPath syntax:
```javascript
const data = $input.first().json;

// Extract nested array
const emails = $jmespath(data, 'contacts[*].email');

// Filter
const active = $jmespath(data, "contacts[?status=='active']");

// Nested extraction
const cities = $jmespath(data, 'contacts[*].address.city');
```

## Error Handling

```javascript
try {
  const response = await $helpers.httpRequest({
    method: 'GET',
    url: $env.API_URL + '/data'
  });
  return [{ json: response }];
} catch (error) {
  // Return error info instead of crashing
  return [{ json: { 
    error: true, 
    message: error.message,
    timestamp: new Date().toISOString()
  }}];
}
```

## Debugging

```javascript
// console.log outputs to n8n server logs (docker logs / journalctl)
console.log('Input count:', $input.all().length);
console.log('First item:', JSON.stringify($input.first().json, null, 2));

// Return debug info temporarily
return [{ json: { debug: $input.first().json, itemCount: $input.all().length } }];
```
