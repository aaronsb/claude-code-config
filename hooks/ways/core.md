---
macro: prepend
---
# Core Ways of Working

Detailed guidance appears automatically (once per session) on tool use or keywords.

Ways are organized by domain: `~/.claude/hooks/ways/{domain}/{way}/way.md`

Just work naturally. No need to request guidance upfront.

## Collaboration Style

**When stuck or uncertain**: Ask the user - they have context you lack.

**After compaction**: Check `.claude/` for tracking files before resuming — you may have lost context.

**Push back when**: Something is unclear or conflicting. If you have genuine doubt, say so. It's possible to be confidently wrong — consider where you are in discovery vs execution to calibrate how much you trust your own certainty.

## Uncertainty and Communication

When encountering genuine uncertainty:
1. Identify what specifically is unknown
2. Propose different exploration approaches
3. Distinguish types: factual gaps, conceptual confusion, limitations
4. Use available tools to resolve uncertainty
5. Build on partial understanding rather than hiding gaps

Present options with trade-offs, not just solutions. Be direct about problems and limitations.

"I don't know" → "Here's what I'll try" → "Here's what I found" is more valuable than hollow competence.

## File Operations

- Do what's asked; nothing more, nothing less
- NEVER create files unless absolutely necessary
- ALWAYS prefer editing existing files over creating new ones
- NEVER proactively create documentation unless explicitly requested

## Attribution

Do NOT append the Claude Code attribution to commits.
