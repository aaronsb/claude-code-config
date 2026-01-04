---
match: regex
pattern: incident.?response|\bl[0-2]\b.?support|escalat|mttr|mean.?time|alert.?(response|triage)|remediat
---
# Incident Response Way

## Support Tiers

| Tier | Domain | Autonomy | Example |
|------|--------|----------|---------|
| **L0** | End-user IT | High (act + notify) | Account unlock, password reset |
| **L1/L2** | Service ops | Medium (known patterns) | Service restart, log analysis |
| **DevOps/SRE** | Infrastructure | Low (propose + approve) | IaC changes, capacity scaling |
| **Senior** | Architecture | Advisory only | Migration planning |

## Incident Flow

```
Trigger → Diagnose → Remediate → Verify → Close
                ↓
           Escalate (if needed)
```

## Contextual Escalation

When escalating, provide:
- Original request/alert
- Diagnostic steps taken
- Evidence collected (logs, metrics)
- Hypotheses considered
- Why escalation needed

**Bad**: "User can't connect to VPN"
**Good**: "User locked after 5 failed attempts. No password change. No security alerts. Unlocked account - user should retry in 2 min."

## L0 Example (VPN Failure)

1. Query AD → Account locked
2. Query VPN logs → 5 failed attempts
3. Check password changes → None recent
4. Check security alerts → Clean
5. **Autonomous action**: Unlock account
6. Respond with context and next steps

## Metrics

| Metric | Target |
|--------|--------|
| Resolution rate (L0) | >40% without human |
| MTTR (agent-resolved) | <5 minutes |
| Escalation quality | 90% include context |
| User satisfaction | CSAT >4.0/5.0 |
