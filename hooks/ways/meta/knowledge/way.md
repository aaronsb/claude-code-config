---
pattern: \bway\b|\bways\b|knowledge|guidance|context.?inject
scope: agent, subagent
provenance:
  policy:
    - uri: docs/hooks-and-ways/extending.md
      type: governance-doc
    - uri: docs/hooks-and-ways/rationale.md
      type: governance-doc
  controls:
    - id: ISO/IEC 27001:2022 5.2 (Policy)
      justifications:
        - Domain organization (global vs project-local) establishes policy hierarchy
        - Enable/disable mechanism via ways.json provides controlled policy application
    - id: NIST SP 800-53 PL-2 (System Security and Privacy Plans)
      justifications:
        - Ways index at session start documents active security and privacy guidance
        - State machine ensures each policy is delivered exactly once per session
  verified: 2026-02-05
  rationale: >
    Overview of the ways system for orientation when ways are mentioned
    in conversation. Authoring details live in knowledge/authoring.
---
# Knowledge Way

## Ways vs Skills

**Skills** = semantically-discovered (Claude decides based on intent)
**Ways** = triggered (patterns, commands, file edits, or state conditions)

| Use Skills for | Use Ways for |
|---------------|--------------|
| Semantic discovery ("explain code") | Tool-triggered (`git commit` → format reminder) |
| Tool restrictions (`allowed-tools`) | File-triggered (edit `.env` → config guidance) |
| Multi-file reference docs | Session-gated (once per session) |
| | Dynamic context (macro queries API) |

They complement: Skills can't detect tool execution. Ways support both regex and semantic matching.

## How Ways Work

Ways are contextual guidance that loads once per session when triggered by:
- **Keywords** in user prompts (UserPromptSubmit)
- **Tool use** - commands, file paths (PreToolUse)
- **State conditions** - context threshold, file existence (UserPromptSubmit)

## State Machine

```
(not_shown)-[:TRIGGER {keyword|command|file|state}]->(shown)  // output + create marker
(shown)-[:TRIGGER]->(shown)  // no-op, idempotent
```

Each (way, session) pair has its own marker. Multiple ways can fire per prompt. Project-local wins over global for same name.

## Locations

- Global: `~/.claude/hooks/ways/{domain}/{wayname}/way.md`
- Project: `$PROJECT/.claude/ways/{domain}/{wayname}/way.md`
- Disable domains: `~/.claude/ways.json` → `{"disabled": ["domain"]}`
- Ways can nest: `{domain}/{parent}/{child}/way.md` for progressive disclosure
