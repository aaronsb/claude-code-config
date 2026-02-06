---
match: regex
pattern: commit|push.*(remote|origin|upstream)
commands: git\ commit
scope: agent, subagent
provenance:
  policy:
    - uri: docs/hooks-and-ways/softwaredev/code-lifecycle.md
      type: governance-doc
  controls:
    - id: NIST SP 800-53 CM-3 (Configuration Change Control)
      justifications:
        - Conventional commit types (feat/fix/refactor) classify changes by nature
        - Atomic single-concern commits make each change independently reviewable
        - Commit message body captures rationale, satisfying change documentation requirements
    - id: SOC 2 CC8.1 (Change Management)
      justifications:
        - Type prefix and scope field create structured change records for audit trail
        - Branch naming convention (adr-NNN, feature/, fix/) categorizes change intent
    - id: ISO/IEC 27001:2022 A.8.32 (Change Management)
      justifications:
        - Git commit history provides immutable timestamped change log
        - Conventional format enables automated changelog generation
  verified: 2026-02-05
  rationale: >
    Conventional commits create structured change records with type classification
    and justification. Atomic commits ensure each change is independently traceable
    and reversible. Together they implement auditable configuration change control.
---
# Git Commits Way

## Conventional Commit Format

- `feat(scope): description` - New features
- `fix(scope): description` - Bug fixes
- `docs(scope): description` - Documentation
- `refactor(scope): description` - Code improvements
- `test(scope): description` - Tests
- `chore(scope): description` - Maintenance

## Branch Names

- `adr-NNN-topic` - Implementing an ADR
- `feature/name` - New feature work
- `fix/issue` - Bug fixes
- `refactor/area` - Code improvements

## Rules

- Skip "Co-Authored-By" and emoji trailers
- Focus commit message on the "why" not the "what"
- Keep commits atomic - one logical change per commit
