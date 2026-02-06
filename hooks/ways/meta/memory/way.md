---
trigger: context-threshold
threshold: 80
macro: prepend
scope: agent
---
# Memory Checkpoint

Context is filling up. Before acting on this, apply the surprise test: did anything unexpected happen this session? A gotcha you hit, a pattern that broke assumptions, a workaround you had to discover? If the session was routine — standard code, familiar patterns, no surprises — then there's nothing new to record. Skip this and keep working.

The threshold is surprise: something that would trip up the next session if it wasn't written down.

## Part 1: You Summarize (main agent)

If something *was* surprising, you have the session history — a subagent does not. Compile a concise list of what's worth persisting:

- Gotchas and workarounds specific to this codebase
- Patterns that worked (or didn't) for this project
- Project-specific tool/config quirks
- Decisions made and their rationale

**Not worth recording:**
- Generic knowledge you already have
- One-off context that won't recur
- Anything already captured in CLAUDE.md or project docs

If nothing clears the bar, say so and skip the subagent.

## Part 2: Subagent Writes Memory

Spawn a subagent (`subagent_type: "general-purpose"`) with your summary and the memory file path.

**Subagent prompt template:**

> Update project memory with session learnings.
>
> **Memory file:** [path from system prompt — the auto memory directory's MEMORY.md]
>
> **Session learnings to record:**
> [your summary from Part 1]
>
> **Your tasks:**
>
> 1. Read the current MEMORY.md (may be empty or have prior content)
> 2. Merge the new learnings into the existing structure — don't duplicate, don't overwrite useful existing content
> 3. Keep MEMORY.md under 200 lines. If it's getting long, create topic files in the same directory and link from MEMORY.md
> 4. Use this structure if starting fresh:
>
> ```markdown
> # Project Memory
>
> ## Codebase Patterns
> - ...
>
> ## Gotchas
> - ...
>
> ## Useful Ways
> - ...
> ```
>
> Write the updated file. Return a summary of what you added or changed.
