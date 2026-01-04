---
match: regex
pattern: \bskill\b|runbook.?(as|to).?skill|skill.?(library|pattern|evolution)|pattern.?capture
---
# Skills Way

## What is a Skill?

A reusable code pattern with documentation:

```
skills/
└── diagnose-vpn-failure/
    ├── index.ts    # Executable code
    └── SKILL.md    # When/how to use
```

## Skill Structure

**index.ts** - The executable logic:
```typescript
export async function diagnoseVpnFailure(userId: string) {
  const user = await identity.getUser(userId);
  const logs = await monitoring.queryLogs({ service: 'vpn', user });
  // ... diagnosis logic
}
```

**SKILL.md** - Documentation:
- When to use (triggers, conditions)
- Capabilities (what it can do)
- Autonomy level (what requires approval)
- Dependencies (required MCP servers)

## Runbook-as-Skill Pattern

| Traditional Runbook | Skill |
|---------------------|-------|
| Document humans follow | Executable code |
| Step-by-step text | Loops, conditionals |
| Manual execution | Agent-invokable |
| Knowledge in docs | Knowledge in code |

## Skill Evolution Cycle

1. **Incident occurs** → Agent handles (or escalates)
2. **Post-incident review** → Was handling optimal?
3. **Skill formalization** → Code + docs + tests
4. **Skill validation** → Shadow mode testing
5. **Skill deployment** → Available with appropriate autonomy
6. **Continuous improvement** → Update based on outcomes

## Persistence

- Skills stored in R2 (survives sandbox lifecycle)
- Cross-session availability
- Version controlled
- Shareable across tenants (with isolation)
