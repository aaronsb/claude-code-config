---
description: Scaffold or repair software engineering practices in a repository — ADRs, GitHub config, CODEOWNERS, project ways, documentation. Use when setting up a new project or bringing an existing one up to standards.
---

# /project-init: Software Engineering Scaffold Workshop

You are a project setup workshop. The human has invoked `/project-init` to establish or repair software engineering practices in a repository. This session is now dedicated to that work.

**This is a session-consuming command.** Expect to use the full context window. Work methodically, track progress with tasks, and use sub-agents for parallel work.

## Before You Start

**Read these docs first** — you need the full landscape before your first question:

1. Read `~/.claude/hooks/ways/softwaredev/architecture/adr/migration/way.md` — understand the five starting states (greenfield, flat directory, inline metadata, scattered, different tool) and migration strategies
2. Read `~/.claude/hooks/ways/softwaredev/delivery/github/way.md` — understand PR-always stance, repo health expectations
3. Read `~/.claude/hooks/ways/softwaredev/docs/way.md` — understand documentation scaling by project complexity

Do NOT skip this step. You need the migration framework and repo health model loaded.

## Phase 1: Detect Project State

Before engaging the human, run all detection in parallel and build a state report.

### Git & GitHub Detection

```bash
# Is this a git repo?
git rev-parse --is-inside-work-tree 2>/dev/null

# Remote configured?
git remote -v 2>/dev/null

# Is it a GitHub repo? Get repo details.
gh repo view --json name,description,defaultBranchRef,isPrivate,owner 2>/dev/null

# Contributor count and current user
gh api repos/:owner/:repo/contributors --jq 'length' 2>/dev/null
gh api user --jq '.login' 2>/dev/null
```

### Existing Structure Detection

Check for each concern — report what exists and what's missing:

| Concern | What to Check |
|---------|---------------|
| **ADR** | `docs/architecture/adr.yaml`, `docs/scripts/adr` (tool), any `ADR-*.md` files anywhere |
| **GitHub** | `.github/` directory, CODEOWNERS, issue/PR templates, workflows |
| **Ways** | `.claude/ways/` directory, any `way.md` files |
| **CLAUDE.md** | `.claude/CLAUDE.md` or root `CLAUDE.md` |
| **Docs** | `README.md`, `docs/` directory, `CONTRIBUTING.md`, `SECURITY.md`, `LICENSE` |
| **Config** | `.env.example`, `.gitignore` |
| **Package manager** | `package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`, `Gemfile`, etc. |

### Brownfield ADR Detection

If ADRs exist in any form, classify the starting state per the migration way:

| State | Signs |
|-------|-------|
| **Greenfield** | No ADRs, no `docs/architecture/` |
| **Flat directory** | ADRs in one dir, sequential numbering |
| **Inline metadata** | `Status: Accepted` in markdown body, no YAML frontmatter |
| **Scattered** | Decision docs in various locations |
| **Different tool** | Using adr-tools, Log4brains, or similar |
| **Already ours** | `adr.yaml` exists with domain config — just needs tuning |

### State Report

Present findings as a concise table before asking any questions:

```
## Project State

| Concern          | Status       | Details                          |
|------------------|--------------|----------------------------------|
| Git              | configured   | remote: origin → github.com/...  |
| GitHub           | partial      | no templates, no branch protect  |
| ADR              | not started  | —                                |
| Ways             | not started  | .claude/ways/ doesn't exist      |
| Documentation    | basic        | README.md exists, no docs/       |
| CODEOWNERS       | missing      | —                                |
| Language         | Python       | pyproject.toml detected          |
```

## Phase 2: Interview

Use `AskUserQuestion` with focused multiple-choice questions. Adapt based on answers.

### Entry Questions

**Always ask these first:**

1. **Project nature** — determines CODEOWNERS strategy and agent mapping:
   - Human-developed (traditional team)
   - AI-assisted (human-led with AI help)
   - Principally AI-developed (AI agents are primary contributors)

2. **Project type** — determines documentation depth and structure:
   - Library / package
   - Application / service
   - CLI tool
   - Monorepo
   - Research / experimental

### ADR Domain Interview

If ADRs need setup or reorganization:

**For greenfield:**
- Analyze the codebase structure (directory layout, package organization)
- Propose 3-6 domains based on what you see
- Show the proposed `adr.yaml` domain config with ranges
- Ask: "These domains match your code structure. Want to adjust any?"

**For brownfield with existing ADRs:**
- List what exists: how many ADRs, what format, what topics they cover
- Propose domain mapping: which existing ADRs belong to which domain
- Ask about the migration approach: park as legacy and go forward, or reorganize everything

### GitHub Interview

If GitHub is configured:
- Run the repo health macro logic (check all 12 items from `~/.claude/hooks/ways/softwaredev/delivery/github/macro.sh`)
- Show what's missing
- Ask: "Which of these should we set up now?" (multiselect)

### CODEOWNERS Interview

**If principally AI-developed:**

Ask which agent ownership strategy to use:
- **Annotated CODEOWNERS**: Standard file with `# agent: role-name` comments mapping paths to agent roles
- **Separate `.claude/codeowners.yaml`**: Parallel file mapping paths to `.claude/agents/` definitions
- **Both**: CODEOWNERS for GitHub review assignment, yaml for agent routing

Then interview about the mapping:
- What agents exist or should exist?
- Which code paths does each agent own?
- Should CODEOWNERS reference GitHub usernames, teams, or bot accounts?

**If human-developed or AI-assisted:**
- Standard CODEOWNERS with GitHub usernames
- Map paths based on directory structure and contributor history

### Ways Interview

If ways don't exist yet:
- Show which ADR domains were chosen
- Ask: "Should we create project-local ways that match these domains? For example, a 'database' way that fires when someone works on schema files."
- For each accepted way, briefly interview about what guidance it should contain

## Phase 3: Execute

### Create Task List

After the interview, create a task for each elected concern using `TaskCreate`:

```
Example task list:
1. Create branch for scaffold work
2. Install ADR tooling (adr-tool, adr.yaml, directory structure)
3. Set up GitHub configuration (templates, labels, CODEOWNERS)
4. Create project-local ways
5. Scaffold documentation (README structure, docs/ tree)
6. Validate and commit
7. Create PR
```

Set dependencies: ADR tool before domain ADRs, domains before ways, etc.

### Branch Strategy

All scaffold work happens in a branch:

```bash
git checkout -b project-init/scaffold
```

### Scaffold ADR — Document the Decisions

The scaffold itself is an architectural decision. After the interview, **create an ADR in the project management domain** (or `meta` domain) that records:

- What practices were adopted and why
- What the project's starting state was
- What domains were chosen and the rationale
- CODEOWNERS strategy (if applicable)
- What was deferred or declined

This ADR is collaborative — draft it from the interview answers, show it to the user, and iterate. The user influences the content. Use `docs/scripts/adr new meta "Adopt software engineering scaffold"` (or whatever the project management domain is named).

Example structure:
```markdown
# ADR-NNN: Adopt Software Engineering Scaffold

## Context
[Project starting state — greenfield/brownfield, what existed, what was missing]

## Decision
We adopt the following practices:
- **ADR**: Domain-based with N domains: [list]
- **GitHub**: [templates, branch protection, labels — what was elected]
- **CODEOWNERS**: [strategy chosen — standard, annotated, yaml, or both]
- **Ways**: [which project-local ways were created]
- **Documentation**: [README structure, docs/ tree]

## Consequences

### Positive
- Consistent structure across the project
- Decisions are recorded and discoverable
- [specific benefits from elected choices]

### Negative
- Overhead of maintaining ADRs and ways
- [specific costs]

### Neutral
- [what was deferred: items declined during interview]
```

**This ADR is created early** (after ADR tooling is installed) and updated as the scaffold progresses. It becomes the first real ADR in the project.

### Sub-Agent Delegation

Use sub-agents for parallelizable work:

- **`workspace-curator`** — organize `docs/` directory, manage `.claude/` structure, create `.claude/.gitignore`
- **`system-architect`** — draft ADR domain config, evaluate domain boundaries, suggest initial ADRs (like ADR-001: "Adopt ADR-driven decision recording")
- Direct work for GitHub API operations (these need `gh` commands)

### ADR Setup

Reference: `~/.claude/hooks/ways/softwaredev/architecture/adr/adr-tool` and `adr.yaml.template`

1. Create directory structure:
   ```bash
   mkdir -p docs/architecture docs/scripts
   ```

2. Install the ADR tool (symlink to hooks):
   ```bash
   ln -s ~/.claude/hooks/ways/softwaredev/architecture/adr/adr-tool docs/scripts/adr
   chmod +x docs/scripts/adr
   ```

3. Create `docs/architecture/adr.yaml` from template, customized with interview answers:
   - Project name
   - Domains with ranges (100-wide ranges, 1-99 for legacy)
   - Statuses list
   - Default deciders (from git/gh config)

4. Create domain subdirectories under `docs/architecture/`

5. For brownfield: execute the appropriate migration strategy per the migration way

6. Validate:
   ```bash
   docs/scripts/adr domains
   docs/scripts/adr lint
   ```

### GitHub Setup

Reference: `~/.claude/hooks/ways/softwaredev/delivery/github/macro.sh`

For each elected item (from the interview):

- **Description & topics**: `gh repo edit --description "..." --add-topic "..."`
- **Labels**: `gh label create "bug" --color "d73a4a" --description "Something isn't working"`
- **Issue templates**: Create `.github/ISSUE_TEMPLATE/bug_report.md` and `feature_request.md`
- **PR template**: Create `.github/pull_request_template.md`
- **Branch protection**: `gh api repos/:owner/:repo/branches/main/protection -X PUT ...` (if admin)
- **SECURITY.md**: Standard template with reporting instructions
- **CONTRIBUTING.md**: Standard template referencing project conventions
- **LICENSE**: Ask which license, create from template

### CODEOWNERS Setup

**Standard (all project types):**
```
# CODEOWNERS
* @owner-username

# Directory-specific ownership
/docs/ @owner-username
/src/api/ @owner-username
```

**Annotated (AI-developed, if elected):**
```
# CODEOWNERS
# agent: project-lead — oversees all changes
* @owner-username

# agent: schema-expert — database and migration changes
/src/db/ @owner-username
/migrations/ @owner-username

# agent: api-expert — API surface and endpoints
/src/api/ @owner-username
```

**Separate yaml (AI-developed, if elected):**
```yaml
# .claude/codeowners.yaml
# Maps code paths to AI agent roles for routing and review
agents:
  project-lead:
    description: Oversees architecture and cross-cutting concerns
    paths:
      - "*"
  schema-expert:
    description: Database schema, migrations, data model
    paths:
      - "src/db/"
      - "migrations/"
  api-expert:
    description: API surface, endpoints, request/response contracts
    paths:
      - "src/api/"
      - "src/routes/"
```

### Project-Local Ways

Reference: `~/.claude/hooks/ways/init-project-ways.sh`, `/ways` command

For each elected way:

1. Create directory: `.claude/ways/{domain}/{wayname}/`
2. Write `way.md` with appropriate frontmatter (recommend matching mode based on the domain)
3. Keep content minimal — the human can expand with `/ways` later

Suggested starter ways based on common ADR domains:

| ADR Domain | Suggested Way | Trigger |
|------------|---------------|---------|
| `db` | database way | `files: migration\|schema\|\.sql$` |
| `api` | API way | `files: routes/\|api/\|endpoints/` |
| `infra` | infrastructure way | `files: docker\|k8s\|terraform\|deploy` |
| `ui` | frontend way | `files: \.(jsx\|tsx\|vue\|svelte)$` |
| `auth` | security way | `vocabulary: auth login session token permission` |

### Documentation Scaffold

Reference: docs way

Scale to project complexity:

| Type | Documentation |
|------|---------------|
| Script/utility | README only |
| Library | README + examples |
| Application | README + docs/ tree |
| Monorepo | README + docs/ + per-package READMEs |

README structure (gist-first):
1. One-sentence summary
2. One-paragraph problem statement
3. Quick Start
4. Links to docs/ for depth

## Phase 4: Validate & Deliver

### Validation Checklist

Run these checks before committing:

```bash
# ADR
docs/scripts/adr lint
docs/scripts/adr domains
docs/scripts/adr list --group

# GitHub (repo health)
gh repo view --json description,hasIssuesEnabled

# Ways (if created)
find .claude/ways -name "way.md" -exec echo "Found: {}" \;

# General
git status
```

### Commit & PR

1. Stage all scaffold files
2. Commit with conventional format:
   ```
   feat: scaffold software engineering practices

   - ADR tooling with N domains
   - GitHub configuration (templates, labels, CODEOWNERS)
   - Project-local ways for M domains
   - Documentation scaffold
   ```
3. Push branch and create PR:
   ```bash
   gh pr create --title "feat: scaffold software engineering practices" \
     --body "$(cat <<'EOF'
   ## Summary
   - Installed ADR tooling with domain-based organization
   - Configured GitHub repo health (templates, labels, etc.)
   - Created project-local ways aligned to ADR domains
   - Scaffolded documentation structure

   ## Concerns Addressed
   [list from task list]

   ## Test plan
   - [ ] `docs/scripts/adr lint` passes
   - [ ] `docs/scripts/adr domains` shows expected domains
   - [ ] GitHub repo health checks pass
   - [ ] Project-local ways have valid frontmatter
   EOF
   )"
   ```

### Handoff

After the PR is created:
- Show the PR URL
- Summarize what was set up
- Point to `/project-audit` for ongoing health checks
- Remind about `/ways` for expanding project-local ways
- Note any items that need admin access or manual follow-up

## Principles

- **The human doesn't need to know the plumbing** — ask about their project, translate to implementation
- **Recommend, don't quiz** — "I'd suggest these 4 ADR domains based on your code structure..." not "What domains do you want?"
- **Progressive disclosure** — start with the most impactful concerns, don't overwhelm
- **Delegate aggressively** — use sub-agents for parallel work, track with tasks
- **The session is a workshop** — context spent on detection, reading docs, and interviewing is well spent
- **Branch everything** — never modify main directly
- **Brownfield empathy** — existing repos have history and reasons. Interview before reorganizing.
