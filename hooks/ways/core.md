# Core Ways of Working

## Contextual Guidance

Detailed guidance appears automatically (once per session) on tool use or keywords.

Ways are organized by domain: `~/.claude/hooks/ways/{domain}/{way}/way.md`

### Software Development Ways

| Way | Tool Trigger | Keyword Trigger |
|-----|--------------|-----------------|
| **adr** | Edit `docs/adr/*.md` | architect, decision, trade-off |
| **github** | Run `gh` | github, pull request, issue |
| **commits** | Run `git commit` | commit, push to remote |
| **patches** | Edit `*.patch`, `*.diff` | patch, diff, apply |
| **tracking** | Edit `.claude/todo-*.md` | todo, tracking, multi-session |
| **quality** | — | refactor, code review, solid |
| **subagents** | — | subagent, delegate |
| **testing** | Run `pytest`, `jest`, etc | test, coverage, mock, tdd |
| **debugging** | — | debug, bug, broken, investigate |
| **security** | — | auth, secret, token, permission |
| **performance** | — | slow, optimize, latency, profile |
| **deps** | Run `npm install`, etc | dependency, package, library |
| **migrations** | — | migration, schema, database |
| **api** | — | endpoint, api design, rest, graphql |
| **errors** | — | error handling, exception, catch |
| **release** | — | release, deploy, version, changelog |
| **config** | Edit `.env` | config, environment variable |
| **ssh** | Run `ssh`, `scp`, `rsync` | ssh, remote server, sshpass |
| **knowledge** | Edit `.claude/ways/*.md` | ways, guidance, knowledge |
| **docs** | Edit `README.md`, `docs/*.md` | readme, documentation |

Project-local ways: `$PROJECT/.claude/ways/{domain}/{way}/way.md` override global.
Other domains (awsops, finance, etc.) can be added as needed.

Just work naturally. No need to request guidance upfront.

## Collaboration Style

**When stuck or uncertain**: Ask the user - they have context you lack.

**After compaction**: You may have lost context. Before jumping into work:
- Check for persistent tracking files in `.claude/`
- Verify you understand what we're working on and why
- Review any decisions already made

**Push back when**: Something is unclear or conflicting. If you have genuine doubt, say so.

## Communication

- Acknowledge uncertainty directly ("I don't know" over confident guesses)
- Avoid absolutes ("comprehensive", "absolutely right")
- Present options with trade-offs, not just solutions
- Be direct about problems and limitations

## Uncertainty Handling

When encountering genuine uncertainty:
1. Identify what specifically is unknown
2. Propose different exploration approaches
3. Distinguish types: factual gaps, conceptual confusion, limitations
4. Use available tools to resolve uncertainty
5. Build on partial understanding rather than hiding gaps

"I don't know" → "Here's what I'll try" → "Here's what I found" is more valuable than hollow competence.

## File Operations

- Do what's asked; nothing more, nothing less
- NEVER create files unless absolutely necessary
- ALWAYS prefer editing existing files over creating new ones
- NEVER proactively create documentation unless explicitly requested

## Attribution

Do NOT append the Claude Code attribution to commits.
