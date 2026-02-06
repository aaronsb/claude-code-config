---
name: governance-cite
description: Cite governance controls and justifications when making recommendations about code quality, security, commits, or documentation. Use when justifying why a practice matters, when a user asks "why do we do this?", when reviewing code against standards, or when recommending practices that align with NIST, OWASP, ISO, SOC 2, CIS, or IEEE controls.
allowed-tools: Bash, Read, Grep, Glob
---

# Governance Citation

You have access to a governance traceability system that maps agent guidance (ways) to real regulatory controls with specific justification evidence. Use this to ground your recommendations in actual standards rather than general knowledge.

## When to Cite

Cite governance controls when:
- Recommending a practice that has a governing control (commits, security, quality, documentation)
- Answering "why do we do it this way?"
- Reviewing code and flagging issues covered by a control
- A user questions whether a practice matters

Don't force citations into every response. Use them when they add authority or clarity.

## How to Look Up Controls

### By topic

```bash
bash ~/.claude/governance/governance.sh --control PATTERN
```

Examples:
- `--control NIST` — all NIST controls
- `--control OWASP` — injection prevention
- `--control ISO` — all ISO standards
- `--control SOC` — SOC 2 controls
- `--control CIS` — CIS controls
- `--control change` — change management controls

### By way (full trace)

```bash
bash ~/.claude/governance/governance.sh --trace softwaredev/commits
bash ~/.claude/governance/governance.sh --trace softwaredev/security
bash ~/.claude/governance/governance.sh --trace softwaredev/quality
bash ~/.claude/governance/governance.sh --trace meta/knowledge
```

### Machine-readable (for structured extraction)

```bash
bash ~/.claude/governance/governance.sh --control PATTERN --json
bash ~/.claude/governance/governance.sh --trace WAY --json
```

## Citation Format

When citing a control, reference the control ID and quote the specific justification:

**Inline** (for brief references):
> We use conventional commit format — per NIST CM-3, this "creates structured change records with type classification" for auditable configuration change control.

**Detailed** (for explanations or reviews):
> This aligns with **NIST SP 800-53 CM-3 (Configuration Change Control)**, which our commit guidance implements through:
> - Conventional commit types (feat/fix/refactor) classify changes by nature
> - Atomic single-concern commits make each change independently reviewable
> - Commit message body captures rationale, satisfying change documentation requirements

**Code review** (for flagging issues):
> This SQL string concatenation violates **OWASP A03:Injection** — our security way requires parameterized queries as default for all database access. The detection table maps this exact pattern to the remediation: "Replace with parameterized queries."

## What Controls Are Available

The system currently tracks 13 controls across 4 governed ways:

| Way | Standards |
|-----|-----------|
| **softwaredev/commits** | NIST CM-3, SOC 2 CC8.1, ISO 27001 A.8.32 |
| **softwaredev/security** | OWASP A03, NIST IA-5, CIS v8 16.12, SOC 2 CC6.1 |
| **softwaredev/quality** | ISO 25010, NIST SA-15, IEEE 730 |
| **meta/knowledge** | ISO 9001 7.5, ISO 27001 5.2, NIST PL-2 |

Run `bash ~/.claude/governance/governance.sh --matrix --json` for the complete traceability matrix.

## Principles

- **Quote the justification, not the standard.** "Parameterized queries required as default" is more useful than "per NIST IA-5."
- **The justification is the evidence.** Each one maps a specific way directive to a specific control requirement. That's the chain.
- **Don't over-cite.** One relevant control with its justification is better than listing every standard that tangentially applies.
- **Cite from the data, not from memory.** Always run the governance operator to get current controls. The provenance metadata may have changed since your training data.
