# Expression Deep Reference

Extended reference for n8n expressions — content folded from the former `n8n-expression-syntax` skill.

## Additional Built-in Variables

### $vars — n8n Variables (read-only)
```javascript
{{$vars.MY_VARIABLE}}
```
```python
_vars.MY_VARIABLE
```
n8n Variables are different from environment variables (`$env`). They are configured in the n8n UI (Settings → Variables), read-only, and available in all workflows. Requires appropriate plan and permissions.

### $tool — AI Agent Tool Context (n8n v2.0+)
```javascript
{{$tool.name}}            // Name of the current tool being called by the agent
{{$tool.parameters}}      // Parameters the AI agent passed to this tool
```
Available only on nodes connected to an AI Agent via the `ai_tool` port. For Python Code nodes used as AI tools, use `_query` instead (see `n8n-code-nodes` skill).

### Other Built-ins
```javascript
{{$execution.id}}              // Current execution ID
{{$workflow.id}}               // Current workflow ID
{{$workflow.name}}             // Current workflow name
{{$execution.resumeUrl}}       // Resume URL (for Wait nodes)
```

## Where NOT to Use Expressions

| Context | Why Not | Use Instead |
|---------|---------|-------------|
| Code nodes | Different syntax | `$json.field` (JS) or `_items[0]["json"]["field"]` (Python) |
| Webhook paths | Must be static | Hardcoded string: `"my-webhook-path"` |
| Credential fields | Security risk | n8n credential system |

## Data Type Helpers

### Strings
```javascript
{{$json.email.toLowerCase()}}          // Lowercase
{{$json.name.toUpperCase()}}           // Uppercase
{{$json.text.trim()}}                  // Remove whitespace
{{$json.text.replace('old', 'new')}}   // Replace
{{$json.text.includes('word')}}        // Boolean check
```

### Numbers
```javascript
{{$json.price * 1.1}}                  // Math: add 10%
{{$json.price.toFixed(2)}}             // Format: "29.99"
```

### Arrays
```javascript
{{$json.items[0].name}}                // First item
{{$json.items.length}}                 // Count
{{$json.tags.join(', ')}}              // Join: "a, b, c"
```

### Conditionals
```javascript
{{$json.status === 'active' ? 'Yes' : 'No'}}          // Ternary
{{$json.email || 'no-email@example.com'}}              // Default value
{{$json.name ?? 'Unknown'}}                            // Nullish coalescing
```

### Dates (Luxon)
```javascript
{{$now.plus({days: 7}).toFormat('yyyy-MM-dd')}}        // Future date
{{DateTime.fromISO($json.date).toFormat('dd MMM yyyy')}} // Parse + format
{{DateTime.fromISO($json.date).toRelative()}}          // "3 days ago"
```

## Debugging Expressions

1. Click the field → open expression editor (fx icon)
2. See live preview of the evaluated result
3. Red highlighting = syntax error

**Common error messages:**
- "Cannot read property 'X' of undefined" → parent object doesn't exist (check data path)
- "X is not a function" → calling method on wrong type
- Expression shows as literal text → missing `{{ }}`
