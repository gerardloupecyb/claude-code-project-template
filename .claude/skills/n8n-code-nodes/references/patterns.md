# Shared Code Patterns (JavaScript & Python)

> **Scope**: Code node syntax — patterns for JavaScript and Python inside n8n Code nodes. For workflow-level data transformation patterns (using Set, IF, Merge, etc.), see **n8n-workflow-architect** → `references/data-transform-debug.md`.

Side-by-side patterns for common tasks in both languages.

## Data Transformation

### Rename and Map Fields
```javascript
// JavaScript
return $input.all().map(item => ({
  json: {
    fullName: `${item.json.firstName} ${item.json.lastName}`,
    email: item.json.email.toLowerCase().trim(),
    source: 'api-import'
  }
}));
```
```python
# Python
return [{"json": {
    "fullName": f"{item['json'].get('firstName', '')} {item['json'].get('lastName', '')}".strip(),
    "email": item["json"].get("email", "").lower().strip(),
    "source": "api-import"
}} for item in _items]
```

### Flatten Nested Objects
```javascript
// JavaScript
const c = $input.first().json;
return [{ json: {
  name: c.name,
  city: c.address?.city,
  company: c.company?.name
}}];
```
```python
# Python
c = _items[0]["json"]
return [{"json": {
    "name": c.get("name"),
    "city": c.get("address", {}).get("city"),
    "company": c.get("company", {}).get("name")
}}]
```

## Filtering

### By Condition
```javascript
// JavaScript
return $input.all().filter(i => i.json.status === 'active' && i.json.score > 50);
```
```python
# Python
return [i for i in _items if i["json"].get("status") == "active" and i["json"].get("score", 0) > 50]
```

## Sorting

```javascript
// JavaScript (descending by score)
return [...$input.all()].sort((a, b) => (b.json.score || 0) - (a.json.score || 0));
```
```python
# Python
return sorted(_items, key=lambda i: i["json"].get("score", 0), reverse=True)
```

## Aggregation

### Sum, Count, Average
```javascript
// JavaScript
const items = $input.all();
const total = items.reduce((s, i) => s + (i.json.amount || 0), 0);
return [{ json: { total, count: items.length, avg: +(total / items.length).toFixed(2) } }];
```
```python
# Python
total = sum(i["json"].get("amount", 0) for i in _items)
count = len(_items)
return [{"json": {"total": total, "count": count, "avg": round(total / count, 2) if count else 0}}]
```

### Group By
```javascript
// JavaScript
const groups = {};
for (const item of $input.all()) {
  const key = item.json.status || 'unknown';
  if (!groups[key]) groups[key] = [];
  groups[key].push(item.json);
}
return Object.entries(groups).map(([status, items]) => ({
  json: { status, count: items.length, items }
}));
```
```python
# Python
from collections import defaultdict
groups = defaultdict(list)
for item in _items:
    groups[item["json"].get("status", "unknown")].append(item["json"])
return [{"json": {"status": k, "count": len(v), "items": v}} for k, v in groups.items()]
```

## Deduplication

```javascript
// JavaScript
const seen = new Set();
return $input.all().filter(i => {
  const k = i.json.email?.toLowerCase();
  if (!k || seen.has(k)) return false;
  seen.add(k); return true;
});
```
```python
# Python
seen = set()
unique = []
for item in _items:
    k = item["json"].get("email", "").lower()
    if k and k not in seen:
        seen.add(k)
        unique.append(item)
return unique
```

## String Processing

### Phone Normalization
```javascript
// JavaScript
function normalizePhone(phone) {
  const digits = phone.replace(/\D/g, '');
  if (digits.length === 10) return `+1${digits}`;
  if (digits.length === 11 && digits.startsWith('1')) return `+${digits}`;
  return `+${digits}`;
}
```
```python
# Python
import re
def normalize_phone(phone):
    digits = re.sub(r'\D', '', phone)
    if len(digits) == 10: return f"+1{digits}"
    if len(digits) == 11 and digits.startswith("1"): return f"+{digits}"
    return f"+{digits}"
```

### Slugify
```javascript
// JavaScript
const slug = name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
```
```python
# Python
import re
slug = re.sub(r'^-|-$', '', re.sub(r'[^a-z0-9]+', '-', name.lower()))
```

## Date Operations

```javascript
// JavaScript (Luxon DateTime)
const now = DateTime.now();
const yesterday = now.minus({ days: 1 });
const formatted = now.toFormat('yyyy-MM-dd');
const parsed = DateTime.fromISO('2025-01-15');
const daysSince = now.diff(parsed, 'days').days;
const montreal = now.setZone('America/Montreal');
```
```python
# Python (datetime)
from datetime import datetime, timedelta
now = datetime.now()
yesterday = now - timedelta(days=1)
formatted = now.strftime("%Y-%m-%d")
parsed = datetime.fromisoformat("2025-01-15")
days_since = (now - parsed).days
# Timezone: use zoneinfo (Python 3.9+) if available in task runner
```

## HTTP Requests (JavaScript Only)

Python cannot make HTTP requests from Code nodes — use the HTTP Request node instead.

```javascript
// JavaScript: GET with auth
const data = await $helpers.httpRequest({
  method: 'GET',
  url: 'https://api.example.com/contacts',
  headers: { 'Authorization': `Bearer ${token}` }
});
return [{ json: data }];

// JavaScript: POST with JSON body
const result = await $helpers.httpRequest({
  method: 'POST',
  url: 'https://api.example.com/contacts',
  body: JSON.stringify({ email, name }),
  headers: { 'Content-Type': 'application/json' }
});
return [{ json: result }];

// JavaScript: With retry
const MAX_RETRIES = 3;
for (let i = 0; i < MAX_RETRIES; i++) {
  try {
    const r = await $helpers.httpRequest({ method: 'GET', url, returnFullResponse: true });
    if (r.statusCode === 200) return [{ json: JSON.parse(r.body) }];
    if (r.statusCode === 429) {
      await new Promise(r => setTimeout(r, Math.pow(2, i) * 1000));
      continue;
    }
    throw new Error(`API ${r.statusCode}`);
  } catch (e) { if (i === MAX_RETRIES - 1) throw e; }
}
```

## Error Handling

```javascript
// JavaScript
try {
  const result = processData($input.first().json);
  return [{ json: { status: 'success', data: result } }];
} catch (error) {
  return [{ json: { error: true, message: error.message } }];
}
```
```python
# Python
try:
    result = process_data(_items[0]["json"])
    return [{"json": {"status": "success", "data": result}}]
except Exception as e:
    return [{"json": {"error": True, "message": str(e)}}]
```

## Webhook Body Processing

> **Cross-reference**: Webhook data structure (`.body` nesting) is documented in the **n8n-node-expert** skill, which is the canonical reference for webhook data access patterns across expressions, JavaScript, and Python. See that skill for complete examples.
