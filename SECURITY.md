# Security Policy

## Reporting a Vulnerability

If you discover a security issue, please report it by [opening a private security advisory](https://github.com/aaronsb/claude-code-config/security/advisories/new) rather than a public issue.

## Scope

This project executes shell scripts via Claude Code hooks. The primary security considerations are:

- **Way macros** (`macro.sh`) execute arbitrary shell commands. Project-local macros are disabled by default and require explicit trust via `~/.claude/trusted-project-macros`.
- **Hook scripts** run on every tool invocation. They should not make network calls unless rate-limited and clearly documented (e.g., `check-config-updates.sh`).
- **No secrets** should be stored in way files, macros, or hook output.
