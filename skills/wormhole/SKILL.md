---
name: wormhole
description: Send and receive files, directories, or text between computers using magic-wormhole. Guides the user through the transfer interactively. Use when the user says "wormhole", "send a file", "receive a file", or invokes /wormhole.
allowed-tools: Bash, Read, Glob, AskUserQuestion
---

# Magic Wormhole File Transfer

Secure, simple transfers between computers using magic-wormhole codes.

## Step 0: Check Installation

```bash
command -v wormhole 2>/dev/null && echo "installed" || echo "missing"
```

If missing, tell the user magic-wormhole needs to be installed first. The `softwaredev/environment/magic-wormhole` way has platform detection and install instructions — it triggers on "installing magic-wormhole". Stop the skill flow until installation succeeds.

## Step 1: Determine Mode

There are two modes depending on who is running the skill:

- **Interactive** — a human is in the loop. Use `AskUserQuestion` for choices, plain text for free-form values (codes, text content).
- **Automated** — a subagent is running this. All parameters (path, code, destination) must be provided in the prompt. No elicitation, no blocking waits for human input.

If you are a subagent, skip all `AskUserQuestion` calls and use the parameters from your task prompt directly.

## Step 2: Ask What They Want To Do

**Interactive**: Use `AskUserQuestion`:

- **Send a file** — transfer a file to another machine
- **Send a directory** — transfer an entire directory (sent as zip)
- **Send text** — send a short text snippet
- **Receive** — receive an incoming transfer using a wormhole code

**Automated**: The operation, path/code, and destination must be specified in the task prompt.

---

## Send Flow

### Determine what to send

**Interactive**: Use `AskUserQuestion` to get the transfer target. If the user is vague ("send my config"), use `Glob` to find candidates and present options via `AskUserQuestion`. For text, ask the user to provide the content.

**Automated**: The path or text content is in the task prompt.

### Confirm before sending (interactive only)

Show the user what will be sent (filename, size, path) and ask for confirmation.

```bash
ls -lh <path>       # Show size
file <path>          # Show type
```

For directories:
```bash
du -sh <path>        # Show total size
ls <path> | head -20 # Show contents preview
```

### Execute the send

```bash
# File or directory
wormhole send --hide-progress <path>

# Text
wormhole send --text "<content>"
```

**Important**: The send command blocks waiting for the receiver. Run it and surface the wormhole code to the user or leader. The code appears in the first lines of output (format: `<number>-<word>-<word>...`).

**Interactive** — tell the user:
1. The wormhole code to share with the recipient
2. That the transfer completes once the other side runs `wormhole receive <code>`
3. The command is blocking — it sits waiting until the receiver connects or times out

**Automated** — return the wormhole code to the leader via `SendMessage` so they can relay it.

---

## Receive Flow

### Get the code

**Interactive**: Ask the user in plain text to paste their wormhole code. Do NOT use `AskUserQuestion` for this — it only offers radio buttons, not a text input field.

**Automated**: The code is in the task prompt.

### Determine where to save

**Interactive**: Use `AskUserQuestion`:

- **Current directory** — save to the working directory
- **Downloads** — save to `~/Downloads`
- **Desktop** — save to `~/Desktop`
- **Custom path** — let the user specify

**Automated**: Use the destination from the task prompt. If none specified, default to the current working directory.

### Execute the receive

```bash
wormhole receive --accept-file --hide-progress -o <target-dir> <code>
```

- `--accept-file` — auto-accept (confirmation already happened via elicitation or task prompt)
- `--hide-progress` — cleaner output for parsing
- `-o <target-dir>` — explicit output location

---

## Key Principles

- **Interactive mode uses elicitation** at decision points — don't assume paths, codes, or intent
- **Automated mode uses task prompt parameters** — no human interaction, no blocking prompts
- **Show before acting** (interactive) — display file sizes, paths, and commands before executing
- **Surface the code prominently** — the wormhole code is the whole point of the send flow
- **Always use `--accept-file` and `--hide-progress`** — the non-TTY environment can't handle interactive prompts or progress bars
