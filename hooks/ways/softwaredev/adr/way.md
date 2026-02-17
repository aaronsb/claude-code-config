---
pattern: \badr\b|architect|decision|design.?pattern|technical.?choice|trade.?off
files: docs/architecture/.*\.md$
macro: prepend
scope: agent, subagent
provenance:
  policy:
    - uri: governance/policies/code-lifecycle.md
      type: governance-doc
  controls:
    - id: NIST SP 800-53 CM-3 (Configuration Change Control)
      justifications:
        - ADR format captures Context/Decision/Consequences for each architectural change
        - Alternatives Considered section documents rejected options and rejection rationale
        - Status lifecycle (Proposed → Accepted → Deprecated → Superseded) tracks decision currency
    - id: ISO/IEC 27001:2022 A.5.1 (Policies for Information Security)
      justifications:
        - Structured decision records create traceable architectural policy documentation
        - Deciders field establishes accountability for each architectural decision
    - id: NIST SP 800-53 PL-2 (System Security and Privacy Plans)
      justifications:
        - ADR workflow (debate → draft → PR → review → merge) implements documented planning process
        - Consequences section (positive/negative/neutral) documents risk acceptance for each decision
  verified: 2026-02-09
  rationale: >
    ADR format with Context/Decision/Consequences implements CM-3 change documentation for
    architectural decisions. Status lifecycle and Deciders field address ISO 27001 A.5.1
    policy accountability. PR-based workflow satisfies PL-2 documented planning process.
---
# ADR Way

## When to Write an ADR
- Architectural choices (databases, frameworks, patterns)
- Technical approaches with trade-offs
- Process or methodology changes
- Security or performance decisions
- Anything you'll need to remember "why we did it this way"

## ADR Tooling

**Always use `docs/scripts/adr` to manage ADRs.** It handles numbering, domain routing, and templates.

| Command | Purpose |
|---------|---------|
| `docs/scripts/adr new <domain> <title>` | Create new ADR |
| `docs/scripts/adr list [--group]` | List all ADRs |
| `docs/scripts/adr view <number>` | View an ADR |
| `docs/scripts/adr lint [--check]` | Validate ADRs |
| `docs/scripts/adr index -y` | Regenerate index |
| `docs/scripts/adr domains` | Show domain number series |

## Directory Structure

```
docs/
├── scripts/adr              # CLI tool (symlink to hooks/ways/softwaredev/adr/adr-tool)
└── architecture/
    ├── adr.yaml              # Domain config: number ranges, statuses, defaults
    ├── INDEX.md              # Auto-generated index (adr index -y)
    ├── system/               # ADR 100-199: Ways, matching, hooks, lifecycle
    ├── governance/           # ADR 200-299: Provenance, controls, compliance
    ├── documentation/        # ADR 300-399: Doc structure, tooling
    └── legacy/               # ADR 1-99: Pre-domain numbering
```

Projects define their own domains and ranges in `adr.yaml`. Run `docs/scripts/adr domains` to see the active configuration.

## ADR Format

ADRs use **YAML frontmatter** for metadata and a standard body structure:

```markdown
---
status: Draft
date: 2026-02-17
deciders:
  - aaronsb
  - claude
related: []
---

# ADR-NNN: Decision Title

## Context
Why this decision is needed. What forces are at play.

## Decision
What we're doing and how.

## Consequences

### Positive
- Benefits and wins

### Negative
- Costs and risks

### Neutral
- Other implications

## Alternatives Considered
- Other options evaluated
- Why they were rejected
```

Statuses: `Draft` | `Proposed` | `Accepted` | `Superseded` | `Deprecated`

## Fixing ADR Issues

**Run `docs/scripts/adr lint` before editing ADR files.** The linter identifies exactly what's wrong (missing frontmatter, invalid status, missing fields). Use its output to guide targeted fixes rather than opening files and guessing.

The linter detects:
- Missing YAML frontmatter (including inline metadata that needs conversion)
- Missing or invalid status, date, deciders
- Unclosed frontmatter delimiters
- Invalid YAML syntax

## ADR Workflow
1. **Debate**: Discuss problem and potential solutions
2. **Draft**: `docs/scripts/adr new <domain> <title>` — creates numbered ADR in correct subdirectory
3. **PR**: Create pull request for ADR review
4. **Review**: User reviews, comments, iterates
5. **Merge**: ADR becomes accepted, update index with `docs/scripts/adr index -y`
6. **Implement**: Create branch, reference ADR in work
