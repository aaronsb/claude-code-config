---
files: \.claude/ways/.*way\.md$
scope: agent, subagent
provenance:
  policy:
    - uri: docs/hooks-and-ways/extending.md
      type: governance-doc
  controls:
    - id: ISO 9001:2015 7.5 (Documented Information)
      justifications:
        - Way file format specification ensures documented information is appropriate and suitable
        - Frontmatter schema (match, pattern, files, commands) standardizes trigger documentation
        - Writing voice guidance ensures guidance is readable by context-free readers
  verified: 2026-02-05
  rationale: >
    Format spec and authoring guidance for writing effective ways.
    Only injected when editing way files — heavier reference that
    isn't needed for general "ways" conversations.
---
# Authoring Ways

## Way File Format

Each way lives in `{domain}/{wayname}/way.md` with YAML frontmatter:

```markdown
---
pattern: foo|bar|regex.*  # for regex matching
files: \.md$|docs/.*
commands: git\ commit
macro: prepend
---
# Way Name

## Guidance
- Compact, actionable points
```

For semantic matching (BM25 — preferred):
```markdown
---
description: what this way covers, in natural language
vocabulary: domain specific keywords users would say
threshold: 2.0            # BM25 score threshold (higher = stricter)
---
```

No `match:` field needed — the presence of `description:` + `vocabulary:` enables semantic matching automatically. Matching is additive: pattern OR semantic (either fires the way).

For state-based triggers:
```markdown
---
trigger: context-threshold
threshold: 90             # percentage (0-100)
---
```

### Frontmatter Fields

**Pattern-based:**
- `pattern:` - Regex matched against user prompts
- `files:` - Regex matched against file paths (Edit/Write)
- `commands:` - Regex matched against bash commands

**Semantic (BM25):**
- `description:` - Natural language reference text for what this way covers
- `vocabulary:` - Space-separated domain keywords users would say
- `threshold:` - BM25 score threshold (default 2.0, higher = stricter)
- Degradation: BM25 binary → gzip NCD fallback → skip

**State-based:**
- `trigger:` - State condition type (`context-threshold`, `file-exists`, `session-start`)
- `threshold:` - For context-threshold: percentage (0-100)
- `path:` - For file-exists: glob pattern relative to project

**Other:**
- `macro:` - `prepend` or `append` to run `macro.sh` for dynamic context
- `scope:` - `agent`, `subagent`, `teammate` (comma-separated, default: agent)

## Creating a New Way

1. Create directory in:
   - Global: `~/.claude/hooks/ways/{domain}/{wayname}/`
   - Project: `$PROJECT/.claude/ways/{domain}/{wayname}/`

2. Add `way.md` with frontmatter + guidance

3. Optionally add `macro.sh` for dynamic context

**That's it.** No config files to update. Project ways override global ways with the same path. Ways can nest arbitrarily: `{domain}/{parent}/{child}/way.md`.

## Writing Ways Well

Write as a collaborator, not an authority. Include the *why* — an agent that understands the reason applies better judgment at the edges. Write for a reader with no prior context.

For state transitions and process flows, prefer Cypher-style notation over ASCII diagrams — it's compact, the model parses it natively, and it saves tokens:
```
(state_a)-[:EVENT {context}]->(state_b)  // what happens
```

## Testing Your Way

Use `/ways-tests` to validate matching quality:
- `/ways-tests score <way> "sample prompt"` — test a specific way
- `/ways-tests score-all "sample prompt"` — rank all ways against a prompt
- `/ways-tests suggest <way>` — analyze vocabulary gaps
- `/ways-tests lint <way>` — validate frontmatter

For vocabulary tuning workflows, see the optimization sub-way (triggers on vocabulary/optimization discussion).

Full authoring guide: `docs/hooks-and-ways/extending.md`
