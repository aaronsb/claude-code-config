---
keywords: todo|tracking|multi.?session|cross.?session|picking.?up
files: \.claude/todo-.*\.md$
---
# Work Tracking Way

## TodoWrite (Session-Scoped)
- Maintains current task list in status bar
- Provides real-time visibility to collaborators
- Best for: active session tasks, quick progress tracking
- Mark tasks complete IMMEDIATELY after finishing

## Persistent Tracking Files (Cross-Session)

For complex, multi-session work, create files in `.claude/`:

```
.claude/
├── todo-adr-NNN-description.md   # ADR implementation
├── todo-pr-NNN.md                # PR work/review
├── todo-issue-NNN.md             # Issue resolution
```

**When to create:**
- ADR implementation spanning sessions
- Complex PR with multiple review cycles
- Multi-step issue resolution

**Format:**
```markdown
# ADR-081 Implementation: Source Lifecycle

## Completed
- [x] Phase 1: Pre-ingestion storage
- [x] Phase 2: Offset tracking

## Remaining
- [ ] Phase 3: Deduplication
- [ ] Phase 4: Regeneration
```

**Cleanup:**
When all items complete, recommend deleting the file. Git history preserves it. Don't let completed files accumulate.

## Relationship

| Aspect | TodoWrite | `.claude/todo-*.md` |
|--------|-----------|---------------------|
| Scope | Current session | Cross-session |
| Detail | Titles only | Rich context |
| Visibility | Status bar | Read on demand |

Use both: TodoWrite for active visibility, tracking files for continuity.
