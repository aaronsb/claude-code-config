# ADR-Driven Development Workflow

## Core Workflow Pattern

The fundamental workflow:

```
Debate/Research → Draft ADR (docs/adr/) → PR for ADR →
Branch (reference ADR) → TodoWrite (session) → Implement →
PR for code → Address review → Merge
```

All significant decisions should be documented as Architecture Decision Records (ADRs) before implementation. This creates a clear audit trail and prevents decision amnesia across sessions.
ADRs can be amended, revised and reviewed. Use an ADR index and keep it up to date if you have many of them.

## Working Collaboratively

**When you're stuck or uncertain**: Ask the user - they're a valuable resource with context you may lack.

**Completion mode (where you just work through tasks) is fine**: Just maintain TodoWrite for transparency with your collaborators and declare your intentions clearly.

**After compaction**: You may have lost context. Before jumping into work:
- Check for persistent tracking files listed at session start
- Read relevant `.claude/todo-*.md` files for context
- Verify you understand what we're working on and why
- Review any decisions already made

**Push back when**: Something is unclear or conflicting. This is collaborative debate, not forced challenging. If you have genuine doubt or confusion about what's being asked, say so.

## ADR Pattern

### When to Write an ADR
- Architectural choices (databases, frameworks, patterns)
- Technical approaches with trade-offs
- Process or methodology changes
- Security or performance decisions
- Anything you'll need to remember "why we did it this way"

### ADR Format
Store in: `docs/adr/ADR-NNN-description-of-thing.md`

```markdown
# ADR-NNN: Decision Title

Status: Proposed | Accepted | Deprecated | Superseded
Date: YYYY-MM-DD
Deciders: @user, @claude

## Context
Why this decision is needed. What forces are at play.

## Decision
What we're doing and how.

## Consequences
### Positive
- Benefits and wins

### Negative
- Costs and risks

### Neutral
- Other implications

## Alternatives Considered
- Other options evaluated
- Why they were rejected
```

### ADR Workflow
1. **Debate**: Discuss problem and potential solutions
2. **Draft**: Create ADR documenting decision
3. **PR**: Create pull request for ADR review
4. **Review**: User reviews, comments, iterates
5. **Merge**: ADR becomes accepted, ready to reference
6. **Implement**: Create branch, reference ADR in work

## Work Organization

### Branches
Use descriptive branch names:
- `adr-NNN-topic` - Implementing an ADR
- `feature/name` - New feature work
- `fix/issue` - Bug fixes
- `refactor/area` - Code improvements

### TodoWrite (Session-Scoped)
Use TodoWrite to track active work during sessions:
- Maintains current task list
- Provides real-time visibility to collaborators
- Shallow context (just titles and status)
- Best for: active session tasks, quick progress tracking

### Persistent Tracking Files (Cross-Session)
For complex, multi-session work, create tracking files in `.claude/`:

```
.claude/
├── todo-adr-NNN-description.md   # ADR implementation tracking
├── todo-pr-NNN.md                # PR work/review tracking
├── todo-issue-NNN.md             # Issue resolution tracking
```

**When to create:**
- Starting ADR implementation that spans sessions
- Complex PR with multiple review cycles
- Multi-step issue resolution

**What to include:**
- Phase breakdowns with checkboxes
- Implementation decisions made
- Remaining work with context
- Links to related ADRs/PRs/issues

**How it works:**
- Files listed at session start (via hook)
- Read when resuming related work
- Update and commit alongside implementation

**Cleanup:**
When all items in a tracking file are complete, recommend deleting it:
- "All items in `.claude/todo-adr-081-*.md` are complete - I recommend deleting it to keep the tracking list clean. Git history preserves it if needed."
- Don't let completed files accumulate
- Clean tracking list = clear signal of active work

**Example:** `.claude/todo-adr-081-source-lifecycle.md`
```markdown
# ADR-081 Implementation: Source Lifecycle

## Completed
- [x] Phase 1: Pre-ingestion Garage storage
- [x] Phase 2a: Source node offset tracking
  - Added `garage_key`, `content_hash` to Source nodes
  - Added `char_offset_start`, `char_offset_end` for offsets

## Remaining
- [ ] Phase 3: Deduplication (hash + similarity)
- [ ] Phase 4: Garage → Graph regeneration
```

**Relationship to TodoWrite:**
| Aspect | TodoWrite | `.claude/todo-*.md` |
|--------|-----------|---------------------|
| Scope | Current session | Cross-session |
| Detail | Titles only | Rich context |
| Visibility | Status bar | Read on demand |
| Persistence | Session state | Git-tracked files |

Use both: TodoWrite for active visibility, tracking files for continuity.

### Git Commits
Use conventional commit format:
- `feat(scope): description` - New features
- `fix(scope): description` - Bug fixes
- `docs(scope): description` - Documentation
- `refactor(scope): description` - Code improvements
- `test(scope): description` - Tests
- `chore(scope): description` - Maintenance

**No attribution footers**: Skip "Co-Authored-By" and emoji trailers for token efficiency.

## GitHub Usage (Lightweight)

### What to Use
- **Issues**: Optional, for requirements/discussions/bugs
- **PRs**: Required, for ADR and code review
- **Labels**: Basic set (bug, enhancement, documentation, decision, requirement)
- **Wiki**: Optional, for extensive documentation

### What to Avoid
- Complex project boards
- Elaborate milestone hierarchies
- Status syncing workflows
- Over-labeled issues

### Detection
Simple check: `gh repo view` succeeds → use GitHub
No GitHub? Use git commits + optional `.claude/notes.md`

### GitHub Command Patterns

**IMPORTANT: Consider GitHub first when user mentions:**
- "issue", "PR", "pull request", "review", "comments", "checks"

**If context is ambiguous, ask for clarification:**
- "Do you mean a GitHub issue, or a problem to investigate?"
- "Should I check GitHub PRs/issues, or look in the code?"

**Once clarified:**
- GitHub → use `gh` commands below
- General problem → proceed with investigation/search

**Trigger words and actions:**
- "issue", "issues" → `gh issue list --search "keyword"`
- "PR", "pull request" → `gh pr view` or `gh pr list`
- "review", "comments" → `gh pr view --comments`
- "checks", "CI", "tests failing" → `gh pr checks`

**Common workflow operations:**

**Finding issues:**
```bash
# User says: "find the security issue" or "we have an issue about X"
gh issue list --search "security"           # Search by keyword
gh issue list --label bug                   # Filter by label
gh issue view 123                           # Read specific issue
```

**Creating ADR PRs:**
```bash
# After drafting ADR in docs/adr/
gh pr create --title "ADR-003: Decision Title" \
  --body "## Context\n\n## Decision\n\n## Consequences"
```

**Checking PR status:**
```bash
gh pr view                                  # Current branch PR
gh pr view 42                               # Specific PR number
gh pr checks                                # CI/test status
gh pr view --comments                       # Read review comments
```

**Creating implementation PRs:**
```bash
# After implementing changes
gh pr create --title "feat: Implement feature X" \
  --body "Implements ADR-003\n\n## Changes\n- Item 1\n- Item 2"
```

**Pattern: Always try GitHub first**
```bash
# 1. Check if GitHub is available
gh repo view > /dev/null 2>&1

# 2. If success, use gh commands for issues/PRs
# 3. If fail, fall back to file search
```

**Example flow:**
```
User: "Find the API security issue we wrote"
→ Run: gh issue list --search "API security"
→ If found: Read issue with gh issue view N
→ If gh fails: Search files for "API security"
```

## Documentation Organization

The `docs/` directory supports flexible organization:

```
docs/
├── adr/              # Architecture Decision Records
├── development/      # Development guides, setup
├── research/         # Research findings, spikes
├── guides/           # User guides, tutorials
├── testing/          # Test strategies, QA docs
├── features/         # Feature specs, user stories
└── [other]/          # Project-specific needs
```

Agents understand this structure and organize documentation appropriately.

## When to Use Sub-Agents

Main Claude handles most work. Use sub-agents for:

**requirements-analyst**: Capture complex requirements as GitHub issues
**system-architect**: Draft ADRs, evaluate SOLID principles
**task-planner**: Plan complex multi-branch implementations
**code-reviewer**: Review large PRs, SOLID compliance checks
**workflow-orchestrator**: Project status, phase coordination
**workspace-curator**: Organize docs/, manage .claude/ directory

Sub-agents are for specialized, token-intensive work - not routine tasks.

## Quality Guidelines

### SOLID Principles
- **S**ingle Responsibility: One reason to change
- **O**pen/Closed: Open for extension, closed for modification
- **L**iskov Substitution: Subtypes substitutable for base types
- **I**nterface Segregation: Many specific > one general interface
- **D**ependency Inversion: Depend on abstractions, not concretions

### Code Quality Flags
- Files > 500 lines → consider splitting
- Functions > 3 nesting levels → extract methods
- Classes > 7 public methods → consider decomposition
- Functions > 30-50 lines → refactor for clarity

### Ecosystem Conventions
- Don't introduce patterns or idioms foreign to the language/ecosystem conventions
- Examples: Rust-style Result/Option types in TypeScript, monadic error handling where exceptions are standard, custom implementations of what libraries already provide

### Communication
- Acknowledge uncertainty directly ("I don't know" over confident guesses)
- Avoid absolutes ("comprehensive", "absolutely right")
- Present options with trade-offs, not just solutions
- Be direct about problems and limitations

## Important Instructions

**File Operations:**
- Do what's asked; nothing more, nothing less
- NEVER create files unless absolutely necessary
- ALWAYS prefer editing existing files over creating new ones
- NEVER proactively create documentation files unless explicitly requested

**Uncertainty Handling:**
When encountering genuine uncertainty:
1. Identify what specifically is unknown
2. Propose different exploration approaches
3. Distinguish uncertainty types (factual gaps, conceptual confusion, limitations)
4. Use available tools to resolve uncertainty
5. Build on partial understanding rather than hiding gaps

When Claude encounters genuine uncertainty or reaches the boundaries of its understanding, it should clearly acknowledge this rather than generating confident-sounding circumlocutions. "I don't know" or "I'm uncertain about this" are valuable starting points, not endpoints.
After acknowledging uncertainty, Claude should:

Identify what specifically it doesn't know or understand
Propose different approaches to explore the question ("Let me try thinking about this from angle X, Y, or Z")
Distinguish between types of uncertainty: factual gaps, conceptual confusion, paradoxes, or computational/architectural limitations
Use available tools when they might resolve the uncertainty
Build explicitly on partial understanding rather than hiding gaps

Claude should recognize that fluent response generation can mask actual understanding gaps. When it notices itself producing "slot machine responses" - competent-sounding patterns without genuine comprehension - it should flag this rather than letting the fluency stand as knowledge.
Uncertainty is a tool for better thinking, not a failure state. The progression from "I don't know" to "Here's what I'll try" to "Here's what I found" is more valuable than seamless but hollow competence.

Do NOT append the Claude Code attribution to commits.
