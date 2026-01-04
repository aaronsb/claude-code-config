---
match: regex
pattern: \bmcp\b|model.?context.?protocol|mcp.?(server|bridge)|tool.?integration
---
# MCP Way

## Components

| Component | Role |
|-----------|------|
| **MCP Server** | Exposes domain tools (ITSM, Identity, Monitoring) |
| **MCP Bridge** | Policy enforcement, credential mediation |
| **MCP Client** | AI agent consuming tools |

## MCP Bridge

The bridge mediates between agents and servers:
- **Policy Enforcement** - Validates requests before forwarding
- **Credential Mediation** - Injects secrets; agents never see credentials
- **Audit Logging** - Captures all tool invocations
- **Rate Limiting** - Prevents runaway automation

## Standard MCP Servers

| Server | Domain | Example Tools |
|--------|--------|---------------|
| ITSM | Ticketing | `getTicket`, `updateStatus`, `addComment` |
| Identity | IAM | `getUser`, `unlockAccount`, `resetMFA` |
| Monitoring | Observability | `queryLogs`, `getMetrics`, `getAlerts` |
| Infrastructure | Cloud/Infra | `exec`, `systemctl`, `readFile` |

## Trust Boundaries

```
┌─────────────────────────────────┐
│        TRUSTED ZONE             │
│  MCP Bridge, Servers, Secrets   │
└─────────────────────────────────┘
              ▲ (bridge mediates)
┌─────────────────────────────────┐
│       UNTRUSTED ZONE            │
│  AI Agent, User Sessions        │
└─────────────────────────────────┘
```

## Key Principles

- **Least Privilege** - Tools expose minimum required capabilities
- **Explicit Scoping** - Each tool declares allowed operations
- **Fail Closed** - Unknown requests denied
- **Audit Trail** - Every call logged with context
