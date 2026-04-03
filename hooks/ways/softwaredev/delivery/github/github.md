---
description: GitHub pull requests, issues, code review, CI checks, repository management
vocabulary: pr pullrequest issue review checks ci label milestone fork repository upstream draft ship land merge
threshold: 2.0
pattern: github|\ issue|pull.?request|\ pr\ |\ pr$|review.?(pr|comment)|merge.?request|ship.?(it|this|the)|land.?(it|this)|merge.?(it|this)
commands: ^gh\ |^gh$
redisclose: 10
macro: prepend
scope: agent, subagent
---
<!-- epistemic: convention -->
# GitHub Way

## Pull Requests — Always

We use PRs for all changes, including solo projects. A PR without reviewers still has value — it's a decision record, a CI gate, and muscle memory for when the project grows. Working solo without PRs is like doing research without keeping notes.

- **Solo/pair**: Lightweight PRs — a title and a few bullets is enough
- **Team**: Full PR with context, reviewers, and linked issues
- **Team (3+ contributors)**: Consider enabling [Claude Code Review](https://claude.com/blog/code-review) — automated multi-agent PR analysis that catches bugs skimmed reviews miss. $15-25/review, Team/Enterprise plans, org spending caps available

## Code Review Before Merge

After creating a PR, offer to spawn a `code-reviewer` subagent to review it before merging. This is the default workflow — don't wait for the user to request it.

## Post-Merge Cleanup

After merging a PR, always run the full cleanup: `git checkout main && git pull && git fetch --prune`, then `git branch -d <branch>`. Stale branches accumulate fast — clean up every time.

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

## What to Use
- **PRs**: Always — lightweight for solo, thorough for teams
- **Issues**: Optional, for requirements/discussions/bugs
- **Labels**: Basic set (bug, enhancement, documentation)

## Repo Health

The macro checks repository configuration (README, license, templates, branch protection, badges, etc.) and reports what's missing. If the report shows gaps:
- Offer to help configure items the user has rights to fix
- For items needing admin access, note them but don't push
- When badges are missing, suggest adding shields.io badges below the README title (license, stars, version)

## What to Avoid
- Complex project boards
- Elaborate milestone hierarchies
- Over-labeled issues

## See Also

- delivery/commits(softwaredev) — PR quality depends on commit quality
- architecture/adr(softwaredev) — reference ADRs in PR descriptions
