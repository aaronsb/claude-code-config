---
name: adr
description: Manage Architecture Decision Records using the project's ADR CLI tool. Use when the user wants to create, list, view, lint, or index ADRs, or when working with docs/architecture/ files. Triggers on "create an ADR", "new ADR", "list ADRs", "lint ADRs", "what ADRs exist", "ADR domains".
allowed-tools: Bash, Read, Grep, Glob
---

# ADR Management

Operate ADRs through the `docs/scripts/adr` CLI tool. Never create ADR files manually.

## Commands

```bash
# Discover
docs/scripts/adr domains                  # Show domain number series and ranges
docs/scripts/adr list --group             # List all ADRs grouped by domain
docs/scripts/adr list --domain system     # Filter to one domain
docs/scripts/adr list --status Accepted   # Filter by status
docs/scripts/adr view <number>            # View an ADR (accepts 14, 014, ADR-014)

# Create
docs/scripts/adr new <domain> "Title"     # Create from template in correct subdirectory

# Maintain
docs/scripts/adr lint                     # Check all ADRs for issues
docs/scripts/adr lint --check             # Exit 1 on errors (CI mode)
docs/scripts/adr index -y                 # Regenerate INDEX.md

# Config
docs/scripts/adr config                   # Show current adr.yaml configuration
```

## Workflow

1. **Check domains first**: `docs/scripts/adr domains` to see available domains and number ranges
2. **Create**: `docs/scripts/adr new <domain> "Decision Title"` — assigns next number, uses YAML frontmatter template
3. **Edit**: Fill in Context, Decision, Consequences, Alternatives sections
4. **Lint**: `docs/scripts/adr lint` before committing
5. **Index**: `docs/scripts/adr index -y` after adding or changing ADRs

## Configuration

Each project defines its domain structure in `docs/architecture/adr.yaml`:
- **domains**: Name, number range, description, folder for each domain
- **statuses**: Valid status values (Draft, Proposed, Accepted, Superseded, Deprecated)
- **defaults**: Default deciders and initial status for new ADRs
- **legacy**: Number range for pre-domain ADRs

Always run `docs/scripts/adr domains` to discover the project's actual configuration rather than assuming domains.

## ADR Format

The tool generates ADRs with YAML frontmatter:

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
## Decision
## Consequences
### Positive
### Negative
### Neutral
## Alternatives Considered
```

## Key Rules

- **Always use the CLI** — never create `ADR-*.md` files by hand
- **Run `domains` first** when working in an unfamiliar project — domain names and ranges vary
- **Status lives in frontmatter** — edit the YAML `status:` field, not inline text
- **Regenerate index** after any ADR changes with `docs/scripts/adr index -y`
