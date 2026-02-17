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

## ADR Format

Store in: `docs/architecture/ADR-NNN-description.md`

```markdown
# ADR-NNN: Decision Title

Status: Proposed | Accepted | Deprecated | Superseded
Date: YYYY-MM-DD
Deciders: @user, @claude

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

## ADR Workflow
1. **Debate**: Discuss problem and potential solutions
2. **Draft**: Create ADR documenting decision
3. **PR**: Create pull request for ADR review
4. **Review**: User reviews, comments, iterates
5. **Merge**: ADR becomes accepted, ready to reference
6. **Implement**: Create branch, reference ADR in work
