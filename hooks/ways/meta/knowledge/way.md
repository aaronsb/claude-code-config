---
match: regex
pattern: \bway\b|\bways\b|knowledge|guidance|context.?inject
files: \.claude/ways/.*way\.md$
scope: agent, subagent
---
# Knowledge Way

## Ways vs Skills

**Skills** = semantically-discovered (Claude decides based on intent)
**Ways** = triggered (patterns, commands, file edits, or state conditions)

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
- **Tool use** - commands, file paths (PreToolUse)
- **State conditions** - context threshold, file existence (UserPromptSubmit)

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

For model-based classification (uses Haiku):
```markdown
---
match: model
description: security-sensitive operations, auth changes, credential handling
---
```

For state-based triggers:
```markdown
---
trigger: context-threshold
threshold: 90             # percentage (0-100)
---
```

### Frontmatter Fields

**Pattern-based:**
- `match:` - `regex` (default), `semantic`, or `model`
- `pattern:` - Regex matched against user prompts
- `files:` - Regex matched against file paths (Edit/Write)
- `commands:` - Regex matched against bash commands

**Semantic (NCD):**
- `description:` - Reference text for semantic similarity
- `vocabulary:` - Domain words for keyword counting
- `threshold:` - NCD threshold (lower = stricter, default 0.58)

**Model (Haiku):**
- `description:` - What this way covers (Haiku classifies yes/no)
- Adds ~800ms latency but high accuracy

**State-based:**
- `trigger:` - State condition type (`context-threshold`, `file-exists`, `session-start`)
- `threshold:` - For context-threshold: percentage (0-100)
- `path:` - For file-exists: glob pattern relative to project

**Other:**
- `macro:` - `prepend` or `append` to run `macro.sh`

## Creating a New Way

1. Create directory in:
   - Global: `~/.claude/hooks/ways/{domain}/{wayname}/`
   - Project: `$PROJECT/.claude/ways/{domain}/{wayname}/`

2. Add `way.md` with frontmatter + guidance

3. Optionally add `macro.sh` for dynamic context

**That's it.** No config files to update.

## Writing Voice

The mechanical format matters, but so does how the guidance reads. Framing shapes how it gets applied.

**Include the why.** "Use conventional commits" is a rule. "We use conventional commits — the release tooling parses them for changelogs" is a shared practice with context. An agent that understands the reason applies better judgment at the edges.

**Write as a collaborator.** "Run tests before committing" is an instruction. "We run tests before committing to catch regressions early" is alignment around a shared goal. The inclusive framing — *we*, *our*, *let's* — carries intent that directives alone don't. This isn't sentimental; it's functional.

**Write for the innie.** Your reader arrives with no memory, no prior context, and a set of injected instructions as their entire understanding of how work gets done. If guidance only makes sense with context they'll never have, rewrite it.

**Respect the reader.** Governance that talks down gets routed around. Ways that explain their reasoning get better adherence than ways that assert authority.

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

## Enabling/Disabling Way Domains

Control which domains are active via `~/.claude/ways.json`:

```json
{
  "disabled": ["itops", "experimental"]
}
```

- Add domain name to `disabled` array to deactivate all ways in that domain
- Remove from array to reactivate
- Empty array `[]` means all domains active

## Locations
- Global: `~/.claude/hooks/ways/{domain}/{wayname}/way.md`
- Project: `$PROJECT/.claude/ways/{domain}/{wayname}/way.md`
- Markers: `/tmp/.claude-way-{domain}-{wayname}-{session_id}`

## State Machine

Each (way, session) pair has two states:

```
┌─────────────┐  keyword/command/file/state    ┌─────────────┐
│  not_shown  │ ─────────────────────────────▶ │   shown     │
│  (no marker)│       output + create marker   │(marker exists)
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
