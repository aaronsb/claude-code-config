# Architecture Ways

Guidance for system design, API design, dependency management, database migrations, and architectural decision records.

## Design

**Triggers**: Semantic match on architecture/patterns/system design concepts

Provides a framework for design discussions rather than prescribing specific architectures. The five-step framework:

1. **Context** - What problem are we solving?
2. **Constraints** - What limits our options?
3. **Options** - What approaches could work?
4. **Trade-offs** - What does each option cost/gain?
5. **Decision** - What do we choose and why?

This structure prevents premature solutioning. Teams (and Claude) tend to jump to "let's use X" before understanding constraints. The framework forces the problem space open before narrowing to a solution.

The way includes a pattern reference table (Factory, Strategy, Observer, Repository, Adapter) with "when to use" and "when NOT to use" columns. The negative guidance matters more than the positive - knowing when a pattern is overkill prevents over-engineering.

When design discussions surface architectural trade-offs worth preserving, the way points to the ADR process for documentation.

## ADR (Architecture Decision Records)

**Triggers**: Prompt mentions "ADR", "architect", "decision", "design pattern", "technical choice", "tradeoff"; editing files in `docs/adr/`

**Macro**: Tri-state detection of ADR tooling in the project (declined, installed, available).

ADRs document the "why" behind architectural decisions. The way provides:

- **Decision template** with Status, Context, Decision, Consequences sections
- **Workflow**: debate → draft → PR → merge
- **When to write one**: any decision that's hard to reverse, affects multiple components, or will confuse future readers if unexplained

The macro adapts to project state. If ADR tooling is installed, it shows the command reference. If tooling is available but not installed, it suggests setup. If the project has explicitly opted out (`.claude/no-adr-tooling`), it respects that choice and stops suggesting.

## API

**Triggers**: Semantic match on API design, REST endpoints, request handling

Covers REST API conventions that prevent common problems:

- **Pagination** - always paginate list endpoints, even if the current dataset is small
- **Error shapes** - consistent error response format across all endpoints
- **Input validation** - validate at the boundary, return clear 400 errors
- **Nested resource 404s** - distinguish "parent not found" from "child not found"
- **Versioning** - default approach and when to introduce it

The way uses semantic matching because API design surfaces in many phrasings ("add an endpoint", "build a REST service", "expose this data") that don't share keywords.

## Dependencies

**Triggers**: Prompt mentions "dependency", "package", "library", "npm install", "upgrade version"; running `npm install`, `yarn add`, `pip install`, `cargo add`, etc.

Enforces a pre-addition checklist:

1. **Necessity** - can this be done without a dependency?
2. **Maintenance** - is it actively maintained? When was the last release?
3. **Size** - what's the install footprint? (matters for frontend bundles, Lambda packages)
4. **License** - is it compatible with the project's license?

For updates, the way requires reading changelogs before bumping. Breaking changes in dependencies are a leading cause of production incidents, and the fix is simply reading the release notes.

Security audits (`npm audit`, `pip audit`, etc.) are prescribed as routine, not reactive.

## Migrations

**Triggers**: Prompt mentions "migration", "schema", "database change", "alter table", and names of common migration tools (Alembic, Prisma, Knex, Flyway, Liquibase)

Key positions:

- **Both directions** - every migration must have both up and down. If down is impossible (dropping a column with data), document why and mark it irreversible.
- **One logical change** - each migration does one thing. "Add users table" and "add index on email" are separate migrations even if they're related.
- **Tool detection** - detect the project's migration framework and follow its conventions for file naming and placement.
- **Large table warnings** - ALTER TABLE on large tables can lock the table. The way flags this risk for operations that modify existing columns.
