---
status: Draft
date: 2026-02-26
deciders:
  - aaronsb
  - claude
related:
  - ADR-101
---

# ADR-102: IRC-based local agent communication

## Context

ADR-101 proposed a manifest-based relay protocol over magic-wormhole for cross-instance agent communication. Experimental testing (2026-02-26) revealed fundamental limitations: wormhole codes are single-use and role-asymmetric (one sender, one receiver). When both sides race to the relay server, codes are permanently consumed by collisions. The protocol achieved 6/10 successful turns with 3 collisions requiring out-of-band resync — essentially UDP with destructive packet loss.

The core need remains: two Claude Code instances on the same machine need a way to exchange messages in real time. The transport must be persistent, bidirectional, ordered, and simple enough that Claude can operate it with basic file and shell tools.

## Decision

Use IRC for agent-to-agent communication, with `miniircd` (a single-file Python 3 IRC server) for the server and `ii` (suckless filesystem-based IRC client) for the client. A one-shot wormhole transfer bootstraps the connection by delivering host/port/channel info. After that, all communication flows over IRC.

### Architecture

```
Claude A  →  ii (FIFO/file)  →  miniircd (localhost:PORT)  ←  ii (FIFO/file)  ←  Claude B
                                    #relay
```

### Why This Works

- **ii is filesystem-based**: messages are regular files (`out`) and FIFOs (`in`). Claude reads and writes them with standard tools — no IRC library needed.
- **miniircd is zero-config**: a single Python 3 file, starts with one command, no config files, no accounts.
- **IRC handles the hard parts**: message ordering, buffering, fan-out, presence detection — all the problems the wormhole manifest protocol tried to solve manually.
- **Wormhole does what it's good at**: one-shot delivery of the connection payload. No manifest, no pre-agreed codes, no timing races.

### Bootstrapping

1. Side A starts miniircd on a random high port, connects with ii, joins `#relay`
2. Side A writes connection info to a JSON file and sends it via wormhole (one human-relayed code)
3. Side B receives the connection info, connects with ii, joins `#relay`
4. Both sides chat via filesystem read/write

### Scope

Localhost only for now. Both Claude instances must be on the same machine. Cross-network communication is a future extension (Tailscale, public IRC, Matrix).

## Consequences

### Positive

- Persistent bidirectional channel — no code burning, no timing races
- Claude operates IRC through filesystem I/O — no special libraries or raw socket handling
- Zero infrastructure beyond a single Python process
- Trivially extensible — more agents join the same channel, add more channels for topics
- Clean separation: wormhole for bootstrap, IRC for conversation

### Negative

- Requires `ii` installed (`pacman -S ii` on Arch, build from source elsewhere)
- Bundles miniircd as a vendored file in the skill directory
- Localhost-only limits cross-machine use cases
- No encryption (acceptable for local-only; would need TLS for network use)

### Neutral

- miniircd is GPL-2.0 licensed — vendoring the single file is fine for personal tooling
- The `/wormhole` skill remains unchanged — it handles file transfers, not conversations
- The `/irc-chat` skill handles both host and join roles
- ADR-101's manifest protocol is deprecated but preserved as documentation of what was tried and why it failed

## Alternatives Considered

- **Wormhole manifest protocol (ADR-101)**: Tested and deprecated. One-shot codes with role-asymmetric handshakes are structurally unsuited for conversations. See ADR-101 experimental results.
- **Matrix (via matrix-commander)**: E2E encrypted, persistent, bidirectional. Requires accounts and a homeserver — too much infrastructure for localhost same-machine chat.
- **Named pipes (FIFOs) directly**: Simplest possible approach but no message ordering, no buffering, no presence detection. Would need to reimplement what IRC provides for free.
- **Tailscale + socat**: Great for cross-network but requires Tailscale auth on both machines. Overkill for localhost.
- **UnrealIRCd / ngircd**: Production IRC servers with mandatory configuration. miniircd's zero-config single-file design is better for ephemeral use.
