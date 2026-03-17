---
description: pre-install trust check for untrusted or unfamiliar repositories
vocabulary: pip install npm install cargo build go build make docker run setup.py postinstall git clone
threshold: 2.5
scope: agent
---
## anchor
Supply chain trust: scan before you run.

## check
Before installing or building from this repo:
- Have you checked git history for secrets or suspicious objects?
- Have you scanned the source for eval/exec, obfuscation, or exfiltration?
- Have you audited dependencies against known vulnerabilities?

If this is a trusted, familiar repo you've worked in before, carry on.

## Common Rationalizations

| Rationalization | Counter |
|---|---|
| "This is a popular package, it's fine" | event-stream had 1.5M weekly downloads when compromised. Popularity is not safety. |
| "I've used this before" | Have you used THIS version? Check the changelog and diff since your last use. |
| "It's in a container, so it's isolated" | Containers have network access. A malicious postinstall can exfiltrate data. |
