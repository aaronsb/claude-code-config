# Claude Code Config

Contextual guidance system for Claude Code. Injects relevant knowledge just-in-time based on what you're doing.

## What It Does

**Ways** are bite-sized guidance that load automatically when triggered:

```
You: "let's discuss the architecture"
→ ADR way loads (architecture decision format, workflow)

You: "there's a bug in the auth"
→ Debugging way + Security way load

Claude runs: git commit
→ Commits way loads (conventional commit format)
```

19 built-in ways covering: ADR, API design, commits, config, debugging, dependencies, documentation, error handling, GitHub, migrations, patches, performance, quality, releases, security, subagents, testing, tracking, and meta-knowledge about ways themselves.

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
├── check-prompt.sh      # Keyword matching
├── check-bash-post.sh   # Command matching
├── check-file-post.sh   # File path matching
└── show-way.sh          # Once-per-session gating
```

## Project-Local Ways

Projects can have custom ways in `.claude/ways/`:

```
your-project/.claude/ways/
├── our-api.md           # Project conventions
├── deployment.md        # How we deploy
└── react.md             # Framework-specific guidance
```

Project ways override global ways with the same name. A template is auto-created on first session.

## Creating a Way

Each way is self-contained with YAML frontmatter:

```markdown
---
keywords: pattern1|pattern2|regex.*
files: \.tsx$|components/.*
commands: npm\ run\ build
---
# Way Name

## Guidance
- Compact, actionable points
- Not exhaustive documentation
```

Drop the file in `~/.claude/hooks/ways/` (global) or `$PROJECT/.claude/ways/` (project). Done.

## Built-in Ways

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
| **subagents** | "delegate", "subagent" |
| **testing** | `pytest`, `jest`, "coverage", "tdd" |
| **tracking** | `.claude/todo-*.md`, "multi-session" |

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

Simple, transparent, zero dependencies beyond standard unix tools.

## Updating

```bash
cd ~/.claude && git pull
```

## License

MIT
