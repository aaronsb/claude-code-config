# Prerequisites — macOS

Install via [Homebrew](https://brew.sh/):

```bash
brew install jq gh python3 coreutils
```

`coreutils` provides GNU `timeout`, which several hook scripts use. By default Homebrew installs it as `gtimeout`. To make it available as `timeout`, add gnubin to your PATH:

```bash
# Add to ~/.zshrc or ~/.bash_profile
export PATH="$(brew --prefix coreutils)/libexec/gnubin:$PATH"
```

**Already present on macOS:** `git` (via Xcode CLT), `bash`, `gzip`, `bc`, `grep`, `awk`, `sed`

> If you don't have Xcode Command Line Tools: `xcode-select --install`

**Install Claude Code:**

```bash
npm install -g @anthropic-ai/claude-code
```

See the [Claude Code docs](https://docs.anthropic.com/en/docs/claude-code) for authentication setup.
