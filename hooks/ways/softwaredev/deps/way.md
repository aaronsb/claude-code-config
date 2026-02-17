---
pattern: dependenc|package|library|npm.?install|pip.?install|upgrade.*version
commands: npm\ install|yarn\ add|pip\ install|cargo\ add|go\ get
scope: agent, subagent
provenance:
  policy:
    - uri: governance/policies/code-lifecycle.md
      type: governance-doc
  controls:
    - id: NIST SP 800-53 SA-12 (Supply Chain Protection)
      justifications:
        - Pre-addition checklist evaluates maintenance status, size, and license before adopting third-party components
        - Trivial dependency rejection (is-odd, left-pad) reduces unnecessary supply chain attack surface
    - id: OWASP Top 10 2021 A06 (Vulnerable and Outdated Components)
      justifications:
        - npm audit / pip-audit / cargo audit required after adding or updating dependencies
        - Dependencies more than 2 major versions behind flagged for remediation
        - Changelog review before updates catches breaking changes and known vulnerabilities
    - id: NIST SP 800-53 RA-5 (Vulnerability Monitoring and Scanning)
      justifications:
        - Post-install audit scanning implements continuous vulnerability monitoring for third-party code
        - Vulnerability warnings must be fixed or explicitly documented as accepted risk
  verified: 2026-02-09
  rationale: >
    Pre-addition evaluation implements supply chain risk assessment per SA-12. Post-install
    audit scanning operationalizes vulnerability monitoring per RA-5. Outdated component
    flagging and changelog review address OWASP A06 vulnerable component risks.
---
# Dependencies Way

## Before Adding a Dependency

Pause and check:

| Question | How to Check |
|----------|-------------|
| Do we really need this? | Could we write it in <50 lines? |
| Is it maintained? | `npm info <pkg>` or `gh repo view <org/repo>` — last publish, open issues |
| How big is it? | `npm pack --dry-run <pkg>` for size |
| What's the license? | `npm info <pkg> license` |
| Is it trivial? | Don't add packages for `is-odd`, `left-pad`, etc. |

## When Updating

- `npm outdated` / `pip list --outdated` to see what's behind
- Read the changelog before updating — check for breaking changes
- Update one package at a time when debugging compatibility
- Run tests after each update

## Security

- `npm audit` / `pip-audit` / `cargo audit` after adding or updating
- Don't ignore vulnerability warnings — fix or document the exception
- Flag dependencies more than 2 major versions behind
