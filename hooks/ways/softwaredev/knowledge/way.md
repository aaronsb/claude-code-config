---
keywords: knowledge|ways|guidance|context.?inject|how.?do.?ways|skill
files: \.claude/ways/.*way\.md$
---
# Knowledge Way

## Ways vs Skills

**Skills** = semantically-discovered (Claude decides based on intent)
**Ways** = pattern-triggered (keywords, commands, file edits)

| Use Skills for | Use Ways for |
|---------------|--------------|
| Semantic discovery ("explain code") | Tool-triggered (`git commit` → format reminder) |
| Tool restrictions (`allowed-tools`) | File-triggered (edit `.env` → config guidance) |
| Multi-file reference docs | Session-gated (once per session) |
| | Dynamic context (macro queries API) |

They complement: Skills can't detect tool execution. Ways can't do semantic matching.

## How Ways Work
Ways are contextual guidance that loads once per session when triggered by:
- **Keywords** in user prompts (UserPromptSubmit)
- **Tool use** - commands, file paths, descriptions (PostToolUse)

## Way File Format

Each way lives in `{domain}/{wayname}/way.md` with YAML frontmatter:

```markdown
---
keywords: pattern1|pattern2|regex.*
files: \.md$|docs/.*
commands: git\ commit|npm\ test
macro: prepend
---
# Way Name

## Guidance content here
- Compact, actionable points
- Not exhaustive documentation
```

### Frontmatter Fields
- `keywords:` - Regex matched against user prompts
- `files:` - Regex matched against file paths (Edit/Write)
- `commands:` - Regex matched against bash commands
- `macro:` - `prepend` or `append` to run `macro.sh` for dynamic context

## Creating a New Way

1. Create directory in:
   - Global: `~/.claude/hooks/ways/{domain}/{wayname}/`
   - Project: `$PROJECT/.claude/ways/{domain}/{wayname}/`

2. Add `way.md` with frontmatter + guidance

3. Optionally add `macro.sh` for dynamic context

**That's it.** No config files to update.

## Project-Local Ways

Projects can override or add ways:
```
$PROJECT/.claude/ways/
└── myproject/
    ├── api/way.md           # Project conventions
    ├── deployment/way.md    # How we deploy
    └── testing/way.md       # Override global testing way
```

Project ways take precedence over global ways with same path.

## Locations
- Global: `~/.claude/hooks/ways/{domain}/{wayname}/way.md`
- Project: `$PROJECT/.claude/ways/{domain}/{wayname}/way.md`
- Markers: `/tmp/.claude-way-{domain}-{wayname}-{session_id}`

## State Machine

Each (way, session) pair has two states:

```
┌─────────────┐   keyword/command/file match   ┌─────────────┐
│  not_shown  │ ─────────────────────────────▶ │   shown     │
│  (no marker)│        output + create marker  │(marker exists)
└─────────────┘                                └─────────────┘
       │                                              │
       │         any subsequent match                 │
       │◀─────────────────────────────────────────────│
                     no-op (idempotent)
```

**Multi-trigger semantics:**
- Single prompt may match multiple ways → all fire (each has own marker)
- Same way matched multiple times → first wins, rest are no-ops
- Multiple hooks (prompt, bash, file) may fire same way → marker prevents duplicates
- Project-local and global with same name → project-local wins (single marker per name)
