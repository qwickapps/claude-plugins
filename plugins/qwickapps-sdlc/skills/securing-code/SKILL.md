---
name: securing-code
description: >
  This skill should be used when writing authentication code, API endpoints, form handlers,
  database queries, or any code that processes user input or manages secrets.
  Auto-loads when implementing login flows, session management, OAuth callbacks, JWT handling,
  access control checks, SQL queries, file uploads, or external data ingestion.
  Provides a security checklist to apply while writing code — not a tutorial, a gate.
---

# Securing Code

Apply this checklist while writing code that touches user input, authentication, authorization,
database access, or secrets. Run through each section relevant to the code at hand.
Stop on failures. Fix before proceeding.

---

## 1. OWASP Top 10 — Quick Reference

Know which categories apply to the current code before writing a line:

| Category | Applies When |
|----------|-------------|
| Injection (SQL, LDAP, OS) | Building queries, shell commands, LDAP filters |
| Broken Authentication | Auth flows, session management, token issuance |
| XSS | Rendering user-supplied data in HTML |
| Insecure Direct Object Reference | Fetching records by user-supplied ID |
| Security Misconfiguration | Setting headers, enabling features, defaults |
| Sensitive Data Exposure | Logging, error messages, responses |
| Broken Access Control | Any route, resource, or action with a permission boundary |
| CSRF | State-changing requests from browser clients |
| Using Components with Known Vulnerabilities | Adding or updating dependencies |
| Insufficient Logging | Security events without audit trails |

Identify which categories apply. Address each one in the checklist sections below.

---

## 2. Input Validation

**Validate at every system boundary. Trust nothing from outside the process.**

Boundaries include: HTTP request parameters, request body, headers, cookies, file uploads,
environment variables from external systems, third-party API responses, message queue payloads.

Internal function calls between modules in the same process boundary do not require re-validation,
but validate data when it first enters any boundary crossing.

Validation checklist:
- [ ] Type: Confirm the value is the expected primitive type before use
- [ ] Length: Enforce maximum length on all strings (prevent buffer abuse and storage attacks)
- [ ] Format: Validate format with a strict allow-list pattern (regex, enum, structured type)
- [ ] Range: Enforce numeric bounds where applicable
- [ ] Allow-list over deny-list: Define what is permitted, reject everything else
- [ ] Reject unknown fields: Strip or reject unexpected keys in request payloads
- [ ] File uploads: Validate MIME type from content inspection, not filename extension. Enforce size limits. Store outside webroot.

**Never sanitize as the primary defense against injection.** Validate first; encode on output.

---

## 3. Output Encoding

**Encode output for the context in which it is rendered. The rendering context determines the encoding.**

| Context | Required Encoding |
|---------|------------------|
| HTML body | HTML entity encoding (`&amp;`, `&lt;`, `&gt;`) |
| HTML attribute | HTML attribute encoding (include quotes, encode `"`, `'`) |
| JavaScript string | JavaScript string escaping (`\n`, `\r`, `\"`, `\\`) |
| URL parameter | Percent-encoding (`encodeURIComponent`) |
| CSS value | CSS escaping |
| JSON response | JSON serialization (handled by `JSON.stringify`) |

Never interpolate user input directly into HTML strings. Use templating libraries that auto-encode
by default. When using React, JSX handles HTML encoding for interpolated values — do not use
`dangerouslySetInnerHTML` with user input.

Content Security Policy:
- Set `Content-Security-Policy` header to restrict script sources
- Prefer `script-src 'self'` over inline scripts
- Use nonces for necessary inline scripts instead of `unsafe-inline`
- Set `X-Content-Type-Options: nosniff`

---

## 4. Authentication Patterns

**Verify identity at every state transition. Never infer authentication from client-side state alone.**

JWT:
- [ ] Validate signature on every request — never decode without verifying
- [ ] Validate `iss`, `aud`, and `exp` claims
- [ ] Use short expiry (15 min access, longer refresh). Never indefinite.
- [ ] Store tokens in `httpOnly`, `Secure`, `SameSite=Strict` cookies when possible
- [ ] Never store JWTs in `localStorage` — accessible to XSS
- [ ] Implement token rotation on refresh. Invalidate old refresh tokens immediately.
- [ ] Maintain a deny-list for revoked tokens when immediate revocation is required

Session:
- [ ] Generate session IDs with cryptographically secure randomness (minimum 128 bits)
- [ ] Rotate session ID on privilege escalation (login, role change)
- [ ] Set absolute and idle timeouts
- [ ] Invalidate sessions server-side on logout — do not rely on deleting the cookie alone

OAuth / OIDC:
- [ ] Validate `state` parameter to prevent CSRF on the callback
- [ ] Validate `nonce` in ID tokens
- [ ] Use PKCE for public clients (SPAs, mobile)
- [ ] Validate the `iss` and `aud` in tokens from the identity provider
- [ ] Never use implicit flow — use authorization code flow

Password handling:
- [ ] Use bcrypt, argon2id, or scrypt for password hashing — never SHA-256, MD5, or unsalted hashing
- [ ] Apply rate limiting and account lockout on authentication endpoints
- [ ] Enforce minimum password complexity without excessive restrictions
- [ ] Never log passwords, not even partially

---

## 5. Authorization — Access Control

**Check authorization on every operation. Never rely on obscurity.**

- [ ] Verify the authenticated principal is authorized for the specific resource before returning or modifying it
- [ ] Check ownership: confirm the requested record belongs to the requesting user, not just that the user is authenticated
- [ ] Apply RBAC at the data layer, not only the UI layer
- [ ] Deny by default: if a permission check is ambiguous, deny access
- [ ] Never expose internal IDs as sequential integers — use UUIDs or opaque tokens
- [ ] Verify authorization on server for every state-changing operation, including those triggered by authenticated users

IDOR prevention:
```
// Unsafe: fetches any record by ID
const record = await db.find({ id: req.params.id });

// Safe: scope to the authenticated user
const record = await db.find({ id: req.params.id, ownerId: req.user.id });
```

---

## 6. CSRF Protection

**Apply to all state-changing operations from browser clients.**

- [ ] Use `SameSite=Strict` or `SameSite=Lax` on session cookies
- [ ] For `SameSite=Lax`, add CSRF tokens for all state-changing forms and AJAX requests
- [ ] Validate the `Origin` or `Referer` header for sensitive operations when tokens are impractical
- [ ] APIs that require only `Authorization: Bearer` headers are inherently CSRF-resistant if cookies are not involved

Do not rely solely on checking that the request has an `Authorization` header — validate the token's authenticity and scope.

---

## 7. SQL Injection Prevention

**Use parameterized queries or an ORM that parameterizes by default. Never concatenate user input into queries.**

Unsafe:
```sql
-- NEVER do this
SELECT * FROM users WHERE email = '${userInput}'
```

Safe — parameterized query:
```typescript
// PostgreSQL (pg library)
await db.query('SELECT * FROM users WHERE email = $1', [userInput]);

// Prisma ORM (parameterizes automatically)
await prisma.user.findUnique({ where: { email: userInput } });
```

When dynamic query construction is unavoidable (dynamic column names, ORDER BY clauses):
- [ ] Validate against an explicit allow-list of permitted values
- [ ] Never interpolate directly — map user input to a controlled value

Apply the same principle to LDAP queries, OS commands (`child_process`), NoSQL queries (MongoDB `$where`), and template engines.

---

## 8. XSS Prevention

**Defense in depth: validate input, encode output, set CSP.**

- [ ] Never insert user-controlled data into `innerHTML`, `outerHTML`, `document.write`, or `eval`
- [ ] Use `textContent` instead of `innerHTML` for inserting text into the DOM
- [ ] Apply DOMPurify or equivalent when rendering rich user-generated HTML is unavoidable
- [ ] Audit React components for `dangerouslySetInnerHTML` — justify each usage
- [ ] Set `Content-Security-Policy` header. Block `unsafe-inline` for scripts.
- [ ] Set `X-XSS-Protection: 1; mode=block` for older browser compatibility

Server-side template injection shares the same category. Never pass user input to template engines that execute it as code.

---

## 9. Secrets Management

**Secrets live in environment variables and secret managers. Never in code, logs, or version control.**

- [ ] Load secrets from environment variables or a secrets manager (AWS Secrets Manager, HashiCorp Vault, 1Password Secrets Automation)
- [ ] Never hardcode API keys, passwords, private keys, or tokens in source code
- [ ] Never commit `.env` files — add to `.gitignore` and document required variables in `.env.example`
- [ ] Never log secret values, even partially — mask them in log output
- [ ] Rotate secrets on suspected exposure immediately
- [ ] Use short-lived credentials where possible (IAM roles, ephemeral tokens)
- [ ] Audit environment variable exposure in error messages and diagnostics endpoints

Pre-commit check: before committing, verify no secrets appear in `git diff --staged`. Use `git-secrets` or similar tooling to enforce this automatically.

---

## 10. Dependency Security

**Outdated dependencies with known vulnerabilities are one of the most common attack vectors.**

- [ ] Run `npm audit` (or `pnpm audit`) before adding or updating dependencies
- [ ] Address critical and high severity advisories before committing
- [ ] Pin dependency versions in `package.json`. Commit `package-lock.json` or `pnpm-lock.yaml`.
- [ ] Review `package.json` `scripts` field in new dependencies — install scripts execute arbitrary code
- [ ] Prefer packages with active maintenance, broad usage, and no critical open advisories
- [ ] Schedule periodic dependency updates rather than waiting for feature work to trigger them

---

## 11. Error Handling

**Errors visible to users must be generic. Errors visible to developers must be detailed.**

- [ ] Return generic error messages to clients: "An error occurred." not stack traces
- [ ] Log detailed errors server-side with full context (request ID, user ID if available, stack trace)
- [ ] Never expose internal system details in error responses: file paths, library versions, SQL errors, server architecture
- [ ] Handle all promise rejections and async errors — unhandled rejections can expose state or crash the process
- [ ] Return consistent HTTP status codes: 401 for unauthenticated, 403 for unauthorized, 404 for not found (never 500 for auth failures)
- [ ] Avoid timing differences in error responses that leak information (e.g., "user not found" vs "wrong password" reveals valid usernames)

---

## Security Gate Before Commit

Run through this gate before committing code that touches any of the above areas:

- [ ] Input validated at all entry boundaries
- [ ] Output encoded for the rendering context
- [ ] Authentication verified on every operation
- [ ] Authorization checked for every resource access, including ownership
- [ ] No user input interpolated into SQL queries
- [ ] CSRF protection applied to state-changing endpoints
- [ ] No secrets in source code or logs
- [ ] `npm audit` shows no critical issues in changed dependencies
- [ ] Error messages to users are generic
- [ ] Detailed errors logged server-side only

If any item fails, fix it before proceeding to commit. Security issues found after deployment cost significantly more than issues caught during development.
