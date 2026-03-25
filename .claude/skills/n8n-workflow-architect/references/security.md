# Security Best Practices

Comprehensive security guidance for n8n workflows handling sensitive data.

## Field-Tested Gotchas

### SSH Credentials — RSA PEM Only
n8n (lib ssh2) only supports RSA PEM traditional format. No OpenSSH, no ed25519, no PKCS#8.
```bash
# Generate RSA key in the ONLY format n8n accepts:
openssl genrsa 4096 > key.pem
openssl rsa -in key.pem -out key-trad.pem -traditional
# Result: -----BEGIN RSA PRIVATE KEY----- (this is the only header n8n accepts)
```

### SSH Host in Docker — Use IP, Not Hostname
When n8n runs in Docker and connects to the host via SSH:
- Use the **public IP**, NOT the hostname
- Hostnames may resolve to loopback (`127.0.1.1`) inside Docker containers
- The SSH node will connect to itself instead of the host

### httpHeaderAuth Credential Pattern
HTTP Request nodes using httpHeaderAuth credentials MUST set:
```json
{
  "authentication": "genericCredentialType",
  "genericAuthType": "httpHeaderAuth"
}
```
Do NOT use `authentication: "none"` with manual `$credentials` expressions in headers — this returns 401.

### Inline HTTP > Execute Sub-Workflow for Reliability
Prefer inlining HTTP Request nodes (KV token -> KV secret -> API call) over Execute Workflow sub-workflows.
Sub-workflows have cache/versioning issues where the published version doesn't match the draft.
Inline via HTTP Request nodes is more reliable for Key Vault and API integrations.

### OAuth2 client_credentials — Inline Token Fetch
n8n's `microsoftOAuth2Api` credential type is authorization code flow (requires refreshToken).
For `client_credentials` grant (service principal auth), use an inline HTTP Request node:
```
POST https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token
Body: client_id=...&client_secret=...&scope=...&grant_type=client_credentials
```

## Credential Management

### n8n Credential Store

**Never Hardcode Credentials**
```
❌ WRONG:
HTTP Request:
Header: Authorization: Bearer sk_live_abc123xyz

✅ CORRECT:
HTTP Request:
Authentication: Generic Credential Type
Credentials: {{ $credentials.stripeApiKey }}
```

**Credential Scoping**
```
Best Practices:
- Create separate credentials for prod/staging/dev
- Use environment-specific naming: "Stripe_Production", "Stripe_Staging"
- Rotate credentials regularly (30-90 days)
- Limit credential access to specific workflows
```

### Environment Variables

**Sensitive Configuration**
```
Store in n8n environment variables:
- Database connection strings
- API keys
- Encryption keys
- OAuth secrets

Access in workflows:
{{ $env.DB_CONNECTION_STRING }}
{{ $env.ENCRYPTION_KEY }}
```

### Secrets Rotation

**Automated Rotation Process**
```
Scheduled Workflow (monthly):
1. Generate new API key via provider API
2. Update n8n credential store
3. Verify new credential works
4. Revoke old credential
5. Send notification to team
```

## Authentication & Authorization

### Webhook Security

**1. API Key Authentication**
```
Webhook Trigger:
- Authentication: Header Auth
  Name: X-API-Key
  Value: {{ $credentials.webhookApiKey }}
  
Validation in Code Node:
const providedKey = $input.item.headers['x-api-key'];
const validKey = $credentials.webhookApiKey;

if (providedKey !== validKey) {
  throw new Error('Unauthorized');
}
```

**2. HMAC Signature Verification**

> **WARNING (n8n v2.0+ with task runners):** `require('crypto')` is **BLOCKED** in the
> Code node sandbox. The pattern below will NOT work. Instead, use one of these approaches:
>
> **Recommended: n8n native webhook Header Auth credential**
> Create an n8n credential of type "Header Auth" with your HMAC secret,
> and configure the Webhook node to use it. n8n verifies the signature natively.
>
> **Alternative: Pre-webhook HTTP Request node**
> Use an HTTP Request node to call an external HMAC verification endpoint
> before processing the webhook payload.

```
LEGACY ONLY (without task runners):
Code Node:
const crypto = require('crypto');

const signature = $input.item.headers['x-hub-signature-256'];
const payload = JSON.stringify($input.item.body);
const secret = $credentials.webhookSecret;

const expectedSignature = 'sha256=' + crypto
  .createHmac('sha256', secret)
  .update(payload)
  .digest('hex');

if (signature !== expectedSignature) {
  throw new Error('Invalid signature');
}
```

**3. JWT Token Validation**
```
Code Node:
const jwt = require('jsonwebtoken');

const token = $input.item.headers.authorization?.replace('Bearer ', '');
const secret = $credentials.jwtSecret;

try {
  const decoded = jwt.verify(token, secret);
  
  // Check expiration
  if (decoded.exp < Date.now() / 1000) {
    throw new Error('Token expired');
  }
  
  // Check user permissions
  if (!decoded.permissions.includes('webhook:write')) {
    throw new Error('Insufficient permissions');
  }
  
  return { ...$input.item, user: decoded };
} catch (error) {
  throw new Error('Unauthorized: ' + error.message);
}
```

**4. OAuth 2.0 Flow**
```
For user-facing webhooks:
1. User clicks "Connect"
2. Redirect to OAuth provider
3. Provider redirects back with code
4. Exchange code for access token
5. Store token in database with user ID
6. Use token for subsequent API calls
```

### IP Allowlisting

**Restrict Webhook Access**
```
Code Node:
const allowedIPs = [
  '192.168.1.0/24',
  '10.0.0.0/8'
];

const clientIP = $input.item.headers['x-forwarded-for'] || 
                 $input.item.ip;

function isIPAllowed(ip, allowedRanges) {
  // IP range checking logic
  // Use ipaddr.js library
}

if (!isIPAllowed(clientIP, allowedIPs)) {
  throw new Error('IP not allowed');
}
```

### Rate Limiting

**Prevent Abuse**
```
Using Redis or Database:
1. Get request count for IP/API key
2. IF: count > limit (e.g., 100 requests/hour)
   - Return 429 Too Many Requests
3. ELSE:
   - Increment counter
   - Set expiration (1 hour)
   - Process request

Database Schema:
CREATE TABLE rate_limits (
  key VARCHAR(255) PRIMARY KEY,
  count INT,
  reset_at TIMESTAMP
);
```

**Sliding Window Implementation**
```
Code Node:
const redis = require('redis');
const key = `ratelimit:${$json.apiKey}:${Date.now()}`;
const limit = 100;
const window = 3600; // 1 hour in seconds

const count = await redis.incr(key);
if (count === 1) {
  await redis.expire(key, window);
}

if (count > limit) {
  throw new Error('Rate limit exceeded');
}
```

## Input Validation & Sanitization

### SQL Injection Prevention

**Always Use Parameterized Queries**
```
❌ WRONG:
Postgres Node:
Query: SELECT * FROM users WHERE email = '{{ $json.email }}'

✅ CORRECT:
Postgres Node:
Query: SELECT * FROM users WHERE email = $1
Parameters:
  $1: {{ $json.email }}
```

### XSS Prevention

**Sanitize User Input**
```
Code Node:
function escapeHtml(text) {
  const map = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#039;',
    '/': '&#x2F;'
  };
  return text.replace(/[&<>"'/]/g, (char) => map[char]);
}

return {
  name: escapeHtml($json.name),
  comment: escapeHtml($json.comment)
};
```

### Command Injection Prevention

**Validate Shell Commands**
```
❌ WRONG:
Execute Command Node:
Command: ls {{ $json.filename }}

✅ CORRECT:
Code Node:
const path = require('path');
const { execSync } = require('child_process');

// Validate input
const allowedChars = /^[a-zA-Z0-9._-]+$/;
if (!allowedChars.test($json.filename)) {
  throw new Error('Invalid filename');
}

// Use safe path joining
const safePath = path.join('/safe/directory', $json.filename);
const result = execSync(`ls ${safePath}`);
```

### File Upload Validation

**Secure File Processing**
```
After file upload:
1. Validate file type:
   - Check MIME type
   - Verify file extension
   - Inspect file header (magic bytes)

2. Scan for malware (if available)

3. Size limits:
   - Max 10MB per file
   - Max 100MB per request

4. Rename file:
   - Use UUID instead of user-provided name
   - Store in isolated directory

Code Node:
const crypto = require('crypto');
const path = require('path');

// Generate safe filename
const ext = path.extname($json.originalName);
const allowedExts = ['.pdf', '.jpg', '.png', '.docx'];

if (!allowedExts.includes(ext.toLowerCase())) {
  throw new Error('Invalid file type');
}

const safeFilename = crypto.randomUUID() + ext;
const safePath = `/uploads/${new Date().getFullYear()}/${safeFilename}`;

return { filename: safeFilename, path: safePath };
```

## Data Encryption

### Encryption at Rest

**Encrypt Sensitive Data Before Storage**
```
Code Node (Encrypt):
const crypto = require('crypto');

const algorithm = 'aes-256-gcm';
const key = Buffer.from($env.ENCRYPTION_KEY, 'hex'); // 32 bytes
const iv = crypto.randomBytes(16);

const cipher = crypto.createCipheriv(algorithm, key, iv);

let encrypted = cipher.update($json.sensitiveData, 'utf8', 'hex');
encrypted += cipher.final('hex');

const authTag = cipher.getAuthTag();

return {
  encryptedData: encrypted,
  iv: iv.toString('hex'),
  authTag: authTag.toString('hex')
};
```

```
Code Node (Decrypt):
const crypto = require('crypto');

const algorithm = 'aes-256-gcm';
const key = Buffer.from($env.ENCRYPTION_KEY, 'hex');
const iv = Buffer.from($json.iv, 'hex');
const authTag = Buffer.from($json.authTag, 'hex');

const decipher = crypto.createDecipheriv(algorithm, key, iv);
decipher.setAuthTag(authTag);

let decrypted = decipher.update($json.encryptedData, 'hex', 'utf8');
decrypted += decipher.final('utf8');

return { sensitiveData: decrypted };
```

### Encryption in Transit

**Always Use HTTPS**
```
HTTP Request Node:
- URL: https://api.example.com (not http://)
- SSL/TLS verification: Enabled
- Minimum TLS version: 1.2

Webhook URLs:
- Only expose HTTPS endpoints
- Use valid SSL certificates
- Enable HSTS headers
```

### Field-Level Encryption

**Encrypt Specific Fields**
```
Database Schema:
CREATE TABLE customers (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255),
  name_encrypted TEXT,
  ssn_encrypted TEXT,
  iv TEXT,
  auth_tag TEXT
);

Before Insert:
1. Encrypt sensitive fields (name, SSN)
2. Store encrypted data + IV + auth tag
3. Leave non-sensitive fields unencrypted

Benefits:
- Query on non-encrypted fields (email)
- Encrypt only what's necessary
- Reduce performance impact
```

## Secure API Integration

### Certificate Pinning

**Verify API Server Identity**
```
HTTP Request Node:
- Enable certificate verification
- Pin expected certificate fingerprint

Code Node (Advanced):
const https = require('https');
const crypto = require('crypto');

const expectedFingerprint = 'AA:BB:CC:...';

const options = {
  hostname: 'api.example.com',
  path: '/data',
  checkServerIdentity: (host, cert) => {
    const fingerprint = crypto
      .createHash('sha256')
      .update(cert.raw)
      .digest('hex')
      .match(/.{2}/g)
      .join(':')
      .toUpperCase();
    
    if (fingerprint !== expectedFingerprint) {
      throw new Error('Certificate pinning failed');
    }
  }
};
```

### API Key Storage

**Use Separate Keys per Environment**
```
Credentials:
- Production_Stripe_API
- Staging_Stripe_API
- Development_Stripe_API

Workflow:
IF {{ $env.ENVIRONMENT === 'production' }}
  Use Production_Stripe_API
ELSE IF {{ $env.ENVIRONMENT === 'staging' }}
  Use Staging_Stripe_API
ELSE
  Use Development_Stripe_API
```

## Logging & Auditing

### Secure Logging

**What to Log**
```
✅ Log:
- Authentication attempts (success/failure)
- Authorization decisions
- Data access events
- Configuration changes
- Error events
- Webhook calls

❌ Never Log:
- Passwords
- API keys
- Credit card numbers
- SSN
- Authentication tokens
- Encryption keys
```

**Audit Trail Pattern**
```
After critical operations:
Postgres Insert:
Table: audit_log
Columns:
  user_id: {{ $json.userId }}
  action: "customer_data_accessed"
  resource: "customer:{{ $json.customerId }}"
  ip_address: {{ $json.ipAddress }}
  user_agent: {{ $json.userAgent }}
  timestamp: {{ $now.toISO() }}
  result: "success"
```

### Log Sanitization

**Remove Sensitive Data**
```
Code Node:
function sanitizeLog(data) {
  const sanitized = { ...data };
  
  // Mask credit cards
  if (sanitized.creditCard) {
    sanitized.creditCard = sanitized.creditCard.replace(
      /\d{12}(\d{4})/,
      '************$1'
    );
  }
  
  // Remove sensitive fields
  delete sanitized.password;
  delete sanitized.apiKey;
  delete sanitized.ssn;
  
  // Mask email
  if (sanitized.email) {
    sanitized.email = sanitized.email.replace(
      /(.{2})(.*)(@.*)/,
      '$1***$3'
    );
  }
  
  return sanitized;
}

return sanitizeLog($json);
```

## Compliance & Privacy

### GDPR Compliance

**Right to Erasure**
```
Workflow: Delete User Data
1. Receive deletion request (webhook)
2. Verify user identity (authentication)
3. Delete from all systems:
   - Main database
   - Analytics database
   - Backup systems
   - Log files
4. Generate deletion certificate
5. Send confirmation email
```

**Data Minimization**
```
Best Practices:
- Only collect necessary data
- Set retention periods
- Auto-delete old data

Scheduled Workflow (daily):
1. Query data older than retention period
2. Anonymize or delete
3. Log deletion for compliance
```

### PCI DSS Compliance

**Credit Card Handling**
```
✅ Correct Approach:
1. Use tokenization (Stripe, Braintree)
2. Never store full card numbers
3. Only store last 4 digits for display
4. Use secure payment gateway

❌ Never Do:
- Store full credit card numbers
- Log credit card data
- Send cards in plain text emails
- Store CVV codes
```

### HIPAA Compliance (Healthcare)

**PHI Protection**
```
Requirements:
- Encrypt all PHI at rest and in transit
- Access logging for all PHI access
- User authentication and authorization
- Regular security assessments
- Business Associate Agreements (BAA)

Workflow Pattern:
1. Authenticate user
2. Check user permissions for PHI access
3. Log access attempt
4. Decrypt PHI if authorized
5. Audit trail entry
```

## Access Control

### Role-Based Access Control (RBAC)

**Implementation**
```
User Roles:
- admin: Full access
- operator: Execute workflows
- viewer: View only

Database Schema:
CREATE TABLE user_roles (
  user_id INT,
  role VARCHAR(50),
  workflow_id VARCHAR(255)
);

Workflow Authorization:
Code Node:
const userRoles = await queryUserRoles($json.userId);
const requiredRole = 'admin';

if (!userRoles.includes(requiredRole)) {
  throw new Error('Insufficient permissions');
}
```

### Principle of Least Privilege

**Minimize Access**
```
Best Practices:
- Grant minimum required permissions
- Time-limited access for contractors
- Separate read/write permissions
- Regular access reviews

Example:
- Database user: Only SELECT permission
- API key: Scoped to specific resources
- Webhook: Limited to specific endpoints
```

## Security Monitoring

### Anomaly Detection

**Detect Suspicious Activity**
```
Scheduled Workflow (every 15 min):
1. Query recent webhook calls
2. Analyze patterns:
   - Unusual call volume
   - Failed authentication spikes
   - Requests from new IPs
   - Off-hours activity
3. IF: Anomaly detected
   - Send alert
   - Consider blocking temporarily
```

### Vulnerability Scanning

**Regular Security Checks**
```
Weekly Workflow:
1. Review workflow configurations
2. Check for:
   - Hardcoded credentials
   - Unencrypted sensitive data
   - Weak authentication
   - Missing input validation
3. Generate security report
4. Create remediation tickets
```

## Incident Response

### Security Incident Workflow

**Automated Response**
```
When security issue detected:
1. Disable affected workflow
2. Revoke compromised credentials
3. Send alerts to security team
4. Log incident details
5. Start incident response process

Incident Log:
{
  "incident_id": "SEC-2024-001",
  "type": "unauthorized_access",
  "severity": "high",
  "detected_at": "2024-01-15T10:30:00Z",
  "affected_workflows": ["payment-processing"],
  "actions_taken": ["disabled_workflow", "revoked_api_key"],
  "assigned_to": "security-team"
}
```

## Security Checklist

Before deploying workflows to production:

- [ ] All credentials in credential store (none hardcoded)
- [ ] Webhook authentication implemented
- [ ] Input validation for all external data
- [ ] SQL queries are parameterized
- [ ] Sensitive data encrypted at rest
- [ ] HTTPS only for all API calls
- [ ] Rate limiting on public endpoints
- [ ] Audit logging for sensitive operations
- [ ] Error messages don't leak sensitive info
- [ ] Regular security reviews scheduled
- [ ] Incident response plan documented
- [ ] Credentials rotation schedule set
- [ ] Access controls configured (RBAC)
- [ ] Data retention policies implemented
- [ ] Compliance requirements met (GDPR, PCI, HIPAA)
