# Matching Modes

How ways decide when to fire.

## Overview

Each way declares a matching strategy in its YAML frontmatter. The strategy determines what input is tested and how similarity is measured.

| Mode | Speed | Precision | Best For |
|------|-------|-----------|----------|
| **Regex** | Fast | Exact | Known keywords, command names, file patterns |
| **Semantic (BM25)** | Fast | Fuzzy | Broad concepts that users describe many ways |
| **State** | Fast | Conditional | Session conditions, not content matching |

Matching is **additive**: a way can have both pattern and semantic triggers. Either channel firing activates the way.

## Regex Matching

The default and most common mode. Three fields can be tested independently:

- `pattern:` - tested against the user's prompt text
- `commands:` - tested against bash commands (PreToolUse:Bash)
- `files:` - tested against file paths (PreToolUse:Edit|Write)

A way can declare any combination. Each field is a standard regex evaluated case-insensitively against its input.

### Why regex is the default

Most ways have clear trigger words. "commit", "refactor", "ssh" - these don't need fuzzy matching. Regex is fast, predictable, and easy to debug. When a way misfires, you can read the pattern and understand why.

### Pattern design considerations

Patterns need to balance sensitivity and specificity:
- Too broad: `error` fires on "no errors found"
- Too narrow: `error_handling` misses "exception handling"
- Right: `error.?handl|exception|try.?catch` catches the concept without false positives

Word boundaries (`\b`) help with short words that appear inside other words. The `commits` way uses `\bcommit\b` to avoid matching "committee" or "commitment".

## Semantic Matching

For concepts that users express in varied language. "Make this faster", "optimize the query", "it's too slow" all mean the same thing but share few words.

### How it works

A way with `description:` and `vocabulary:` frontmatter fields is automatically eligible for semantic matching. The `description` provides natural language context; the `vocabulary` provides domain-specific keywords. These are combined and scored against the user's prompt using BM25 (Okapi BM25 with Porter2 stemming).

```yaml
description: debugging code issues, troubleshooting errors, investigating broken behavior
vocabulary: debug breakpoint stacktrace investigate troubleshoot regression bisect crash error
threshold: 2.0
```

### Degradation chain

Semantic matching uses a three-tier degradation chain:

1. **BM25 binary** (`~/.claude/bin/way-match`) — fast, preferred. Scores description+vocabulary against prompt with Porter2 stemming and IDF weighting.
2. **Gzip NCD fallback** — if the binary isn't available, falls back to Normalized Compression Distance using `gzip`. Measures structural similarity between texts. Uses a fixed threshold (0.58) since NCD and BM25 scales don't map cleanly.
3. **Skip** — if neither BM25 nor gzip+bc are available, semantic matching is silently skipped. Pattern matching still works.

### Vocabulary design

Good vocabulary terms are domain-specific words that **users would say** when asking about the topic:

- **Include**: Terms users type in prompts — `bcrypt`, `xss`, `breakpoint`, `monolith`
- **Skip**: Generic terms that don't discriminate — `code`, `use`, `make`, `change`
- **Keep unused terms**: Vocabulary terms that don't appear in the way body are often intentional — they catch user prompts, not body text

Use `/test-way suggest <way>` to find gaps and `/test-way score-all "prompt"` to check for cross-way false positives.

### Sparsity over coverage

The goal of vocabulary design isn't to maximize each way's match rate — it's to maximize the semantic distance *between* ways. Each way should occupy a distinct region of the scoring space with minimal overlap. When a prompt fires exactly one way with a clear margin above others, the system is working well. When multiple ways fire on the same prompt, their vocabularies overlap and need sharpening.

This means expanding vocabulary can be counterproductive. Adding generic terms like `error` to the debugging way might catch more debugging prompts, but it also creates overlap with the errors way. Narrow, specific vocabulary creates sparsity — clean separation between ways — which is more valuable than broad recall on any single way.

### Which ways use semantic matching

Ways covering broad concepts where keyword matching would be either too narrow or too noisy:
- `testing` (2.0) — unit tests, TDD, mocking, coverage
- `api` (2.0) — REST APIs, endpoints, HTTP, versioning
- `debugging` (2.0) — debugging, troubleshooting, investigation
- `security` (2.0) — authentication, secrets, vulnerabilities
- `design` (2.0) — architecture, patterns, schema, modeling
- `config` (2.0) — environment variables, dotenv, configuration
- `adr-context` (2.0) — planning, approach decisions, context
- `knowledge/optimization` (2.0) — vocabulary tuning, way health analysis

All use threshold 2.0. The test harness maintains 0 false positives as a hard constraint.

## State Triggers

Unlike the other modes, state triggers don't match against content. They evaluate session conditions.

### context-threshold

Monitors transcript size as a proxy for context window usage. The calculation:
- Claude's context window: ~155K tokens
- Estimated density: ~4 characters per token
- Total capacity: ~620K characters
- Threshold at 75%: fires when transcript exceeds ~465K characters

The transcript size is measured since the last compaction (identified by `"type":"summary"` markers in the transcript JSONL). A cache avoids rescanning the full transcript on every prompt.

Unlike other ways, context-threshold triggers **repeat on every prompt** until the condition is resolved (task list created). This is deliberate: it's an enforcement mechanism, not educational guidance.

### file-exists

Checks for a glob pattern relative to the project directory. Fires once (standard marker) if any matching file exists. Useful for detecting project state - e.g., whether tracking files exist.

### session-start

Always evaluates true. Uses the standard marker, so it fires exactly once on the first UserPromptSubmit after session start. Useful for one-time session initialization that doesn't belong in SessionStart hooks.
