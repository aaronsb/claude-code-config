---
keywords: commit|push.*(remote|origin|upstream)
commands: git\ commit
---
# Git Commits Way

## Conventional Commit Format

- `feat(scope): description` - New features
- `fix(scope): description` - Bug fixes
- `docs(scope): description` - Documentation
- `refactor(scope): description` - Code improvements
- `test(scope): description` - Tests
- `chore(scope): description` - Maintenance

## Branch Names

- `adr-NNN-topic` - Implementing an ADR
- `feature/name` - New feature work
- `fix/issue` - Bug fixes
- `refactor/area` - Code improvements

## Rules

- Skip "Co-Authored-By" and emoji trailers
- Focus commit message on the "why" not the "what"
- Keep commits atomic - one logical change per commit
