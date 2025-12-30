---
keywords: readme|documentation|docs|document.*project|explain.*repo
files: README\.md$|docs/.*\.md$
---
# Documentation Way

## README Philosophy

**Gist first.** A reader should understand what this is and why it exists within 30 seconds.

**Scale to complexity.** Simple project = simple README. Complex project = README + docs tree.

## README Anti-Patterns

- **Monolith** - Everything in one massive file
- **Installation-first** - Burying the "what" under "how to install"
- **No context** - Assuming reader knows what problem this solves
- **Over-documenting simple things** - 500 lines for a utility script

## README Structure

```markdown
# Project Name

One sentence: what it is.

One paragraph: why it exists, what problem it solves.

## Quick Start (if applicable)
Minimal steps to see it work.

## [More sections as needed]
Keep README focused. Link to docs/ for depth.
```

## When to Use docs/

| Complexity | Documentation |
|------------|---------------|
| Script/utility | README only |
| Small library | README + examples |
| Application | README + docs/ tree |
| Platform | README + docs/ + guides + API docs |

## docs/ Structure (when needed)

```
docs/
├── getting-started.md
├── configuration.md
├── guides/
│   └── specific-workflows.md
└── reference/
    └── api.md
```

## Principles

- **Progressive disclosure** - Overview → Details → Deep dives
- **Task-oriented** - Organize by what people want to do
- **Keep README current** - Outdated README = broken front door
