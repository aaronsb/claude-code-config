---
pattern: magic.?wormhole|install.*wormhole|wormhole.*install
scope: agent, subagent
---
# Installing magic-wormhole

## Check First

```bash
command -v wormhole 2>/dev/null && wormhole --version 2>&1
```

If already installed, say so and move on.

## Detect Platform and Install

```bash
uname -s  # Darwin = macOS, Linux = check distro
```

For Linux, identify the distro:

```bash
cat /etc/os-release 2>/dev/null | grep -E '^(ID|ID_LIKE)='
```

| Platform | Command |
|----------|---------|
| Arch Linux | `sudo pacman -S magic-wormhole` |
| macOS (Homebrew) | `brew install magic-wormhole` |
| Debian / Ubuntu | `sudo apt install magic-wormhole` |
| Fedora | `sudo dnf install magic-wormhole` |
| pip (fallback) | `pip install magic-wormhole` |

Use `AskUserQuestion` to confirm the detected install method before running it. If the platform doesn't match any of the above, suggest pip as a fallback or direct the user to https://github.com/magic-wormhole/magic-wormhole.

## After Install

Verify:

```bash
wormhole --version
```
