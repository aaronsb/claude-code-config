# Prerequisites — Arch Linux

```bash
sudo pacman -S jq bc gzip python git
```

For the GitHub CLI (`gh`):

```bash
sudo pacman -S github-cli
```

**Already present on most Arch installs:** `bash`, `coreutils` (provides `timeout`, `tr`, `sort`, `wc`, etc.), `grep`, `awk`, `sed`, `gzip`, `find`

> `bc` is not part of `base` — if you're on a minimal install, make sure it's there.

**Install Claude Code:**

```bash
npm install -g @anthropic-ai/claude-code
```

See the [Claude Code docs](https://docs.anthropic.com/en/docs/claude-code) for authentication setup.
