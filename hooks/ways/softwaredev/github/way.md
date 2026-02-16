---
match: regex
pattern: github|\ issue|pull.?request|\ pr\ |\ pr$|review.?(pr|comment)|merge.?request
commands: ^gh\ |^gh$
macro: prepend
scope: agent, subagent
provenance:
  policy:
    - uri: docs/hooks-and-ways/softwaredev/code-lifecycle.md
      type: governance-doc
  controls:
    - id: SOC 2 CC8.1 (Change Management)
      justifications:
        - PR-always stance ensures all changes pass through a reviewable change management gate
        - Solo PRs still serve as decision records and CI gates even without reviewers
        - Tiered PR depth (lightweight for solo, thorough for teams) scales change management to context
    - id: NIST SP 800-53 CM-3 (Configuration Change Control)
      justifications:
        - PR as change record creates immutable audit trail of what changed and why
        - CI checks on PRs implement automated configuration change verification
        - Repo health macro detects missing configuration controls (branch protection, templates)
    - id: ISO/IEC 27001:2022 A.8.32 (Change Management)
      justifications:
        - PR workflow (create → review → merge) implements formal change management process
        - Issue tracking provides requirements traceability for changes
  verified: 2026-02-09
  rationale: >
    PR-always stance implements CC8.1 change management even for solo projects. PR-as-record
    with CI gates satisfies CM-3 automated change verification. Repo health checks detect
    gaps in A.8.32 change management infrastructure.
---
# GitHub Way

## Pull Requests — Always

We use PRs for all changes, including solo projects. A PR without reviewers still has value — it's a decision record, a CI gate, and muscle memory for when the project grows. Working solo without PRs is like doing research without keeping notes.

- **Solo/pair**: Lightweight PRs — a title and a few bullets is enough
- **Team**: Full PR with context, reviewers, and linked issues

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
