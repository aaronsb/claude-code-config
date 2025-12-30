#!/bin/bash
# Dynamic context for GitHub way
# Detects project type (solo vs team) and suggests appropriate workflow

# Early exit if not a GitHub repo
gh repo view &>/dev/null || {
  echo "**Note**: Not a GitHub repository - GitHub commands won't work"
  exit 0
}

# Get contributor count with timeout
CONTRIBUTORS=$(timeout 2 gh api repos/:owner/:repo/contributors --jq 'length' 2>/dev/null)

if [[ -z "$CONTRIBUTORS" ]]; then
  echo "**Note**: Could not reach GitHub API"
  exit 0
fi

CURRENT_USER=$(gh api user --jq '.login' 2>/dev/null)

if [[ "$CONTRIBUTORS" -le 2 ]]; then
  echo "**Context**: Solo/pair project ($CONTRIBUTORS contributors)"
  echo "- PR optional for small changes"
  echo "- Direct merge to main acceptable"
  echo "- Consider asking: \"Create PR or merge directly?\""
else
  # Get top reviewers excluding current user
  REVIEWERS=$(gh api repos/:owner/:repo/contributors --jq '.[0:5][].login' 2>/dev/null | grep -v "$CURRENT_USER" | head -3 | tr '\n' ', ' | sed 's/,$//')
  echo "**Context**: Team project ($CONTRIBUTORS contributors)"
  echo "- PR recommended for all changes"
  if [[ -n "$REVIEWERS" ]]; then
    echo "- Potential reviewers: $REVIEWERS"
  fi
fi
