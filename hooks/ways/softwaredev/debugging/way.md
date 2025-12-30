---
keywords: debug|bug|broken|investigate|troubleshoot|not.?working
---
# Debugging Way

## Systematic Approach
1. **Reproduce** - Can you trigger it reliably?
2. **Isolate** - What's the smallest case that fails?
3. **Hypothesize** - What could cause this?
4. **Test** - Verify one hypothesis at a time
5. **Fix** - Change one thing, confirm it works

## Common Traps
- Changing multiple things at once
- Assuming you know the cause without evidence
- Fixing symptoms instead of root cause
- Not checking the obvious first (typos, config, versions)

## Tools
- Print/log statements (shameless but effective)
- Debugger breakpoints
- Git bisect for regressions
