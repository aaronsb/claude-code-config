# Prerequisites — Debian / Ubuntu

```bash
sudo apt install jq bc gzip python3 git
```

For the GitHub CLI (`gh`):

```bash
# See https://github.com/cli/cli/blob/trunk/docs/install_linux.md
sudo mkdir -p -m 755 /etc/apt/keyrings
wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install gh
```

**Already present on most Debian/Ubuntu installs:** `bash`, `coreutils` (provides `timeout`, `tr`, `sort`, `wc`, etc.), `grep`, `awk`, `sed`, `gzip`, `find`

**Install Claude Code:**

```bash
npm install -g @anthropic-ai/claude-code
```

See the [Claude Code docs](https://docs.anthropic.com/en/docs/claude-code) for authentication setup.
