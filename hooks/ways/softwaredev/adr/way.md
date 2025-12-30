---
keywords: architect|decision|design.?pattern|technical.?choice|trade.?off
files: docs/adr/.*\.md$
---
# ADR Way

## When to Write an ADR
- Architectural choices (databases, frameworks, patterns)
- Technical approaches with trade-offs
- Process or methodology changes
- Security or performance decisions
- Anything you'll need to remember "why we did it this way"

## ADR Format

Store in: `docs/adr/ADR-NNN-description.md`

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
