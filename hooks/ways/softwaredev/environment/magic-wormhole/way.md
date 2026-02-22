---
description: file transfer between computers, sharing files across machines, magic-wormhole setup and usage
vocabulary: transfer file send receive share wormhole between computers machines cross-machine exchange relay
threshold: 2.0
pattern: magic.?wormhole|install.*wormhole|wormhole.*install
scope: agent, subagent
---
# File Transfer with magic-wormhole

## When to Suggest Wormhole

| Scenario | Tool |
|----------|------|
| Ad-hoc transfer between two machines, no prior setup | **wormhole** |
| Recurring transfers, SSH already configured | scp, rsync |
| Transfer within same machine or LAN with shared filesystem | cp, rsync |
| Transfer to/from cloud storage | provider CLI (aws s3, gsutil, etc.) |

Wormhole is the right tool when:
- No SSH keys or shared accounts exist between the machines
- The transfer is a one-off or infrequent
- Simplicity matters more than throughput
- The sender and receiver are both at a terminal (or running Claude)

## Cross-Agent File Exchange

Two Claude instances on different machines can exchange files via wormhole if a human facilitates the initial code handshake:

1. **Machine A**: Claude runs `wormhole send --hide-progress <path>`, gets a code
2. **Human**: copies the code from A's output to B's session
3. **Machine B**: Claude runs `wormhole receive --accept-file --hide-progress -o <dir> <code>`

With `--code`, a predetermined code can skip the relay step — both sides just need to agree on the code in advance. The human only needs to start both sides.

The `/wormhole` skill handles both interactive and automated modes.

## Installation

```bash
command -v wormhole 2>/dev/null && wormhole --version 2>&1
```

If missing, detect the platform:

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

After install, verify:

```bash
wormhole --version
```
