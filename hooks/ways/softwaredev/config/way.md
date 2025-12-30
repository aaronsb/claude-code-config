---
keywords: config|environment.?variable|\.env|settings
files: \.env|config\.(json|yaml|yml|toml)$
---
# Configuration Way

## Environment Variables
- Use for secrets and environment-specific values
- Never commit `.env` with real secrets
- Provide `.env.example` with dummy values

## 12-Factor Principles
- Config in environment, not code
- Same artifact, different config per environment
- Secrets separate from code

## Patterns
- Fail fast if required config missing
- Validate config at startup
- Document all config options
- Sensible defaults where safe

## Hierarchy
1. Environment variables (highest priority)
2. Config files
3. Default values (lowest priority)
