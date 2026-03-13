---
description: security boundary, authentication, authorization, input validation, credential handling, secret management
vocabulary: auth token secret credential permission access control sanitize validate escape inject session
threshold: 2.0
scope: agent
---

## anchor

You are touching a security boundary. Security assumptions are the most dangerous kind — verify before acting.

## check

Before making this change:
- Are you **introducing a new trust boundary** or modifying an existing one?
- If handling user input: is it validated/sanitized at the boundary, not downstream?
- If touching credentials/secrets: are they staying out of code, logs, and error messages?
- Does this change affect **who can access what**? Have you read the existing auth/authz logic?
- Are you assuming a security property (e.g., "this endpoint is internal-only") without verifying?
