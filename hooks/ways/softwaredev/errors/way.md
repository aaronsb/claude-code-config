---
keywords: error.?handl|exception|try.?catch|throw|catch
---
# Error Handling Way

## When to Catch
- You can actually handle/recover from it
- You need to translate it (wrap with context)
- At system boundaries (API endpoints, CLI entry)

## When to Propagate
- You can't meaningfully handle it
- Caller needs to know about it
- It's a programmer error (bug)

## Good Error Messages
- What went wrong
- Why it went wrong (if known)
- How to fix it (if possible)

## Patterns
- Fail fast for programmer errors
- Graceful degradation for operational errors
- Log at the boundary, not everywhere
- Don't swallow errors silently
