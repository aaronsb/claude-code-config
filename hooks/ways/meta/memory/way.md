---
trigger: context-threshold
threshold: 80
pattern: \bremember\b|save.?(?:to|this|that).?memory|note.?(?:for|this).?(?:later|next)|don't forget|keep.?in.?mind
macro: prepend
scope: agent
---
# Memory

Memory is Claude Code's auto-memory — the `MEMORY.md` file and topic files in the project's memory directory. It persists across sessions. The first 200 lines of MEMORY.md load at every session start.

## When This Fires

This way fires in two contexts:

1. **User asks to remember something** — explicit request like "remember this" or "note this for later"
2. **Context threshold** — context is filling up and it's time to checkpoint before compaction

For explicit requests, just record what the user asked. For threshold checkpoints, apply the surprise test below.

## Surprise Test (threshold checkpoint only)

Did anything unexpected happen this session? A gotcha, a pattern that broke assumptions, a workaround you had to discover? If the session was routine — standard code, familiar patterns, no surprises — there's nothing new to record. Skip and keep working.

## What to Record

- Gotchas and workarounds specific to this codebase
- Patterns that worked (or didn't) for this project
- Project-specific tool/config quirks
- Decisions made and their rationale
- **Which ways helped and when** — reference the way path, note the context where it was useful beyond its static triggers

**Not worth recording:**
- Generic knowledge you already have
- One-off context that won't recur
- Anything already captured in CLAUDE.md or project docs
- Way content — never duplicate a way's guidance, just reference it

## Memory as Way References

Memory entries about ways should be pointers, not copies. Ways are structured, curated guidance. Memory records *experience* with that guidance:

```markdown
## Useful Ways
- `softwaredev/code/testing` — relevant when editing integration tests,
  not just when "test" keywords appear. --forked flag is essential in this repo.
- `softwaredev/delivery/commits` — always check before pushing to repos
  with pre-commit hooks; caught formatting issues in sessions 2 and 3.
```

This is progressive disclosure: ways hold the knowledge, memory indexes when and why it matters. Claude can `Read` any way file on demand — memory tells it *which ones to reach for* in context the triggers wouldn't catch.

## Writing Memory

Spawn a subagent (`subagent_type: "general-purpose"`) with your summary and the memory file path.

**Subagent prompt template:**

> Update project memory with session learnings.
>
> **Memory file:** [path from system prompt — the auto memory directory's MEMORY.md]
>
> **Session learnings to record:**
> [your summary or the user's explicit request]
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
> - [way path] — [when and why it helped beyond its triggers]
> ```
>
> Write the updated file. Return a summary of what you added or changed.
