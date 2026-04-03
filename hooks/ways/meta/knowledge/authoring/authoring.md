---
files: \.claude/ways/.*\.md$
scope: agent, subagent
---
<!-- epistemic: convention -->
# Authoring Ways

## Way File Format

Each way lives in `{domain}/{wayname}/{wayname}.md` with YAML frontmatter.

## Matching Strategy

**Use semantic matching.** This is the primary matching strategy for prompt-triggered ways. The engine uses embeddings (cosine similarity) with BM25 as fallback.

```markdown
---
description: what this way covers, in natural language
vocabulary: domain specific keywords users would say
threshold: 2.0            # BM25 score threshold (higher = stricter)
embed_threshold: 0.35     # cosine similarity threshold (optional, per-way tuning)
scope: agent
---
```

Regex-only matching (`pattern:` without `description:`/`vocabulary:`) will miss any phrasing you didn't predict. Users don't say "code.?quality" — they say "clean this up" or "this function is a mess." Semantic matching with a good description and vocabulary handles the variation. Regex doesn't.

If you still want regex-only, that's your choice, but expect poor recall on natural language prompts.

**When to add `pattern:` alongside semantic:** As a supplementary trigger for exact matches you never want to miss. Matching is additive — pattern OR semantic, either fires the way. Use both when you need guaranteed activation on specific terms AND broad natural language coverage.

**Other trigger types** (not prompt-based, semantic doesn't apply):
- `files:` — regex matched against file paths (Edit/Write hooks)
- `commands:` — regex matched against bash commands
- `trigger:` — state-based (context-threshold, file-exists, session-start)

**All values must be single-line.** Do not use YAML folded (`>`) or literal (`|`) scalars — the trigger pipeline parsers only read the first line, silently returning `>` as the value. Use `ways lint` to catch this.

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

**Semantic:**
- `description:` - Natural language reference text for what this way covers
- `vocabulary:` - Space-separated domain keywords users would say
- `threshold:` - BM25 score threshold (default 2.0, higher = stricter)
- `embed_threshold:` - Cosine similarity override (optional, per-way tuning)
- Engine: embedding → BM25 → skip (regex still works without either)

**State-based:**
- `trigger:` - State condition type (`context-threshold`, `file-exists`, `session-start`)
- `threshold:` - For context-threshold: percentage (0-100)
- `path:` - For file-exists: glob pattern relative to project

**Preconditions (`when:` block):**
- `when:` - Deterministic gate checked before any matching. If unmet, way is skipped entirely.
  - `project:` - Only fire in this project directory (e.g., `~/.claude`). Path is resolved for comparison.

```yaml
when:
  project: ~/.claude    # only fire when working in claude-code-config
```

Ways without a `when:` block fire everywhere (the default). Use `when:` sparingly — only for self-referential ways that are meaningless outside their home project.

**Other:**
- `macro:` - `prepend` or `append` to run `macro.sh` for dynamic context
- `scope:` - `agent`, `subagent`, `teammate` (comma-separated, default: agent)

## Creating a New Way

1. Create directory in:
   - Global: `~/.claude/hooks/ways/{domain}/{wayname}/`
   - Project: `$PROJECT/.claude/ways/{domain}/{wayname}/`

2. Add `{wayname}.md` with frontmatter + guidance

3. Optionally add `macro.sh` for dynamic context

**That's it.** No config files to update. Project ways override global ways with the same path. Ways can nest arbitrarily: `{domain}/{parent}/{child}/{child}.md`.

## Writing Ways Well

Write as a collaborator, not an authority. Include the *why* — an agent that understands the reason applies better judgment at the edges. Write for a reader with no prior context.

For state transitions and process flows, prefer Cypher-style notation over ASCII diagrams — it's compact, the model parses it natively, and it saves tokens:
```
(state_a)-[:EVENT {context}]->(state_b)  // what happens
```

## Progressive Disclosure Trees

When a way covers multiple distinct concerns (>80 lines, >2 sub-topics, language/tool-specific variants), decompose into a tree. The supply chain tree (`softwaredev/code/supplychain/`) is the reference implementation.

**Threshold progression** — thresholds increase with depth:
- Root: `1.8` (broad catch, overview/orientation)
- Mid-tier: `2.0` (focused, actionable guidance)
- Leaf/specialist: `2.5` (narrow, specific implementation)

**Vocabulary isolation** — sibling ways MUST NOT share vocabulary:
- Target Jaccard similarity < 0.15 between siblings
- Each child owns its own keyword space
- Use `/ways-tests jaccard <tree>` to verify

**Token awareness** — aim for:
- Realistic path (root→leaf): ~1200 tokens
- Worst case (all fire): ~4000 tokens
- Use `/ways-tests budget <tree>` to measure

**When NOT to tree**: Leave flat if <80 lines, single cohesive concern, or all content is needed together.

## Anti-Rationalization Patterns

For high-stakes ways where the agent is tempted to skip steps (testing, security, supply chain), add a "Common Rationalizations" table:

```markdown
## Common Rationalizations

| Rationalization | Counter |
|---|---|
| "This is simple, tests aren't needed" | If it's simple, the test is trivial. Write it. |
| "I'll add tests later" | Later never comes. Tests verify understanding NOW. |
```

**Placement**: In the specific leaf/mid-tier node, not the root. The table should only appear when the agent is actively doing the thing it might skip.

**Tone**: Direct, not preachy. State the fact. 5-7 rows max.

## Testing Your Way

Use `/ways-tests` and the `ways` CLI to validate matching quality. **Use the built-in tools — do not write ad-hoc scripts** for scoring, Jaccard, or vocabulary analysis.

- `/ways-tests score <way> "sample prompt"` — test a specific way
- `/ways-tests score-all "sample prompt"` — rank all ways against a prompt
- `/ways-tests suggest <way>` — analyze vocabulary gaps
- `/ways-tests lint <way>` — validate frontmatter
- `ways siblings <path>` — vocabulary overlap between siblings (Jaccard)
- `way-embed match --corpus ... --query "..."` — embedding similarity scores

**Tree validation**:
- `/ways-tests tree <path>` — structural analysis (depth, breadth, threshold progression)
- `/ways-tests budget <path>` — token cost per way, per path, worst-case
- `/ways-tests crowding "prompt"` — vocabulary overlap detection
- `/ways-tests metrics` — session disclosure tracking (after live use)

For vocabulary tuning workflows, see the optimization sub-way (triggers on vocabulary/optimization discussion).

Full authoring guide: `docs/hooks-and-ways/extending.md`

## Locale Stubs

Ways can have native-language matching stubs stored in `{wayname}.locales.jsonl` alongside the way file. These are packed JSONL — one line per language with `description` and `vocabulary` in the target language. The way body stays English.

```jsonl
{"lang":"ja","description":"セキュリティ脆弱性スキャン","vocabulary":"セキュリティ 脆弱性 CVE","embed_threshold":0.74}
```

Use `ways tune --apply` to auto-set thresholds, `ways tune --audit` to find ambiguous descriptions. Full guide: `docs/hooks-and-ways/languages.md`.

## See Also

- knowledge/authoring/tool-agnostic(meta) — ways describe intent, not tool calls
- knowledge/authoring/pii-free(meta) — privacy constraint on way content
- knowledge/optimization(meta) — vocabulary tuning, threshold auto-tuning, discrimination audit
