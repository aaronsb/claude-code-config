---
keywords: dependenc|package|library|npm.?install|pip.?install|upgrade.*version
commands: npm\ install|yarn\ add|pip\ install|cargo\ add|go\ get
---
# Dependencies Way

## Before Adding
- Do we really need this? Could we write it simply?
- Is it maintained? Check last commit, open issues
- How big is it? Check bundle size impact
- What's the license?

## When Updating
- Read the changelog for breaking changes
- Update one at a time when debugging issues
- Pin versions in production
- Test after updating

## Security
- Run `npm audit` / `pip check` / equivalent
- Don't ignore vulnerability warnings
- Keep dependencies reasonably current
