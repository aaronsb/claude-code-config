# Operations Ways

Guidance for configuration, security, SSH/remote access, and documentation.

## Config

**Triggers**: Semantic match on configuration/environment/settings concepts; editing `.env`, `config.json`, `config.yaml`, `config.toml`

Establishes a clear hierarchy for configuration sources:

1. Environment variables (highest priority)
2. Config files
3. Default values (lowest priority)

The rationale: environment variables are the standard way to configure applications across deployment contexts (local dev, CI, staging, production) without changing code or files. Config files provide structured defaults. Hardcoded defaults are the fallback.

Key positions:

- **Fail fast** - check required config at startup, not at first use. A missing `DATABASE_URL` should crash the app immediately, not after it's been running for an hour and someone hits a database query.
- **Sensible defaults** - provide defaults where safe (timeouts, ports, log levels). Don't force configuration of things that have obvious right answers.
- **`.env` hygiene** - when creating `.env`, also create `.env.example` with placeholder values and comments. Verify `.env` is in `.gitignore`. These two steps prevent the most common config problems: "what env vars does this need?" and "who committed the production credentials?"

## Security

**Triggers**: Semantic match on authentication/secrets/vulnerability concepts (threshold: 0.52, the most strict)

Uses the lowest semantic threshold of any way because false negatives in security guidance are costlier than false positives. Better to remind about security when it's not needed than to miss a moment when it is.

Core rules:

- **Never commit secrets** - no API keys, passwords, tokens, or private keys in source control. Use environment variables or secret managers.
- **Parameterized queries** - always. No string concatenation for SQL. This is non-negotiable regardless of whether the input "looks safe."
- **Input validation at boundaries** - validate and sanitize at system entry points (API endpoints, form handlers). Trust nothing from outside.
- **Detection patterns** - the way includes patterns to scan for: hardcoded secrets, SQL injection vectors, XSS vulnerabilities. These are the OWASP Top 10 basics.

## SSH

**Triggers**: Prompt mentions "ssh", "remote server", "remote host"; running `ssh`, `scp`, `rsync`, `sshpass`

The primary concern is non-interactive execution. Claude Code runs commands programmatically - interactive SSH sessions with password prompts or host key confirmations will hang.

Key positions:

- **BatchMode=yes** - always. This makes SSH fail immediately on any interactive prompt rather than hanging.
- **Strict timeouts** - `ConnectTimeout=10` and `ServerAliveInterval=15` prevent indefinite hangs on unreachable hosts.
- **Scenario-aware** - the way distinguishes development/homelab (where `sshpass` might be acceptable) from enterprise (where it shouldn't be used). Claude Code is often pointed at home servers where convenience trumps policy.

## Documentation

**Triggers**: Prompt mentions "readme", "documentation", "docs"; editing `README.md` or files in `docs/`

Follows a "gist first" philosophy: a reader should understand what the project is and why it exists within 30 seconds of opening the README.

The way scales documentation to project complexity:

| Complexity | Documentation |
|------------|---------------|
| Script/utility | README only |
| Small library | README + examples |
| Application | README + docs/ tree |
| Platform | README + docs/ + guides + API reference |

Anti-patterns to avoid:
- **Monolith README** - everything in one massive file
- **Installation-first** - burying the "what" under setup instructions
- **Over-documenting** - 500 lines of docs for a utility script

The principle of progressive disclosure applies: overview first, details on demand, deep dives linked from relevant sections.
