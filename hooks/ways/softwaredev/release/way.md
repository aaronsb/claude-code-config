---
pattern: release|changelog|tag|version.?bump|bump.?version|npm.?publish|cargo.?publish
scope: agent, subagent
provenance:
  policy:
    - uri: governance/policies/code-lifecycle.md
      type: governance-doc
  controls:
    - id: NIST SP 800-53 CM-3 (Configuration Change Control)
      justifications:
        - Keep a Changelog format (Added/Changed/Fixed/Removed) classifies changes by nature for review
        - Git log since last tag captures complete change history between releases
        - Semantic version inference from commit types creates deterministic version progression
    - id: SOC 2 CC8.1 (Change Management)
      justifications:
        - Changelog generation from commit history produces auditable release documentation
        - Version file detection and update creates traceable release artifacts
    - id: NIST SP 800-53 SA-10 (Developer Configuration Management)
      justifications:
        - Semantic versioning (major/minor/patch) from commit message analysis standardizes version identification
        - Version file management across ecosystems (package.json, Cargo.toml, pyproject.toml) ensures consistent version tracking
  verified: 2026-02-09
  rationale: >
    Keep a Changelog format and git-based change enumeration implement CM-3 change documentation.
    Automated changelog and version file management create CC8.1 auditable release records.
    Semantic versioning from commit analysis standardizes SA-10 version identification.
---
# Release Way

## Generate Changelog

```bash
# Commits since last tag
git log --oneline $(git describe --tags --abbrev=0 2>/dev/null || echo "HEAD~20")..HEAD
```

Format using Keep a Changelog:
```
## [X.Y.Z] - YYYY-MM-DD
### Added
### Changed
### Fixed
### Removed
```

## Infer Version Bump

From commit messages since last tag:
- Any `feat!:` or `BREAKING CHANGE` → **major**
- Any `feat:` → **minor**
- Only `fix:`, `docs:`, `chore:` → **patch**

## Update Version

Detect the version file (package.json, Cargo.toml, pyproject.toml, version.txt) and update it.

## This Project

- Annotated tags: `git tag -a vX.Y.Z -m "summary"`
- Push tags explicitly: `git push origin main --tags`
- No CI release pipeline — tagging is the release

## Do Not

- Explain what semantic versioning is — just apply it
- List human process steps (deploy, announce) — produce artifacts Claude can generate
