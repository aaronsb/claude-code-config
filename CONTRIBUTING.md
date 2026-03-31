# Contributing

The recommended setup is to **fork this repo** and customize it for your own workflows. Add ways for your domain, tweak the triggers, build your own Lumon handbooks. Your fork stays yours.

When you build something that would benefit everyone — a new domain, a better trigger pattern, a macro that detects something clever — we'd love a PR back to upstream. The framework improves when people bring different workflows to it.

## Adding a Way

1. Create `hooks/ways/{domain}/{wayname}/{wayname}.md` with YAML frontmatter
2. Define your trigger: `pattern:` for regex, `match: semantic` for fuzzy matching
3. Write compact, actionable guidance (every token costs context)
4. Test it: trigger the pattern and verify the guidance appears once

See [docs/hooks-and-ways/extending.md](docs/hooks-and-ways/extending.md) for the full guide.

## Reporting Bugs

Open an issue. Include which hook or way is involved, your OS/shell, and any error output.

## Pull Requests

- Keep changes focused — one way or one fix per PR
- Test your trigger patterns against both positive and negative cases
- If adding a new domain, include a brief rationale in the PR description

## Code Style

**Hooks and macros** are bash. Keep them portable (macOS bash 3.2 compatible — no `declare -A`, no `mapfile`, no `grep -P`), use `shellcheck` if available, and keep scripts under 200 lines where possible. Hook scripts should be thin dispatchers to the `ways` binary.

**The `ways` binary** is Rust (`tools/ways-cli/`). Run `cargo test` before submitting changes. See [ADR-111](docs/architecture/system/ADR-111-unified-ways-cli-single-binary-tool-consolidation.md) for the consolidation rationale.

## Gitignore: Exclusive by Design

The `.gitignore` uses an **exclusive pattern**: `*` (ignore everything) with explicit `!` exceptions for tracked files. This is intentional, not lazy.

This repo *is* `~/.claude/` — the directory that controls how Claude Code thinks and acts. Every file here can influence agent behavior: hooks execute shell commands, ways inject guidance, CLAUDE.md steers reasoning, settings.json controls permissions. An accidental commit of a malicious or poorly-written file could steer Claude to do undesirable things for anyone who pulls it.

The exclusive gitignore ensures:
- **No accidental file inclusion.** New files must be explicitly opted in via `.gitignore`. You can't push a file you didn't mean to track.
- **Clear audit surface.** `git diff .gitignore` shows exactly what's tracked. Reviewers can see the full inclusion list in one place.
- **Defense against ignorance and malice.** Both well-meaning contributors who don't realize their file will affect Claude's behavior, and adversarial PRs that try to slip in steering content.

When adding a new tracked file, add a `!filename` or `!path/` exception to `.gitignore` and explain why it needs to be tracked in your PR description.
