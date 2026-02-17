# Code Lifecycle Ways

Guidance for the journey from local changes to published releases.

## Commits

**Triggers**: Prompt mentions "commit" or "push to remote"; running `git commit`

Enforces conventional commit format (`feat:`, `fix:`, `docs:`, etc.) with optional scopes. The rationale is automated changelog generation and semantic version inference - if every commit follows the convention, the release process can determine whether the next version is a major, minor, or patch bump without human judgment.

Key positions:
- **Atomic commits** - one logical change per commit. Mixed changes ("fix login and also update deps") make bisect useless and reverts dangerous.
- **"Why" over "what"** - the diff shows what changed. The commit message should explain why. "Fix race condition in session cleanup" beats "Update session.py".
- **Branch naming** - `{type}/{short-description}` matching commit types. Keeps the mental model consistent across git log and branch list.

## Patches

**Triggers**: Prompt mentions "patch" or "diff"; editing `.patch`/`.diff` files; running `git apply` or `git diff >file`

The core rule is simple: never hand-write patches. Always generate them from real, tested changes using `git diff` or `git format-patch`. Hand-written patches bypass the normal edit-test-commit cycle and are error-prone.

For multi-step changes, the way prescribes patch series with cumulative semantics (each patch applies on top of the previous) rather than independent patches (which can conflict).

## Release

**Triggers**: Prompt mentions "release", "changelog", "version bump", "tag"

Automates two things that are tedious and error-prone when done manually:

1. **Changelog generation** - `git log` since the last tag, formatted as Keep a Changelog sections (Added, Changed, Fixed, Removed).
2. **Version inference** - scan commit prefixes since last tag. Any `feat!:` or `BREAKING CHANGE` = major. Any `feat:` = minor. Only `fix:`/`docs:`/`chore:` = patch.

The way deliberately avoids prescribing release process steps (deploy, announce, etc.) and focuses on artifacts that Claude can actually produce.

## GitHub

**Triggers**: Prompt mentions "issue", "pull request", "PR"; running `gh` commands

**Macro**: Detects solo vs team project via GitHub API contributor count.

Establishes `gh` CLI as the primary interface for GitHub operations. The rationale: `gh` provides authenticated, structured access to issues, PRs, checks, and releases without leaving the terminal. It's faster than the web UI and scriptable.

Key positions:
- **GitHub-first** - check issues/PRs before starting work. Someone may have already solved the problem or documented constraints.
- **PR formality scales with team size** - solo projects don't need formal PRs for every change. Team projects benefit from the review checkpoint.
- **CLI over API** - `gh pr create`, `gh issue list`, etc. rather than raw `gh api` calls where possible.
