---
pattern: error.?handl|exception|try.?catch|throw|catch
scope: agent, subagent
provenance:
  policy:
    - uri: docs/hooks-and-ways/softwaredev/code-lifecycle.md
      type: governance-doc
  controls:
    - id: OWASP Top 10 2021 A09 (Security Logging and Monitoring Failures)
      justifications:
        - Boundary-only catch pattern ensures errors are logged once at system edges, not swallowed internally
        - Prohibition on silent catch blocks prevents monitoring blind spots
        - Log-once-at-boundary rule prevents log noise that obscures real failures
    - id: NIST SP 800-53 SI-11 (Error Handling)
      justifications:
        - Generic error responses to clients (code + safe message) prevent information disclosure
        - Programmer vs operational error distinction prevents exposing internal state through bug-triggered messages
    - id: NIST SP 800-53 AU-3 (Content of Audit Records)
      justifications:
        - Error wrapping with context (module boundary, identifiers) creates traceable audit records
        - Cause chaining preserves full error provenance for forensic analysis
  verified: 2026-02-09
  rationale: >
    Boundary-only catching with log-once semantics implements OWASP A09 monitoring requirements.
    Generic client error responses with safe messages address SI-11 information disclosure prevention.
    Contextual error wrapping with cause chains creates AU-3 compliant audit records.
---
# Error Handling Way

## Where to Catch

Catch at **system boundaries** only — API endpoints, CLI entry points, message handlers. Not inside business logic.

```javascript
// Boundary catch: translate and log
app.get('/users/:id', async (req, res) => {
  try {
    const user = await getUser(req.params.id);
    res.json(user);
  } catch (err) {
    logger.error('getUser failed', { userId: req.params.id, error: err.message });
    res.status(500).json({ error: { code: 'INTERNAL', message: 'Failed to fetch user' } });
  }
});
```

## Wrapping with Context

When crossing module boundaries, add context and re-throw:

```javascript
async function processOrder(orderId) {
  try {
    await chargePayment(orderId);
  } catch (err) {
    throw new Error(`Failed to process order ${orderId}: ${err.message}`, { cause: err });
  }
}
```

## Programmer Errors vs Operational Errors

- **Programmer errors** (bugs): null reference, type mismatch, assertion failure — fail fast, don't catch
- **Operational errors** (expected failures): network timeout, file not found, invalid input — handle gracefully: retry, return fallback, or return clear error to user

## Do Not

- Swallow errors silently (`catch (e) {}`)
- Log the same error at multiple levels — log once at the boundary
- Catch errors you can't handle just to re-throw unchanged
