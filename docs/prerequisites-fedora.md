# Prerequisites — Fedora / RHEL

```bash
sudo dnf install jq bc gzip python3 git
```

For the GitHub CLI (`gh`):

```bash
sudo dnf install 'dnf-command(config-manager)'
sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
sudo dnf install gh
```

**Already present on most Fedora/RHEL installs:** `bash`, `coreutils` (provides `timeout`, `tr`, `sort`, `wc`, etc.), `grep`, `awk`, `sed`, `gzip`, `find`

**Install Claude Code:**

```bash
npm install -g @anthropic-ai/claude-code
```

See the [Claude Code docs](https://docs.anthropic.com/en/docs/claude-code) for authentication setup.
