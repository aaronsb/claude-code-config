---
name: ship
description: Ship current work through the branch → commit → push → PR → merge → cleanup flow. Picks up wherever you are in the cycle. Use when the user says "ship it", "land this", "merge this", or invokes /ship.
allowed-tools: Bash, Read, Grep, Glob
---

# Ship Workflow

Deliver current work to main. Assess the current state and pick up from wherever the user is.

## Assess First

Run these in parallel to determine current position in the flow:

```bash
git status --short              # Uncommitted changes?
git branch --show-current       # On main or a feature branch?
git log --oneline main..HEAD    # Commits ahead of main?
git remote show origin 2>&1     # Remote tracking state?
```

## Flow Steps (skip what's already done)

### 1. Branch (if on main with changes)

```bash
git checkout -b <branch-name>
```

Pick a name from the changes: `feature/thing`, `fix/thing`, `refactor/thing`.
If the user provides a name, use it. If changes are already committed on main,
create the branch first, then it carries the commits.

### 2. Commit (if uncommitted changes)

Stage and commit. Follow conventional commit format.
If there are multiple logical changes, make multiple atomic commits.
Ask the user for a commit message direction if the intent isn't clear.

### 3. Push

```bash
git push -u origin <branch>
```

### 4. PR

```bash
gh pr create --title "..." --body "$(cat <<'EOF'
## Summary
...

## Test plan
...
EOF
)"
```

Keep the title under 70 characters. Summary should be 1-3 bullets.
For small/obvious changes, the test plan can be brief.

### 5. Review (scope-dependent)

- **Trivial** (typos, config, single-file): skip review, merge directly
- **Small** (1-3 files, clear intent): quick self-review of the diff is enough
- **Significant** (architecture, multi-file, behavioral): suggest the user review or request a reviewer

State your assessment and let the user decide.

### 6. Merge

```bash
gh pr merge <number> --merge
```

Use `--merge` (not squash or rebase) unless the user prefers otherwise.

### 7. Cleanup

```bash
git checkout main && git pull
```

Git typically prunes the remote tracking ref on pull after merge.
If the local branch lingers:

```bash
git branch -d <branch>
```

## Key Principles

- **Don't ask permission for each step** — assess state, propose the full remaining flow, then execute
- **Pause only at decision points**: commit message wording, PR description, review scope
- **If already mid-flow**, pick up from current state — don't restart
- **One commit is fine** for most changes; only split if there are genuinely separate concerns
