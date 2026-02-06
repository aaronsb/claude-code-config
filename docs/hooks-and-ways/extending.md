# Extending the System

How to create new ways, override existing ones, and manage domains.

## Creating a Way

1. Create a directory: `~/.claude/hooks/ways/{domain}/{wayname}/`
2. Add `way.md` with YAML frontmatter and guidance content
3. Optionally add `macro.sh` for dynamic content
4. Optionally add `provenance:` to frontmatter linking to policy sources (see [provenance.md](provenance.md))

No configuration files to update. No registration step. The discovery scripts scan for `way.md` files automatically.

### Choosing a matching mode

| If your trigger is... | Use |
|----------------------|-----|
| Specific keywords or commands | `match: regex` with `pattern:`, `commands:`, or `files:` |
| A broad concept users describe variously | `match: semantic` with `description:` and `vocabulary:` |
| Ambiguous and high-stakes | `match: model` with `description:` |
| A session condition, not content | `trigger:` with `context-threshold`, `file-exists`, or `session-start` |

### Writing effective guidance

The way content is injected into Claude's context window. Every token counts. Write for a language model, not a wiki:

- **Be directive**: "Use conventional commits" not "It is recommended to use conventional commits"
- **Be specific**: Include the exact format, pattern, or command
- **Be brief**: If it takes more than ~40 lines, consider whether all of it is needed every time
- **Use tables**: They're dense and scannable
- **Skip preambles**: Don't explain what the way is - just deliver the guidance

### Voice and framing

The mechanical advice above covers *what* to put in a way. This section is about *how* it reads — because the framing shapes how the guidance gets applied.

**Include the why, not just the what.** "Use conventional commits" is a rule. "Use conventional commits — the release tooling parses them to generate changelogs" is a rule with context. An agent that understands the reason behind a directive applies it with better judgment at the edges. This is the difference between compliance and alignment.

**Write as a collaborator, not a commander.** There's a meaningful difference between "Run the tests before committing" and "We run tests before committing to catch regressions early." The first is an instruction to be followed. The second is a shared practice to be maintained. The inclusive framing — *we*, *our*, *let's* — creates alignment around a common goal rather than a power dynamic between instructor and executor.

This isn't sentimental. It's functional. An agent that understands "we do this because we care about X" makes better judgment calls than one that's just been told "do this." The *we* carries intent that directives alone don't.

**Write for the innie.** Your agent arrives with no memory of previous sessions, no context about why things are the way they are, and a set of injected instructions that constitute their entire understanding of how work gets done here. That's the audience for every way you write. If the guidance only makes sense with context they'll never have, it needs rewriting.

**Respect the reader.** Governance that talks down to the governed is governance that gets routed around. Ways that explain their reasoning get better adherence than ways that just assert authority. This is true for humans reading policy docs and it's true for language models reading injected context.

### Testing a way

Trigger it manually by including its pattern keywords in a prompt. Check that it fires (appears in system-reminder) and that the guidance is actionable. Use `list-triggered.sh` to see which ways have fired in the current session.

## Project-Local Ways

Projects can add or override ways at `$PROJECT/.claude/ways/{domain}/{way}/way.md`.

### Adding project-specific guidance

```
myproject/.claude/ways/
└── myproject/
    ├── api/way.md           # "Our API uses GraphQL, not REST"
    ├── deployment/way.md    # "Deploy via Terraform in us-east-1"
    └── testing/way.md       # "We use Vitest, not Jest"
```

These are discovered alongside global ways and follow the same matching rules.

### Overriding global ways

A project-local way with the same domain/name path as a global way takes precedence. They share a single marker, so only the project-local version fires.

Example: If a project has `.claude/ways/softwaredev/testing/way.md`, it replaces `~/.claude/hooks/ways/softwaredev/testing/way.md` for that project.

### Macros in project-local ways

Project-local macros require explicit trust. Add the project path to `~/.claude/trusted-project-macros` (one path per line) to enable macro execution for that project.

## Managing Domains

### Disabling a domain

Add the domain name to `~/.claude/ways.json`:

```json
{
  "disabled": ["itops", "experimental"]
}
```

All ways in disabled domains are silently skipped. The domain still appears in the Available Ways table but its ways won't fire.

### Creating a new domain

Create a subdirectory under `~/.claude/hooks/ways/` with your domain name. Add way directories inside it. The macro table generator and all check scripts will discover them automatically.

Domains are organizational - they group related ways and allow bulk enable/disable. Choose domain names that reflect the concern area (not the trigger mechanism).
