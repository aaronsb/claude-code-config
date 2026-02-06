---
description: Run governance traceability report — provenance coverage, control queries, way traces
---

Run `~/.claude/governance/governance.sh` with the user's arguments (if any) and display the output.

This is the governance operator. Common invocations:

- `governance.sh` — coverage report (default)
- `governance.sh --trace softwaredev/commits` — end-to-end trace for a way
- `governance.sh --control NIST` — which ways implement controls matching "NIST"
- `governance.sh --policy code-lifecycle` — which ways derive from a policy
- `governance.sh --gaps` — list ways without provenance
- `governance.sh --stale` — ways with stale verified dates
- `governance.sh --active` — cross-reference provenance with way firing stats
- `governance.sh --matrix` — flat traceability matrix (way | control | justification)
- `governance.sh --lint` — validate provenance integrity
- `governance.sh --json` — append to any mode for machine-readable output

If the user provides arguments after `/governance`, pass them through. If no arguments, run the default coverage report.
