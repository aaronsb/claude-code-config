---
keywords: github|\ issue|pull.?request|\ pr\ |\ pr$|review.?(pr|comment)|merge.?request
commands: ^gh\ |^gh$
macro: prepend
---
# GitHub Way

## When User Mentions GitHub

**Trigger words**: "issue", "PR", "pull request", "review", "comments", "checks"

**If ambiguous, clarify**:
- "Do you mean a GitHub issue, or a problem to investigate?"
- "Should I check GitHub PRs/issues, or look in the code?"

## Common Commands

```bash
# Finding issues
gh issue list --search "keyword"
gh issue list --label bug
gh issue view 123

# PR operations
gh pr view                    # Current branch PR
gh pr view 42                 # Specific PR
gh pr checks                  # CI/test status
gh pr view --comments         # Review comments

# Creating PRs
gh pr create --title "feat: Description" \
  --body "## Changes\n- Item 1\n- Item 2"

# ADR PRs
gh pr create --title "ADR-003: Decision Title" \
  --body "## Context\n\n## Decision\n\n## Consequences"
```

## Pattern: GitHub First

```bash
# 1. Check if GitHub is available
gh repo view > /dev/null 2>&1

# 2. If success, use gh commands
# 3. If fail, fall back to file search
```

## What to Use
- **Issues**: Optional, for requirements/discussions/bugs
- **PRs**: Required, for ADR and code review
- **Labels**: Basic set (bug, enhancement, documentation)

## What to Avoid
- Complex project boards
- Elaborate milestone hierarchies
- Over-labeled issues
