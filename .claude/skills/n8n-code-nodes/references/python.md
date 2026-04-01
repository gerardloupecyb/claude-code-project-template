# Python in n8n Code Nodes (n8n v2.0 — Native Python)

## ⚠️ Critical: Native Python vs Pyodide

n8n v2.0 **removed Pyodide** and replaced it with **native Python running on task runners**. Key differences:

| Feature | Pyodide (v1.x, removed) | Native Python (v2.0+) |
|---------|-------------------------|----------------------|
| Notation | Dot + bracket: `item.json.name` | **Bracket only**: `item["json"]["name"]` |
| Built-in variables | `_input`, `_json`, `_node`, etc. | **Only `_items` and `_item`** |
| External libraries | Pyodide packages only | Any pip package IF allowlisted in task runner |
| Standard library | Limited WebAssembly subset | Full CPython standard library |
| AI tool input | N/A | `_query` (string from agent) |
| Performance | Slower (WebAssembly overhead) | Faster (native execution) |

## Data Access

### _items — All Items (All-Items Mode, Default)
```python
# _items is a list of dicts with "json" key
items = _items
# items = [{"json": {"name": "John"}}, {"json": {"name": "Jane"}}]

# Access first item
email = _items[0]["json"]["email"]

# Access nested (webhook data under body)
contact_name = _items[0]["json"]["body"]["contact"]["name"]

# Safe access with .get()
city = _items[0]["json"].get("address", {}).get("city", "Unknown")
```

### _item — Current Item (Each-Item Mode)
```python
# Only in "Run Once for Each Item" mode
data = _item["json"]
name = data.get("name", "Unknown")
return [{"json": {**data, "processed": True}}]
```

### _query — AI Agent Tool Input
```python
# In Python tools connected to AI Agent via ai_tool port
search_term = _query  # String the agent sends to this tool
# Use search_term to query database, API, etc.
```

## Return Format

```python
# ✅ Single item
return [{"json": {"result": "success"}}]

# ✅ Multiple items (transformation)
return [{"json": {**item["json"], "extra": True}} for item in _items]

# ✅ Filter
return [item for item in _items if item["json"].get("score", 0) > 50]

# ✅ Empty (stops downstream)
return []

# ❌ WRONG — missing list wrapper
return {"json": {"result": "fail"}}

# ❌ WRONG — missing "json" key
return [{"result": "fail"}]

# ❌ WRONG — dot notation (Pyodide syntax, broken in v2)
return [{"json": {"name": item.json.name}} for item in _items]

# ✅ CORRECT — bracket notation
return [{"json": {"name": item["json"]["name"]}} for item in _items]
```

## What's Available (Standard Library)

These are always available — no import restrictions:
```python
import json          # JSON parsing/serializing
import re            # Regular expressions
import datetime      # Date/time handling
import math          # Math operations
import statistics    # Statistical functions
import collections   # Counter, defaultdict, OrderedDict
import hashlib       # Hashing (SHA256, MD5, etc.)
import base64        # Base64 encoding/decoding
import urllib.parse  # URL encoding/parsing
import uuid          # Generate UUIDs
import csv           # CSV parsing (with io.StringIO)
import io            # StringIO, BytesIO
import itertools     # Iteration tools
import functools     # reduce, partial, lru_cache
import copy          # Deep copy
import string        # String constants
import textwrap      # Text wrapping
```

## What's NOT Available (by default)

```python
# ❌ External libraries — NOT available unless allowlisted in task runner config
import pandas        # ModuleNotFoundError
import requests      # ModuleNotFoundError
import numpy         # ModuleNotFoundError
import beautifulsoup4  # ModuleNotFoundError

# ❌ n8n built-in variables (NOT available in native Python)
_input.first()       # NameError — use _items[0] instead
_json.email          # NameError — use _items[0]["json"]["email"]
_node["Name"]        # NameError — not available
```

### Enabling External Libraries
If you need external libraries, configure your task runner:
1. Extend the `n8nio/runners` Docker image to include the package
2. Allowlist the package in `n8n-task-runners.json`
3. Restart the task runner container

Environment variables: `N8N_RUNNERS_STDLIB_ALLOW`, `NODE_FUNCTION_ALLOW_EXTERNAL`

## Common Patterns

### Data Transformation
```python
return [{
    "json": {
        "fullName": f"{item['json'].get('firstName', '')} {item['json'].get('lastName', '')}".strip(),
        "email": item["json"].get("email", "").lower().strip(),
        "score": item["json"].get("interactions", 0) * 5,
        "importedAt": datetime.datetime.now().isoformat()
    }
} for item in _items]
```

### Filtering
```python
return [item for item in _items 
        if item["json"].get("status") == "active" 
        and item["json"].get("score", 0) > 50]
```

### Grouping
```python
from collections import defaultdict
groups = defaultdict(list)
for item in _items:
    key = item["json"].get("status", "unknown")
    groups[key].append(item["json"])

return [{"json": {"status": k, "count": len(v), "items": v}} for k, v in groups.items()]
```

### Deduplication
```python
seen = set()
unique = []
for item in _items:
    key = item["json"].get("email", "").lower()
    if key and key not in seen:
        seen.add(key)
        unique.append(item)
return unique
```

### Hashing / HMAC
```python
import hashlib, hmac
payload = json.dumps(_items[0]["json"]["body"])
secret = "shared-secret"  # Ideally from env, but $env not available in Python
signature = hmac.new(secret.encode(), payload.encode(), hashlib.sha256).hexdigest()
return [{"json": {"signature": signature, "payload": payload}}]
```

### Date Operations
```python
from datetime import datetime, timedelta
now = datetime.now()
yesterday = now - timedelta(days=1)
formatted = now.strftime("%Y-%m-%d %H:%M:%S")  # "2025-03-11 14:30:00"
parsed = datetime.fromisoformat("2025-01-15T10:00:00")
days_since = (now - parsed).days
return [{"json": {"now": formatted, "daysSince": days_since}}]
```

### CSV Parsing
```python
import csv, io
csv_text = _items[0]["json"]["body"]
reader = csv.DictReader(io.StringIO(csv_text))
return [{"json": dict(row)} for row in reader]
```

## Error Handling

```python
try:
    data = _items[0]["json"]
    result = process(data)
    return [{"json": {"status": "success", "data": result}}]
except KeyError as e:
    return [{"json": {"error": True, "message": f"Missing key: {e}"}}]
except Exception as e:
    return [{"json": {"error": True, "message": str(e)}}]
```

## Debugging

```python
# print() outputs to n8n server logs
print(f"Item count: {len(_items)}")
print(f"First item: {json.dumps(_items[0]['json'], indent=2)}")

# Return debug data temporarily
return [{"json": {"debug": _items[0]["json"], "count": len(_items)}}]
```

## Python vs JavaScript Decision

| Need | Use |
|------|-----|
| HTTP requests in Code node | **JavaScript** ($helpers.httpRequest) |
| Date manipulation with timezones | **JavaScript** (DateTime/Luxon) |
| Access $node, $execution, $workflow | **JavaScript** (not available in Python) |
| Complex regex processing | **Python** (re module more readable) |
| Statistical analysis | **Python** (statistics module) |
| List comprehensions for data transform | **Python** (more concise) |
| Maximum performance | **JavaScript** (faster in n8n) |
| AI tool with simple logic | **Python** (_query available) |
