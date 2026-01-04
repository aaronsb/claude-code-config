---
match: regex
pattern: code.?mode|tool.?call|sandbox.?(filesystem|execution)|progressive.?disclosure
---
# Code Mode Way

## Code Mode vs Tool Calling

| Aspect | Tool Calling | Code Mode |
|--------|--------------|-----------|
| Interface | Function schemas | TypeScript API |
| Context load | All tools upfront (100K+ tokens) | On-demand discovery |
| Intermediate results | Flow through model | Stay in sandbox |
| LLM strength | Unfamiliar paradigm | Native code fluency |

**Key insight**: LLMs trained on real code, not synthetic tool-call examples.

## Token Efficiency

- **98.7% reduction** (150K → 2K tokens for complex workflows)
- Tool definitions loaded on-demand
- Data processed in sandbox, only results to model

## Sandbox Filesystem

```
/workspace/
├── servers/           # MCP tool definitions
│   ├── itsm/          # getTicket, updateTicket
│   ├── identity/      # getUser, unlockAccount
│   ├── monitoring/    # queryLogs, getMetrics
│   └── infrastructure/# exec, systemctl
├── skills/            # Persistent library (R2-backed)
│   └── diagnose-vpn/
└── current_task.ts    # Agent-generated code
```

## Progressive Disclosure

1. List `/workspace/servers/` → see available MCP servers
2. List specific server → see available tools
3. Read only needed tool definitions
4. Optional: `search_tools` for keyword discovery

## Trust Boundaries

| Zone | Contents |
|------|----------|
| **Trusted** | Orchestrator, MCP Bridge, credentials, policies |
| **Untrusted** | Sandbox, agent code, user input |

Sandbox gets typed interfaces, not credentials or network access.
