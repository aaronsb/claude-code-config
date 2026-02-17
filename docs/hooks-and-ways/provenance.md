# Provenance and Governance Traceability

Ways are compiled policy. A human reads a policy document, interprets it for the agent context, and writes a way.md file — compressed, directive, stripped of rationale. The guidance that reaches the agent is the object code. The policy document is the source.

This page documents how to make that compilation traceable. For running governance reports, see [governance/README.md](../../governance/README.md).

## Quick Start: Add Provenance to a Way

Add a `provenance:` block to your way's YAML frontmatter. The runtime strips it before injection — zero tokens, zero latency:

```yaml
---
match: regex
pattern: commit|push
provenance:
  policy:
    - uri: docs/hooks-and-ways/softwaredev/code-lifecycle.md
      type: governance-doc
  controls:
    - id: NIST SP 800-53 CM-3
      justifications:
        - Conventional commits create structured change records
  verified: 2026-02-17
---
```

Then verify it's picked up: `bash governance/governance.sh --trace softwaredev/commits`

## The Full Chain

```
Regulatory Framework    (NIST, ISO, OWASP, SOC 2, CIS...)
       ↓
Control Requirement     (NIST SP 800-53 CM-3, OWASP A03:Injection...)
       ↓
Policy Document         (ADR, governance doc, internal standard)
       ↓
Way File                (way.md — compiled guidance, context-optimized)
       ↓
Agent Context           (injected at runtime when triggers match)
```

Each layer compresses the one above it. The regulatory framework is hundreds of pages. The control requirement is a paragraph. The policy document is a few pages of interpretation. The way is 30 lines of directives. The agent sees only the directives — but the full chain is walkable.

## The Compilation Metaphor

| Concept | Software Build | Way System |
|---------|---------------|------------|
| Source code | `.c` files | Policy documents |
| Compiler | `gcc` | Human authoring process |
| Object code | `.o` files | `way.md` files |
| Debug symbols | DWARF / PDB | `provenance:` frontmatter block |
| Symbol table | `.map` file | `provenance-manifest.json` |

Debug symbols don't affect program execution but are essential for debugging. Provenance metadata doesn't affect way injection but is essential for governance auditing.

## Adding Provenance to a Way

Add a `provenance:` block to the YAML frontmatter. The runtime strips all frontmatter before injection — these fields never reach the agent's context window. Zero cost.

```yaml
---
match: regex
pattern: commit|push
provenance:
  policy:
    - uri: docs/hooks-and-ways/softwaredev/code-lifecycle.md
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
    Conventional commits create structured change records. Atomic commits
    ensure each change is independently traceable and reversible.
---
```

Each control carries its own justifications — specific claims about how the way's guidance satisfies that control's requirements. This enables both graph queries (way → control → justification) and flat reporting (the spreadsheet auditors love).

### Fields

| Field | Purpose |
|-------|---------|
| `policy[].uri` | Source policy document — relative path (same repo) or `github://org/repo/path` (cross-repo) |
| `policy[].type` | Classification: `adr`, `governance-doc`, `regulatory-framework`, `control-spec` |
| `controls[].id` | Regulatory control reference this way addresses |
| `controls[].justifications[]` | Specific claims about how guidance satisfies the control |
| `verified` | Date provenance was last confirmed accurate |
| `rationale` | How policy intent became way guidance — the "compilation commentary" |

Provenance is optional. Ways without it work exactly as before. Not every way is policy-derived — operational ways like `meta/todos` or `meta/memory` exist for system management, not compliance.

## Generating the Manifest

```bash
python3 ~/.claude/governance/provenance-scan.py
python3 ~/.claude/governance/provenance-scan.py -o provenance-manifest.json
```

The manifest aggregates provenance across all ways into a single JSON artifact with:
- Per-way provenance data
- Inverted index: policy document → implementing ways
- Inverted index: control reference → addressing ways
- Coverage statistics

## Running the Coverage Report

```bash
# Basic report
bash ~/.claude/governance/provenance-verify.sh

# With cross-repo audit ledger
bash ~/.claude/governance/provenance-verify.sh --ledger /path/to/audit-ledger.json

# Machine-readable
bash ~/.claude/governance/provenance-verify.sh --json
```

The report shows which ways have provenance, which policy documents are referenced, which controls are covered, and where gaps exist.

## Cross-Repo Pattern

In an enterprise, policy documents and way implementations typically live in separate repositories:

```
compliance-repo/              your-claude-config/
├── docs/architecture/        ├── hooks/ways/
│   ├── ADR-150.md           │   ├── softwaredev/commits/way.md
│   └── ADR-200.md           │   │   (provenance: → ADR-150)
├── audit-ledger.json        │   └── softwaredev/security/way.md
└── controls.xlsx            └── provenance-manifest.json
```

The provenance frontmatter in ways references policies by URI. The manifest bridges the repos at verification time. The audit ledger in the compliance repo traces controls to policies. Together, the full chain is walkable from regulatory framework to agent context.

## Why This Matters

Governance-as-code means the connection between stated policy and actual agent behavior is verifiable — not by reading two documents side-by-side and trusting that someone maintained the link, but by running a script that walks the chain.

This doesn't require expensive GRC software. It requires frontmatter fields that the runtime ignores, a Python script that reads them, and a bash script that reports on them. The entire traceability system is three files and zero runtime cost.

An auditor can ask: "Show me which agent governance implements NIST CM-3." The answer is a `jq` query against the manifest. The way file contains the compiled guidance. The policy document contains the rationale. The control reference closes the loop to the regulatory framework. All of it is in git, with cryptographic hashes and commit history.
