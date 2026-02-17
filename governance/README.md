# Governance Traceability

<img src="../docs/images/lumon-hq.jpg" alt="The institutional perspective" width="100%" />

<sub>Someone decided what the handbooks should say. Someone decided which departments get which manuals.<br/>This is where those decisions are traceable.</sub>

---

## Getting Started

```bash
# See what's covered
bash governance/governance.sh

# Trace a single way end-to-end
bash governance/governance.sh --trace softwaredev/security

# Query by control framework
bash governance/governance.sh --control OWASP
```

For adding provenance to your own ways, see [provenance.md](../docs/hooks-and-ways/provenance.md).

> **Current state:** Governance output is ephemeral — reports go to stdout, manifests to local files. There is no CI integration or tracked output. The provenance metadata lives in way frontmatter and the reporting tools work, but the pipeline between them is run-on-demand.

---

The [main project](../README.md) manages what happens on the severed floor — how agents receive guidance, how teams coordinate, how context flows. This directory is concerned with the floor above: where the policies come from, why they exist, and whether the guidance actually implements what the institution intended.

## The Problem It Solves

Every organization with AI agents faces the same question from compliance: *"How do you know your agents are following policy?"*

The usual answer involves expensive GRC platforms, manual attestation spreadsheets, or the honest shrug of "we told them to." None of these are satisfying. The GRC platform costs six figures and still can't look inside the agent's context window. The spreadsheet is stale before the ink dries. The shrug is accurate but doesn't pass audit.

This directory contains a different answer: the policies are in the code, the code traces back to the policies, and you can verify the chain with a bash script. And because it all lives in git, every change to every policy and every way already has cryptographic hashing, immutable history, blame attribution, and timestamped provenance — for free.

## How It Works

Ways — the guidance files that get injected into agent sessions — can carry `provenance:` metadata in their YAML frontmatter:

```yaml
---
match: regex
pattern: commit|push
provenance:
  policy:
    - uri: governance/policies/code-lifecycle.md
      type: governance-doc
  controls:
    - id: NIST SP 800-53 CM-3 (Configuration Change Control)
      justifications:
        - Conventional commit types classify changes by nature
        - Atomic commits make each change independently reviewable
    - id: SOC 2 CC8.1 (Change Management)
      justifications:
        - Type prefix and scope create structured change records
  verified: 2026-02-05
  rationale: >
    Conventional commits create structured change records with type
    classification and justification, implementing auditable
    configuration change control.
---
```

The runtime strips all frontmatter before injection. Provenance metadata never reaches the agent's context window. Zero tokens. Zero latency. It exists purely for governance — the debug symbols of compiled policy.

## The Chain

```
Regulatory Framework    NIST SP 800-53, ISO 27001, OWASP, SOC 2...
       ↓
Control Requirement     CM-3: Configuration Change Control
       ↓
Policy Document         code-lifecycle.md: "Atomic commits, conventional format"
       ↓
Way File                commits/way.md: 30 lines of directive guidance
       ↓
Agent Context           Injected when git commit triggers
```

Each layer compresses the one above it. The regulatory framework is hundreds of pages. The control is a paragraph. The policy is a few pages. The way is 30 lines. The agent sees only the directives — but the full chain is walkable in either direction.

## What's Here

| File | Purpose |
|------|---------|
| `governance.sh` | The governance operator — unified CLI for all queries |
| `provenance-scan.py` | Scan all ways, extract provenance, generate traceability manifest |
| `provenance-verify.sh` | Coverage report — policy sources, control references, gaps |

A symlink at the repo root (`governance-report`) provides convenient access.

### The governance operator

```bash
# Coverage report
bash governance/governance.sh

# Trace a single way end-to-end (controls + justifications + firing stats)
bash governance/governance.sh --trace softwaredev/security

# Query by control
bash governance/governance.sh --control OWASP

# Flat traceability matrix (the spreadsheet auditors want)
bash governance/governance.sh --matrix

# Validate provenance integrity (the audit of the audit)
bash governance/governance.sh --lint

# Cross-reference provenance with way firing stats
bash governance/governance.sh --active

# Any mode outputs JSON with --json
bash governance/governance.sh --matrix --json
```

### Justifications

Each control carries specific claims about how the way satisfies it:

```yaml
controls:
  - id: OWASP Top 10 2021 A03:Injection
    justifications:
      - Detection table maps SQL concatenation to remediation actions
      - Parameterized queries required as default for all database access
```

The `--matrix` mode flattens these into rows for spreadsheet export. The `--lint` mode validates that every control has justifications, every policy URI points to a real file, and every verified date is well-formed. The linter is committed and versioned — it's the governance system auditing its own integrity.

### Generate the manifest

```bash
python3 governance/provenance-scan.py -o provenance-manifest.json
```

Produces a JSON artifact with per-way provenance data and inverted indices — policy → implementing ways, control → addressing ways. An auditor can query it with `jq`.

### Cross-reference with an external audit ledger

```bash
bash governance/provenance-verify.sh --ledger /path/to/audit-ledger.json
```

If your compliance team maintains a separate repo with control inventories and ADRs, the verify script can cross-reference their control IDs against your ways and report coverage gaps.

## Real Standards, Not Theater

The provenance annotations on the built-in ways reference actual, public standards:

| Way | Standards |
|-----|-----------|
| **commits** | NIST CM-3, SOC 2 CC8.1, ISO 27001 A.8.32 |
| **security** | OWASP A03, NIST IA-5, CIS Controls, SOC 2 CC6.1 |
| **quality** | ISO 25010, NIST SA-15, IEEE 730 |
| **knowledge** | ISO 9001 7.5, ISO 27001 5.2, NIST PL-2 |

These aren't decorative. An auditor familiar with NIST 800-53 can read the commits way's provenance and trace the line from CM-3 (Configuration Change Control) through the governance doc (code-lifecycle.md) to the specific guidance the agent receives (conventional commit format, atomic changes, audit trail through commit messages). That chain is real and verifiable.

## Making This Its Own Repo

This directory is designed to be separable — a perforated pop-out. To use it standalone:

1. Copy `governance/` to a new repo
2. Set `WAYS_DIR` in the scripts to wherever your ways live
3. Add `provenance:` blocks to your ways referencing your own policy documents
4. Optionally connect to an external audit ledger for cross-repo control verification

The tools need Python 3 and bash + jq. No other dependencies.

Your compliance repo owns the policies. Your ways repo owns the guidance. This directory bridges them — and the bridge is verifiable.

## Further Reading

- [ADR-005: Governance Traceability](../docs/architecture/legacy/ADR-005-governance-traceability.md) — the design decision
- [Provenance documentation](../docs/hooks-and-ways/provenance.md) — the full reference
- [The Cost of Bad Instructions](../docs/hooks-and-ways/rationale.md) — why this matters economically and environmentally
