---
description: security overview, secure coding defaults, security review checklist
vocabulary: security vulnerability protect defense secure harden owasp
threshold: 1.8
scope: agent, subagent
provenance:
  policy:
    - uri: governance/policies/operations.md
      type: governance-doc
  controls:
    - id: OWASP Top 10 2021 A03:Injection
      justifications:
        - Detection table maps SQL concatenation, innerHTML, and shell interpolation to remediation actions
        - Parameterized queries required as default for all database access
        - Input validation enforced at system boundaries
    - id: NIST SP 800-53 IA-5 (Authenticator Management)
      justifications:
        - Never-commit list explicitly prohibits API keys, tokens, passwords, and private keys
        - Hardcoded secrets flagged for extraction to environment variables
        - .env hygiene enforced with .env.example and .gitignore verification
    - id: CIS Controls v8 16.12 (Implementation of Application-Level Access)
      justifications:
        - Missing auth check on endpoints flagged as security issue
        - Principle of least privilege stated as default for permissions
    - id: SOC 2 CC6.1 (Logical and Physical Access Controls)
      justifications:
        - Authentication/authorization gap detection in code review checklist
        - Endpoint access control enforcement via middleware/guard guidance
  verified: 2026-02-05
  rationale: >
    Detection table operationalizes OWASP injection prevention and NIST credential
    management at code-commit time. Secrets exclusion and .env hygiene implement
    CIS credential separation. Auth check enforcement shifts access control
    verification left into development.
---
# Security Way

## Defaults

- Parameterized queries for all database access
- Escape output for its context (HTML, URL, SQL)
- Validate at system boundaries (user input, external APIs)
- Principle of least privilege for permissions

## When Reviewing Existing Code

Flag these as security issues:
- Hardcoded secrets or credentials
- SQL string concatenation
- Unsanitized user input in templates or commands
- Missing authentication/authorization on endpoints
- Sensitive data in logs
