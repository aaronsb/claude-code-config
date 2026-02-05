---
trigger: context-threshold
threshold: 80
macro: prepend
scope: agent, subagent
---
# Memory Checkpoint

Context is filling up. Before compaction loses what you've learned, save insights to the project's persistent memory.

## What to Record

Write to `MEMORY.md` in the project's auto memory directory (path is in your system prompt). Keep it under 200 lines — link to other files in the directory for details.

**Worth recording:**
- Gotchas and workarounds specific to this codebase
- Patterns that worked (or didn't) for this project
- Project-specific tool/config quirks
- Which ways of working were useful here
- Decisions made and their rationale

**Not worth recording:**
- Generic knowledge you already have
- One-off context that won't recur
- Anything already captured in CLAUDE.md or project docs

## First Time?

If MEMORY.md is empty, seed it now. Even a few lines of project-specific context compounds across sessions. Structure suggestion:

```markdown
# Project Memory

## Codebase Patterns
- ...

## Gotchas
- ...

## Useful Ways
- ...
```
