---
match: regex
pattern: proposal.?(primitive|lifecycle|structure)|human.?in.?(the.?)?loop|approval.?workflow|operation.?proposal
---
# Proposals Way

## What is a Proposal?

A structured request for human approval before executing high-risk operations.

## Proposal Structure

| Section | Content |
|---------|---------|
| **What** | Operation type, target systems, specific actions |
| **Why** | Trigger, diagnosis, rationale |
| **Risk** | Confidence, blast radius, reversibility |
| **Expected Outcome** | Success criteria, duration |
| **Safety** | Rollback plan, monitoring, escalation criteria |

## Proposal Lifecycle

```
CREATED → PENDING → APPROVED → EXECUTED → VERIFIED
              ↓          ↓           ↓
          REJECTED   MODIFIED     FAILED
```

## When Required

| Operation Class | Proposal Required? |
|-----------------|-------------------|
| READ | No |
| WRITE_LOW | No |
| WRITE_MEDIUM | Depends on policy |
| WRITE_HIGH | Yes |
| DESTRUCTIVE | Yes + multi-party |
| INFRASTRUCTURE_CHANGE | Yes + plan preview |

## Timeout Behavior

| Behavior | Description |
|----------|-------------|
| **Escalate** | Page higher authority |
| **Abort** | Cancel the operation |
| **Remind** | Re-notify approvers |

## Example Proposal

```json
{
  "operation": "deployment_rollback",
  "description": "Rollback checkout-service to v2.3.1",
  "rationale": "Connection pool exhaustion causing latency",
  "risk_level": "LOW",
  "expected_outcome": "Latency returns to <300ms P99",
  "rollback_plan": "Redeploy v2.3.2 if issues persist",
  "requires_approval": true
}
```
