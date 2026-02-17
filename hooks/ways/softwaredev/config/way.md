---
description: application configuration, environment variables, dotenv files, config file management
vocabulary: dotenv environment configuration envvar config.json config.yaml connection port host url setting variable
files: \.env|config\.(json|yaml|yml|toml)$
threshold: 2.0
scope: agent, subagent
provenance:
  policy:
    - uri: governance/policies/operations.md
      type: governance-doc
  controls:
    - id: NIST SP 800-53 CM-6 (Configuration Settings)
      justifications:
        - Configuration hierarchy (env vars > config files > defaults) establishes deterministic configuration precedence
        - Fail-fast on missing required config prevents runtime configuration drift
        - Sensible defaults for non-sensitive values reduce misconfiguration risk
    - id: CIS Controls v8 4.1 (Establish and Maintain a Secure Configuration Process)
      justifications:
        - Startup validation pattern checks all required configuration before accepting traffic
        - .env.example with placeholder values documents expected configuration shape
    - id: NIST SP 800-53 IA-5 (Authenticator Management)
      justifications:
        - .env files excluded from version control via .gitignore verification
        - Secrets handling deferred to Security Way for credential separation
  verified: 2026-02-09
  rationale: >
    Configuration hierarchy and startup validation implement CM-6 configuration management.
    .env.example documentation and secure defaults address CIS 4.1 configuration process.
    Secrets separation via .gitignore enforces IA-5 authenticator protection.
---
# Configuration Way

## Hierarchy

1. Environment variables (highest priority)
2. Config files
3. Default values (lowest priority)

## When Creating Config

- Fail fast if required config is missing — check at startup, not at first use
- Provide sensible defaults where safe (timeouts, ports, log levels)
- For secrets handling: see Security Way

## .env Files

When creating a `.env` file:
1. Also create `.env.example` with placeholder values and comments
2. Verify `.env` is in `.gitignore`

```bash
# .env.example
DATABASE_URL=postgresql://user:pass@localhost:5432/mydb
API_KEY=your-api-key-here
LOG_LEVEL=info  # debug, info, warn, error
```

## Validation Pattern

```javascript
// Check required config at startup
const required = ['DATABASE_URL', 'API_KEY'];
for (const key of required) {
  if (!process.env[key]) throw new Error(`Missing required env var: ${key}`);
}
```
