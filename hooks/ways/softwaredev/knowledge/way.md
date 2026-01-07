---
match: regex
pattern: \bway\b|ways|knowledge|guidance|context.?inject
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

They complement: Skills can't detect tool execution. Ways support both regex and semantic matching.

## How Ways Work
Ways are contextual guidance that loads once per session when triggered by:
- **Keywords** in user prompts (UserPromptSubmit)
- **Tool use** - commands, file paths, descriptions (PostToolUse)

## Way File Format

Each way lives in `{domain}/{wayname}/way.md` with YAML frontmatter:

```markdown
---
match: regex              # or "semantic"
pattern: foo|bar|regex.*  # for regex matching
files: \.md$|docs/.*
commands: git\ commit
macro: prepend
---
# Way Name

## Guidance
- Compact, actionable points
```

For semantic matching:
```markdown
---
match: semantic
description: reference text for similarity
vocabulary: domain specific words
threshold: 0.55           # optional, default 0.58
---
```

### Frontmatter Fields
- `match:` - `regex` (default) or `semantic`
- `pattern:` - Regex matched against user prompts
- `files:` - Regex matched against file paths (Edit/Write)
- `commands:` - Regex matched against bash commands
- `macro:` - `prepend` or `append` to run `macro.sh`
- `description:` - Reference text for semantic similarity
- `vocabulary:` - Domain words for keyword counting
- `threshold:` - NCD threshold (lower = stricter, default 0.58)

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
