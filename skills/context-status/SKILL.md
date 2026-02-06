---
name: context-status
description: Check how much context window remains in this session. Use when you want to know token budget, context usage, or how much room is left before compaction. Also use proactively when working on long tasks to gauge remaining capacity.
allowed-tools: Bash
---

# Context Status

Run this to check your remaining context window budget:

```bash
~/.claude/scripts/context-usage.sh "${CLAUDE_PROJECT_DIR:-$PWD}"
```

Report the result to the user in plain language, e.g.:

> "About 98k tokens remaining (50% of the 200k window)."

If the remaining percentage is below 20%, mention that compaction is approaching and suggest wrapping up or prioritizing remaining work.
