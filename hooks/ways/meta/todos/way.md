---
trigger: context-threshold
threshold: 75
---
# Todo Management

## Two Systems, One Goal

| TodoWrite | `.claude/todo-*.md` |
|-----------|---------------------|
| Session-scoped | Cross-session |
| Status bar visibility | Read on demand |
| Survives compaction well | Persistence across sessions |

**Use both:** TodoWrite for active visibility, tracking files for continuity.

## Context Checkpoint

You're approaching compaction. Task lists survive compaction and provide continuity.

**If no active task list exists:** Create one now using TodoWrite. Capture:
- What we're working on (the goal)
- Current progress (what's done)
- Next steps (what remains)
- Any decisions or constraints established

**If task list exists:** Verify it reflects current state - update stale items, add discovered work.

This is not optional. Task lists are the primary continuity mechanism across compaction.

## Avoiding Intent Drift

The plan evolves as you build. When completing items:
- Verify remaining items still serve the original goal
- Remove stale items, add discovered needs
- Three stale items are worse than one right item

## Autonomy Balance

Complete items autonomously. Sync with user at natural checkpoints:
- Major feature complete
- Unexpected complexity emerged
- Direction needs to change

Not approval-seeking. Alignment-checking.
