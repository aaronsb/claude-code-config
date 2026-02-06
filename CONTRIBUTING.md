# Contributing

This is a personal project that's open source because other people might find it useful. Contributions are welcome, especially new ways for domains beyond software development.

## Adding a Way

1. Create `hooks/ways/{domain}/{wayname}/way.md` with YAML frontmatter
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

It's all bash. Keep it portable (no bashisms that break on macOS default bash 3.2), use `shellcheck` if available, and keep scripts under 200 lines where possible.
