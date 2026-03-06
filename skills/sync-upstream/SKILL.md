---
name: sync-upstream
description: Sync fork with upstream (aaronsb/claude-code-config). Fetches upstream/main, shows what's new, and merges into your current branch or main. Handles conflicts by preserving local fixes. Use when the user says "sync upstream", "pull upstream", "update from upstream", or invokes /sync-upstream.
allowed-tools: Bash, Read, Grep, Glob
---

# Sync Upstream

Integrate changes from the upstream repo (aaronsb/claude-code-config) into this fork.

## Assess First

Run these in parallel to understand current state:

```bash
git remote -v                          # Verify upstream is configured
git branch --show-current              # What branch are we on?
git status --short                     # Any uncommitted work?
git log --oneline upstream/main..main  # Local-only commits (our fixes)
```

### If upstream remote is missing

```bash
git remote add upstream https://github.com/aaronsb/claude-code-config.git
```

## Flow

### 1. Stash uncommitted work (if any)

```bash
git stash push -m "sync-upstream: stash before merge"
```

### 2. Fetch upstream

```bash
git fetch upstream
```

### 3. Show what's incoming

```bash
git log --oneline main..upstream/main
```

If nothing new, report "already up to date" and stop.

### 4. Show divergence

```bash
git log --oneline upstream/main..main   # Our local-only commits
git log --oneline main..upstream/main   # Incoming from upstream
```

Report both sides so the user sees the full picture.

### 5. Merge upstream into main

If on a feature branch, switch to main first:

```bash
git checkout main
git merge upstream/main
```

If conflicts arise:

- **bin/way-match**: Keep ours (`git checkout --ours bin/way-match`). Upstream ships a Linux ELF; we need the arm64 macOS binary. After resolving, rebuild with `make -f tools/way-match/Makefile local` to ensure we have the latest source compiled natively.
- **tools/way-match/test-harness.sh** or **test-integration.sh**: Inspect carefully. If upstream added new test cases, incorporate them into our bash 3.2 compatible version. Don't accept upstream's `declare -A` or `mapfile` patterns.
- **Other files**: Accept upstream's version unless we have intentional local changes.

After resolving all conflicts:

```bash
git add <resolved-files>
git commit   # Accept or adjust the merge commit message
```

### 6. Push to origin

```bash
git push origin main
```

### 7. Rebase feature branch (if we were on one)

If the user was on a feature branch before sync:

```bash
git checkout <branch>
git rebase main
```

### 8. Restore stashed work (if any)

```bash
git stash pop
```

## Key Principles

- **Show the diff summary before merging** — let the user see what's incoming
- **Preserve local platform fixes** — our arm64 binary and bash 3.2 compat are intentional divergences
- **If upstream changed way-match.c source**, rebuild locally after merge: `make -f tools/way-match/Makefile local`
- **Don't force-push main** — always fast-forward or merge
- **Report what happened** — summarize commits integrated, conflicts resolved, and current state
