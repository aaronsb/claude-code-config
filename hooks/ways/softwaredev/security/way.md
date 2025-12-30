---
keywords: auth|secret|token|password|permission|vulnerab|owasp|inject
---
# Security Way

## Never Commit
- `.env` files with real secrets
- API keys, tokens, passwords
- Private keys, certificates

## Input Validation
- Validate at system boundaries (user input, external APIs)
- Don't trust client-side validation alone
- Sanitize before using in queries, commands, HTML

## OWASP Top Concerns
- Injection (SQL, command, XSS)
- Broken authentication
- Sensitive data exposure
- Security misconfiguration

## When in Doubt
- Hash passwords (bcrypt, argon2)
- Use parameterized queries
- Escape output for context (HTML, URL, SQL)
- Principle of least privilege
