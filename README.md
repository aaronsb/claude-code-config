# Claude Code Config

A domain-agnostic guidance framework for Claude Code. Injects relevant knowledge just-in-time based on what you're doing.

## The Idea

**Ways** = automated, contextual guidance triggered by keywords, commands, and file patterns.

This repo ships with software development ways, but the mechanism is general-purpose. You could have ways for:
- Excel/Office productivity
- AWS operations
- Financial analysis
- Research workflows
- Anything with patterns Claude should know about

## What It Does

```
You: "let's discuss the architecture"
→ ADR way loads (architecture decision format, workflow)

You: "there's a bug in the auth"
→ Debugging way + Security way load

Claude runs: git commit
→ Commits way loads (conventional commit format)
```

Ways load once per session when triggered. No manual invocation needed.

## Quick Start

```bash
# Backup existing config if any
[ -d ~/.claude ] && mv ~/.claude ~/.claude-backup-$(date +%Y%m%d)

# Clone
git clone https://github.com/aaronsb/claude-code-config ~/.claude

# Make hooks executable
chmod +x ~/.claude/hooks/**/*.sh ~/.claude/hooks/*.sh 2>/dev/null

# Restart Claude Code - ways are now active
```

## How It Works

1. **SessionStart** loads `core.md` - a compact index of all available ways
2. **UserPromptSubmit** scans your message for keywords
3. **PostToolUse** scans commands, file paths, and descriptions
4. Matching ways inject via `additionalContext` - Claude sees them
5. Each way loads once per session (markers in `/tmp`)

```
~/.claude/hooks/ways/
├── core.md              # Loads at startup
├── *.md                 # Individual ways (frontmatter defines triggers)
├── *.macro.sh           # Optional dynamic context (see Way Macros)
├── check-prompt.sh      # Keyword matching
├── check-bash-post.sh   # Command matching
├── check-file-post.sh   # File path matching
└── show-way.sh          # Once-per-session gating
```

## Creating a Way

Each way is self-contained with YAML frontmatter:

```markdown
---
keywords: pattern1|pattern2|regex.*
files: \.tsx$|components/.*
commands: npm\ run\ build
macro: prepend
---
# Way Name

## Guidance
- Compact, actionable points
- Not exhaustive documentation
```

Drop the file in `~/.claude/hooks/ways/` (global) or `$PROJECT/.claude/ways/` (project). Done.

### Frontmatter Fields

| Field | Purpose |
|-------|---------|
| `keywords:` | Regex matched against user prompts |
| `files:` | Regex matched against file paths (Edit/Write) |
| `commands:` | Regex matched against bash commands |
| `macro:` | `prepend` or `append` - run matching `.macro.sh` for dynamic context |

## Way Macros

Static guidance can't know your environment. Macros add dynamic state detection:

```
Way    = guidance (the "how")
Macro  = state detection (the "what is")
Output = contextual guidance (the "how, given what is")
```

**Example**: `github.macro.sh` detects solo vs team project:
```bash
#!/bin/bash
gh repo view &>/dev/null || { echo "**Note**: Not a GitHub repo"; exit 0; }
CONTRIBUTORS=$(timeout 2 gh api repos/:owner/:repo/contributors --jq 'length' 2>/dev/null)
if [[ "$CONTRIBUTORS" -le 2 ]]; then
  echo "**Context**: Solo project - PR optional"
else
  echo "**Context**: Team project - PR recommended"
fi
```

Macros are optional. Ways without macros work as pure static guidance.

See [ADR-004](docs/adr/ADR-004-way-macros.md) for full macro documentation.

## Project-Local Ways

Projects can have custom ways in `.claude/ways/`:

```
your-project/.claude/ways/
├── our-api.md           # Project conventions
├── deployment.md        # How we deploy
└── react.md             # Framework-specific guidance
```

Project ways override global ways with the same name. A template is auto-created on first session.

## Built-in Ways (Software Dev)

This repo ships with 20 development-focused ways:

| Way | Triggers On |
|-----|-------------|
| **adr** | `docs/adr/*.md`, "architect", "decision" |
| **api** | "endpoint", "rest", "graphql" |
| **commits** | `git commit`, "push to remote" |
| **config** | `.env`, "environment variable" |
| **debugging** | "bug", "broken", "investigate" |
| **deps** | `npm install`, "dependency", "package" |
| **docs** | `README.md`, "documentation" |
| **errors** | "error handling", "exception" |
| **github** | `gh`, "pull request", "issue" |
| **knowledge** | `.claude/ways/*.md`, "ways" |
| **migrations** | "migration", "schema" |
| **patches** | `*.patch`, "git apply" |
| **performance** | "slow", "optimize", "profile" |
| **quality** | "refactor", "code review", "solid" |
| **release** | "deploy", "version", "changelog" |
| **security** | "auth", "secret", "token" |
| **ssh** | `ssh`, `scp`, "remote server" |
| **subagents** | "delegate", "subagent" |
| **testing** | `pytest`, `jest`, "coverage", "tdd" |
| **tracking** | `.claude/todo-*.md`, "multi-session" |

**Replace these entirely** if your domain isn't software dev. The framework doesn't care.

## Also Included

- **6 specialized subagents** for complex tasks (requirements, architecture, planning, review, workflow, organization)
- **ADR-driven workflow** guidance
- **GitHub-first patterns** (auto-detects `gh` availability)
- **Status line** with git branch and API usage

## Philosophy

This is a "poor man's RAG" - retrieval-augmented generation without the infrastructure:

| Traditional RAG | Ways System |
|-----------------|-------------|
| Vector embeddings | Keyword regex |
| Semantic search | Pattern matching |
| External services | Bash + jq |
| Probabilistic | Deterministic |
| Domain-locked | Domain-agnostic |

Simple, transparent, zero dependencies beyond standard unix tools. Fork it, gut the dev ways, add your own domain.

## Updating

```bash
cd ~/.claude && git pull
```

## License

MIT
