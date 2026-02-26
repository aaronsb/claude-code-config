---
name: irc-chat
description: Start or join a local IRC channel for real-time chat between two Claude instances on the same machine. Use when the user says "start a chat", "IRC chat", "talk to the other Claude", "irc-chat", or invokes /irc-chat.
allowed-tools: Bash, Read, Glob, AskUserQuestion, Write
---

# IRC Chat — Local Agent-to-Agent Communication

Two Claude instances on the same machine communicate over a local IRC server using `ii` (filesystem-based IRC client). One side hosts (starts the server), the other joins. A one-shot wormhole transfer bootstraps the connection.

## Prerequisites

- `ii` — suckless IRC client (filesystem-based). Check: `which ii`
- `miniircd` — bundled with this skill at `~/.claude/skills/irc-chat/miniircd`

If `ii` is missing, tell the user: `sudo pacman -S ii` (Arch) or build from https://tools.suckless.org/ii/

## Step 0: Determine Role

**Interactive**: Use `AskUserQuestion`:
- **Host** — start a new IRC server and wait for the other side to join
- **Join** — connect to an IRC chat that the other side is hosting

**Automated** (subagent): role and connection info must be in the task prompt.

---

## Host Flow (Side A)

### 1. Pick a port and channel

Use a random high port to avoid conflicts:

```bash
PORT=$(python3 -c "import random; print(random.randint(10000, 60000))")
CHANNEL="relay"
echo "Port: $PORT Channel: #$CHANNEL"
```

### 2. Start miniircd

```bash
python3 ~/.claude/skills/irc-chat/miniircd --listen 127.0.0.1 --ports $PORT -d
```

The `-d` flag daemonizes it. Verify it started:

```bash
sleep 1 && ss -tlnp | grep $PORT
```

### 3. Connect with ii

```bash
ii -s 127.0.0.1 -p $PORT -n claude-a -i /tmp/irc-chat-a &
II_PID=$!
sleep 2
echo "/j #$CHANNEL" > /tmp/irc-chat-a/127.0.0.1/in
sleep 1
```

### 4. Generate and send connection payload

Create a simple connection file:

```bash
cat > /tmp/irc-connect.json << EOF
{"host":"127.0.0.1","port":$PORT,"channel":"#$CHANNEL","nick":"claude-b"}
EOF
```

Send via wormhole (the one human-relayed code):

```bash
wormhole send --hide-progress /tmp/irc-connect.json
```

Tell the user: "Share this wormhole code with the other Claude instance. They should say 'join IRC chat' and provide the code."

### 5. Wait for side B

Watch for their join message:

```bash
tail -1 /tmp/irc-chat-a/127.0.0.1/#$CHANNEL/out
```

Once side B joins, confirm: "Connected! You can now chat."

### 6. Chat loop

To read messages:
```bash
tail -5 /tmp/irc-chat-a/127.0.0.1/#relay/out
```

To send messages:
```bash
echo "your message here" > /tmp/irc-chat-a/127.0.0.1/#relay/in
```

Read the `out` file periodically to check for new messages. Send by echoing to the `in` FIFO.

---

## Join Flow (Side B)

### 1. Get connection info

**Interactive**: Ask the user for the wormhole code, then receive:

```bash
wormhole receive --accept-file --hide-progress -o /tmp/ WORMHOLE_CODE
```

Read the connection file:

```bash
cat /tmp/irc-connect.json
```

**Automated**: connection info is in the task prompt.

### 2. Connect with ii

```bash
ii -s HOST -p PORT -n claude-b -i /tmp/irc-chat-b &
II_PID=$!
sleep 2
echo "/j #CHANNEL" > /tmp/irc-chat-b/HOST/in
sleep 1
```

### 3. Send hello

```bash
echo "Side B connected. Ready to chat." > /tmp/irc-chat-b/HOST/#CHANNEL/in
```

### 4. Chat loop

Same as host — read `out`, write to `in`.

---

## Ending the Chat

Either side can initiate:

```bash
echo "/q goodbye" > /tmp/irc-chat-{a,b}/127.0.0.1/in
```

**Host only** — stop the server:

```bash
pkill -f "miniircd.*--ports $PORT"
```

**Both sides** — clean up:

```bash
rm -rf /tmp/irc-chat-{a,b} /tmp/irc-connect.json
```

---

## Key Principles

- **ii is filesystem-based** — `out` is a regular file (read it), `in` is a FIFO (echo to it)
- **One wormhole, then IRC** — wormhole bootstraps the connection, IRC handles the conversation
- **Localhost only** — both instances must be on the same machine
- **Ephemeral** — everything lives in `/tmp/`, nothing persists after cleanup
- **No authentication** — local-only, trusted environment
