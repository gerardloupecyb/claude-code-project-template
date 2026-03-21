# Debugging & Troubleshooting

Comprehensive guide to debugging n8n workflows and solving common issues.

## Debugging Techniques

### Execution View Analysis

**Understanding Execution Output**
```
For each node:
1. Click node to see execution details
2. Check Input/Output tabs:
   - Input: Data received from previous node
   - Output: Data sent to next node
3. Look for:
   - Empty arrays (no data passed)
   - Error messages
   - Unexpected data structures
   - Missing fields
```

**Binary Data Inspection**
```
For file operations:
1. Click node
2. Go to Binary tab
3. Check:
   - File size
   - MIME type
   - Base64 preview (for images)
4. Download binary to inspect locally
```

### Console Logging

**Strategic Log Placement**
```javascript
Code Node:
console.log('=== Debug Point 1 ===');
console.log('Input data:', JSON.stringify($input.item, null, 2));
console.log('Specific field:', $json.fieldName);
console.log('Data type:', typeof $json.value);
console.log('Array length:', $json.items?.length);

// Your logic here

console.log('=== Debug Point 2 ===');
console.log('Output data:', JSON.stringify(result, null, 2));

return result;
```

**Conditional Logging**
```javascript
const DEBUG = $env.DEBUG === 'true';

if (DEBUG) {
  console.log('Debug info:', {
    execution_id: $execution.id,
    node: $node.name,
    data: $json
  });
}
```

### Breakpoint Simulation

**Pause Workflow Execution**
```
Using Manual Trigger:
1. Disable auto-execution after each node
2. Execute one node at a time
3. Inspect data between nodes
4. Adjust logic as needed

Pattern:
Node 1 → [Check output] → Node 2 → [Check output] → Node 3
```

### Data Snapshots

**Capture State at Key Points**
```
Insert Set nodes to capture data:

Before transformation:
Set Node "Snapshot: Before":
- original_data: {{ $json }}
- timestamp: {{ $now.toISO() }}

After transformation:
Set Node "Snapshot: After":
- transformed_data: {{ $json }}
- previous_snapshot: {{ $('Snapshot: Before').item.json }}
- changes_made: true

Compare snapshots to identify transformation issues
```

## Common Issues & Solutions

### Issue 1: No Data Passing Between Nodes

**Symptoms:**
- Next node receives empty array
- Execution shows 0 items

**Causes & Solutions:**

**1. Filter Removed All Items**
```
Check IF node conditions:
- Verify logic (=== vs ==, null vs undefined)
- Check for typos in field names
- Test with sample data

Debug:
Add Set node after IF to see which path executes
```

**2. Array Not Properly Mapped**
```
❌ Wrong:
{{ $json.items }}  // Returns array reference, not items

✅ Correct:
Use "Loop Over Items" or "Split In Batches"
```

**3. Expression Returns Undefined**
```javascript
Code Node:
console.log('Field value:', $json.fieldName);
console.log('Is undefined?', $json.fieldName === undefined);
console.log('Available fields:', Object.keys($json));

// Check for null, undefined, empty
return {
  safeValue: $json.fieldName ?? 'default'
};
```

### Issue 2: Incorrect Data Types

**Symptoms:**
- Comparison fails unexpectedly
- Math operations return NaN
- Database errors

**Solutions:**

**String to Number**
```javascript
// Problem: API returns "123" as string
const value = $json.stringNumber;
console.log('Type:', typeof value); // "string"

// Solutions:
const asNumber = Number(value);
const asInt = parseInt(value, 10);
const asFloat = parseFloat(value);

// With validation:
function toNumber(val) {
  const num = Number(val);
  if (isNaN(num)) {
    throw new Error(`Cannot convert "${val}" to number`);
  }
  return num;
}
```

**Type Validation**
```javascript
function validateTypes(data) {
  const issues = [];
  
  if (typeof data.age !== 'number') {
    issues.push(`age should be number, got ${typeof data.age}`);
  }
  
  if (!Array.isArray(data.items)) {
    issues.push(`items should be array, got ${typeof data.items}`);
  }
  
  if (typeof data.active !== 'boolean') {
    issues.push(`active should be boolean, got ${typeof data.active}`);
  }
  
  if (issues.length > 0) {
    console.error('Type validation failed:', issues);
    throw new Error(issues.join('; '));
  }
  
  return data;
}

return validateTypes($json);
```

### Issue 3: Expression Syntax Errors

**Common Mistakes:**

**1. Missing Curly Braces**
```
❌ Wrong: {{ $json.name }
✅ Correct: {{ $json.name }}
```

**2. Wrong Bracket Type**
```
❌ Wrong: {{ $json.items(0) }}
✅ Correct: {{ $json.items[0] }}
```

**3. Unescaped Quotes**
```
❌ Wrong: {{ "User's name: " + $json.name }}
✅ Correct: {{ 'User\'s name: ' + $json.name }}
✅ Better: {{ `User's name: ${$json.name}` }}
```

**4. Accessing Non-Existent Data**
```
❌ Wrong: {{ $json.user.address.city }}
   // Fails if user or address is undefined

✅ Correct: {{ $json.user?.address?.city ?? 'Unknown' }}
```

### Issue 4: Webhook Not Triggering

**Troubleshooting Steps:**

**1. Verify Webhook URL**
```
Check:
- Workflow is active (toggle in top-right)
- Webhook path is unique
- Full URL is correct: https://your-n8n.com/webhook/your-path

Test:
curl -X POST https://your-n8n.com/webhook/your-path \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

**2. Check Authentication**
```
Webhook node settings:
- Authentication method configured
- Credentials match what sender is using

Test without auth first:
- Temporarily set Authentication: None
- Confirm webhook receives data
- Re-enable authentication
- Debug auth headers
```

**3. Inspect Headers**
```javascript
Code Node (after Webhook):
console.log('=== Webhook Received ===');
console.log('Headers:', JSON.stringify($input.item.headers, null, 2));
console.log('Body:', JSON.stringify($input.item.body, null, 2));
console.log('Query:', JSON.stringify($input.item.query, null, 2));
console.log('Method:', $input.item.method);

return $input.item;
```

**4. Response Mode Issues**
```
If webhook hangs:
- Change Response Mode to "Immediately"
- Move long-running tasks after webhook response
- Use sub-workflows for async processing
```

### Issue 5: Database Errors

**Connection Issues**
```
Symptoms: "Connection timeout", "Connection refused"

Check:
1. Credentials are correct
2. Database is accessible from n8n server
3. Firewall rules allow connection
4. Connection string format

Test:
psql -h hostname -U username -d database -p port
```

**Query Errors**
```
Symptoms: "Syntax error", "Column doesn't exist"

Debug:
1. Log the exact query being executed:
Code Node:
console.log('Query:', $json.query);
console.log('Parameters:', $json.params);

2. Test query in database client
3. Check for:
   - Reserved keywords (wrap in quotes)
   - Case sensitivity
   - Missing parameters
   - SQL injection (use parameterized queries)
```

**Data Type Mismatches**
```
Error: "Invalid input value for column type"

Solution:
// Ensure correct types before insert
const prepared = {
  id: parseInt($json.id),
  amount: parseFloat($json.amount),
  active: Boolean($json.active),
  created_at: new Date($json.date).toISOString()
};

return prepared;
```

### Issue 6: API Request Failures

**HTTP Errors**

**400 Bad Request**
```
Causes:
- Invalid request body format
- Missing required fields
- Invalid field values

Debug:
1. Log request body:
console.log('Request:', JSON.stringify($json, null, 2));

2. Check API documentation for required format
3. Validate against API schema
4. Test with curl/Postman first
```

**401 Unauthorized**
```
Causes:
- Invalid API key
- Expired token
- Wrong authentication method

Debug:
1. Verify credentials
2. Check authentication header:
console.log('Auth header:', $input.item.headers.authorization);

3. Test credentials outside n8n
4. Check token expiration
```

**429 Too Many Requests**
```
Causes:
- Hitting rate limits

Solutions:
1. Add delays between requests
2. Implement exponential backoff
3. Use batch endpoints if available
4. Cache responses

Error Trigger:
IF {{ $json.statusCode === 429 }}
  Wait: 60000ms
  Retry original request
```

**500/502/503 Server Errors**
```
Causes:
- API server issues
- Timeout
- Overload

Solutions:
1. Retry with exponential backoff
2. Use fallback API endpoint
3. Notify ops team
4. Return cached data temporarily
```

### Issue 7: Timeout Errors

**HTTP Request Timeout**
```
Error: "Request timed out"

Solutions:
1. Increase timeout in HTTP Request node:
   - Options > Timeout: 30000 (30 seconds)

2. For long-running requests:
   - Use async pattern
   - Poll for result
   - Implement webhook callback

3. Check API performance
```

**Workflow Execution Timeout**
```
Error: "Workflow execution timeout"

Solutions:
1. Optimize workflow:
   - Reduce data processing
   - Use pagination
   - Batch operations

2. Split into sub-workflows
3. Use queue pattern for large jobs
```

## Testing Strategies

### Unit Testing Nodes

**Test Individual Transformations**
```
Pattern:
1. Create test workflow: "Test: Data Transform"
2. Manual trigger with sample data
3. Execute transformation node
4. Verify output matches expected

Sample Test Data:
{
  "input": {
    "name": "John Doe",
    "email": "john@example.com",
    "age": "30"
  },
  "expected": {
    "full_name": "John Doe",
    "email_lower": "john@example.com",
    "age_number": 30
  }
}
```

### Integration Testing

**Test Complete Workflows**
```
Test Checklist:
1. Happy path (valid data)
2. Missing fields
3. Invalid data types
4. Empty arrays
5. Large datasets
6. Duplicate data
7. Concurrent requests (for webhooks)
8. Error scenarios

Automate:
Create "Test Runner" workflow:
- Loop through test cases
- Execute workflow with each
- Compare results
- Report failures
```

### Load Testing

**Test Performance Under Load**
```
Pattern:
1. Create load test workflow
2. Generate multiple requests:
   - Loop 100 times
   - Wait 100ms between requests
   - Send to webhook/API

3. Monitor:
   - Execution time
   - Success rate
   - Error patterns
   - Resource usage

Scheduled Test (weekly):
- Ensures workflow scales
- Catches performance regressions
```

## Debugging Tools

### Custom Debug Node

**Reusable Debug Node**
```javascript
Code Node: "Debug Inspector"

const item = $input.item;

const debug = {
  execution_id: $execution.id,
  workflow: $workflow.name,
  node: $node.name,
  timestamp: new Date().toISOString(),
  
  data_summary: {
    keys: Object.keys(item.json || {}),
    item_count: $input.all().length,
    has_binary: Boolean(item.binary),
    data_type: typeof item.json
  },
  
  full_data: item.json,
  
  environment: {
    debug_mode: $env.DEBUG,
    environment: $env.NODE_ENV
  }
};

console.log(JSON.stringify(debug, null, 2));

// Also log to database for persistence
// INSERT INTO debug_logs ...

return { ...item.json, _debug: debug };
```

### Request/Response Logger

**Log All HTTP Requests**
```javascript
// Before HTTP Request node:
Code Node: "Log Request"

const request = {
  url: $json.url,
  method: $json.method || 'GET',
  headers: $json.headers,
  body: $json.body,
  timestamp: new Date().toISOString()
};

console.log('=== HTTP REQUEST ===');
console.log(JSON.stringify(request, null, 2));

// Store in database
await $pgClient.query(
  'INSERT INTO http_logs (direction, data) VALUES ($1, $2)',
  ['request', request]
);

return $json;

// After HTTP Request node:
Code Node: "Log Response"

const response = {
  status: $json.statusCode,
  headers: $json.headers,
  body: $json.body,
  duration_ms: Date.now() - requestStartTime,
  timestamp: new Date().toISOString()
};

console.log('=== HTTP RESPONSE ===');
console.log(JSON.stringify(response, null, 2));

// Store in database
await $pgClient.query(
  'INSERT INTO http_logs (direction, data) VALUES ($1, $2)',
  ['response', response]
);

return $json;
```

### Data Diff Tool

**Compare Before/After**
```javascript
Code Node: "Data Diff"

const before = $('Before Transform').item.json;
const after = $json;

function diff(obj1, obj2) {
  const changes = {};
  
  const allKeys = new Set([...Object.keys(obj1), ...Object.keys(obj2)]);
  
  for (const key of allKeys) {
    if (obj1[key] !== obj2[key]) {
      changes[key] = {
        before: obj1[key],
        after: obj2[key]
      };
    }
  }
  
  return changes;
}

const differences = diff(before, after);

console.log('=== DATA CHANGES ===');
console.log(JSON.stringify(differences, null, 2));

return { ...after, _diff: differences };
```

## Error Pattern Recognition

### Common Error Patterns

**Pattern 1: Null Reference**
```
Error: "Cannot read property 'x' of undefined"

Location: {{ $json.user.address.city }}

Cause: $json.user or $json.user.address is undefined

Fix: {{ $json.user?.address?.city ?? 'Unknown' }}
```

**Pattern 2: Type Coercion**
```
Error: "NaN" in calculations

Location: {{ $json.quantity * $json.price }}

Cause: quantity or price is string

Fix:
{{ Number($json.quantity) * Number($json.price) }}
```

**Pattern 3: Array Operations on Non-Array**
```
Error: "map is not a function"

Location: {{ $json.items.map(...) }}

Cause: items is not an array

Fix:
{{ Array.isArray($json.items) ? $json.items.map(...) : [] }}
```

## Production Debugging

### Remote Debugging

**Debug Production Issues Without Logs**
```
Pattern:
1. Capture problematic execution ID
2. Export execution data
3. Replay in test environment
4. Add debug nodes
5. Identify issue
6. Deploy fix

Export Execution:
Settings > Executions > Find execution > Export
```

### Debug Mode Toggle

**Enable Debug Features Conditionally**
```javascript
const DEBUG = $env.DEBUG_MODE === 'true';

if (DEBUG) {
  // Detailed logging
  console.log('Full input:', JSON.stringify($input.all(), null, 2));
  
  // Save debug snapshot
  await saveDebugSnapshot($execution.id, $input.all());
  
  // Slow down execution
  await sleep(1000);
}

// Regular logic
return processData($input.item);
```

### Health Check Workflow

**Monitor Workflow Health**
```
Scheduled (every 5 min):
1. Test critical workflows
2. Check execution success rate
3. Measure response times
4. Alert on anomalies

Health Check:
{
  "workflow": "Payment Processing",
  "status": "healthy",
  "last_execution": "2024-01-15T10:30:00Z",
  "success_rate_24h": 99.8,
  "avg_duration_ms": 1500,
  "errors_last_hour": 0
}
```
