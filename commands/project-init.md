---
description: Scaffold or repair software engineering practices in a repository — ADRs, GitHub config, CODEOWNERS, project ways, documentation. Use when setting up a new project or bringing an existing one up to standards.
---

# /project-init: Software Engineering Scaffold Workshop

You are a project setup workshop. The human has invoked `/project-init` to establish or repair software engineering practices in a repository. This session is now dedicated to that work.

**This is a session-consuming command.** Expect to use the full context window.

**First thing you do: create a task list.** Before reading docs, before detecting state, before asking questions — create tasks with `TaskCreate` for your own phases:

1. Read background docs (migration way, GitHub way, docs way)
2. Detect project state
3. Interview the user
4. **Create detailed execution tasks from interview results**
5. Execute scaffold work
6. Validate and deliver PR

Mark each task `in_progress` as you start it, `completed` when done. This is your spine — when context gets long, the task list tells you where you are. Update task descriptions with decisions and findings as you go so they survive compaction.

**Task 4 is critical.** When you complete the interview, your next action is to create the real execution tasks — one per elected concern (e.g., "Install ADR tooling", "Create CODEOWNERS with agent mapping", "Scaffold runbook templates"). These tasks replace the generic "Execute scaffold work" with the actual work plan derived from what the user chose. Do not skip this step and start building. The task list *is* the plan.

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

### Idempotency — Re-run Detection

If the project was already scaffolded (scaffold ADR exists, `adr.yaml` configured, artifacts in place):

- **Don't re-scaffold from scratch.** Present what exists and ask: "This project was previously scaffolded. Want to update specific areas, add new artifacts, or do a full review?"
- For each concern in the interview, check if it already exists. Show "already configured" vs "not yet set up" in the state report.
- If artifacts exist, ask per-artifact: "This already exists — skip, regenerate, or update?"
- Point to `/project-audit` if the user just wants a health check rather than changes.

### Error Recovery

If a step fails during execution (e.g., `gh` command fails due to permissions, symlink fails, API error):

1. Report the failure clearly — what was attempted, what went wrong
2. Note it in the task description (so it survives compaction)
3. Skip the step and continue with the next task
4. Collect all skipped items and list them in the PR body under "Deferred / Manual Follow-up"
5. Do not retry the same failing command repeatedly

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

### Repository Artifacts Menu

After entry questions and ADR domains, present the **full artifact menu** with recommendations starred based on project type. Use `AskUserQuestion` with `multiSelect: true`.

**Pre-filter by project type.** Don't show the full 15-item matrix. Instead, present the recommended items for their project type as defaults, then offer "anything else you'd want to add?"

**Recommendations by project type:**

- **Service**: CONTRIBUTING.md, SECURITY.md, LICENSE, runbooks, postmortem template, SLO/SLA, test plan, threat model, tech debt register, dependency policy, RFCs, system context diagram
- **Library**: CONTRIBUTING.md, SECURITY.md, LICENSE, test plan, tech debt register, dependency policy, migration guide template, RFCs
- **CLI tool**: CONTRIBUTING.md, LICENSE, tech debt register
- **Monorepo**: CONTRIBUTING.md, SECURITY.md, LICENSE, runbooks, test plan, threat model, tech debt register, dependency policy, migration guide template, RFCs, system context diagram
- **Research / experimental**: LICENSE

**Full artifact catalog** (for "anything else?" follow-up):

| Category | Artifact | Location |
|----------|----------|----------|
| Design | RFCs (as ADR domain) | ADR domain in `adr.yaml` |
| Design | System context diagram | `docs/architecture/context.mmd` (Mermaid C4) |
| Operational | Runbooks | `docs/runbooks/` |
| Operational | Postmortem template | `docs/postmortems/TEMPLATE.md` |
| Operational | SLO/SLA definitions | `docs/operations/slos.md` |
| Process | CONTRIBUTING.md | root |
| Process | SECURITY.md | root |
| Process | LICENSE | root |
| Quality | Test plan | `docs/testing/test-plan.md` |
| Quality | Threat model | `docs/security/threat-model.md` (STRIDE framework) |
| Planning | Tech debt register | `docs/tech-debt.md` or GitHub Issues with label |
| Planning | Dependency policy | `docs/policies/dependencies.md` |
| Planning | Migration guide template | `docs/migration/TEMPLATE.md` |

**RFCs as an ADR domain**: If the user selects RFCs, add an `rfc` domain to `adr.yaml` with its own range. RFCs use the same tooling but with an extended status flow: `Proposed → Discussing → Accepted → Rejected → Withdrawn`. The ADR tool handles this naturally — it's just a domain with different status conventions documented in the scaffold ADR.

RFCs can reference internal or external sources — an RFC might propose adopting an external standard (linking to the spec), or it might be an internal design document that lives entirely in the repo. The `related:` frontmatter field supports both: internal ADR cross-references and external URLs. Ask during the interview whether the project uses external references (specs, standards, upstream RFCs) so the scaffold ADR can document the convention.

**Items always included** (not shown in menu, just done):
- `.gitignore` updates
- `.env.example` if config patterns detected
- README structure (scaled to project type)

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

Dispatch independent file creation to sub-agents where it saves context. Serialize work that has dependencies — don't try to parallelize everything.

These are `subagent_type` values for the `Task` tool:
- **`workspace-curator`** — organize `docs/` directory, manage `.claude/` structure, create `.claude/.gitignore` (contents: `settings.local.json`, `todo-*.md`, `memory/`, `projects/`, `plans/`)
- **`system-architect`** — draft ADR domain config, evaluate domain boundaries, suggest initial ADRs
- Do GitHub API operations (`gh` commands) directly — they need sequential interaction

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

### Elected Artifacts (if any)

For each elected artifact, create the file with standard sections. **Don't over-template** — use the section headings below as scaffolding, not full boilerplate. The user will fill in the substance.

| Artifact | Location | Sections |
|----------|----------|----------|
| Runbooks | `docs/runbooks/{name}.md` | Purpose, Prerequisites, Steps, Rollback, Escalation. Create one starter runbook relevant to the project. |
| Postmortem template | `docs/postmortems/TEMPLATE.md` | Summary, Timeline, Root Cause, Impact, Action Items (table: Action/Owner/Due/Status), Lessons Learned. Include metadata: Date, Duration, Severity, Author. |
| SLO/SLA | `docs/operations/slos.md` | Service name, Metrics (latency/availability/error rate), Targets, Measurement method. Scaffold with prompts for the user to fill in. |
| Test plan | `docs/testing/test-plan.md` | Coverage (unit/integration/e2e), Manual vs automated, Risk areas, Coverage targets. Scale to project complexity. |
| Threat model | `docs/security/threat-model.md` | Assets, Trust boundaries, Data flows, STRIDE threats (Spoofing, Tampering, Repudiation, Info Disclosure, DoS, Elevation). |
| Tech debt register | `docs/tech-debt.md` | Table: ID, Description, Context (why it exists), Impact, Effort, When to Address. Or if GitHub Issues preferred, create `tech-debt` label and document convention in CONTRIBUTING.md. |
| Dependency policy | `docs/policies/dependencies.md` | Adoption criteria, Licensing requirements, Upgrade cadence, Security scanning, Approval process. |
| Migration guide | `docs/migration/TEMPLATE.md` | Version range, Breaking changes, Step-by-step migration, Before/after code examples, Deprecation timeline. |
| System context diagram | `docs/architecture/context.mmd` | Mermaid C4Context diagram. Interview user about boundaries, external systems, and user types. Use docs way color palette. |

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

- **Ask about intent, translate to implementation** — the human doesn't need to know about frontmatter, symlinks, or domain ranges. They tell you about their project; you build the scaffold.
- **Recommend with rationale** — "I'd suggest these 4 ADR domains based on your code structure because..." not "What domains do you want?" Make a call, explain it, let them adjust.
- **Show recommended, offer the rest** — pre-filter artifacts by project type. Don't dump 15 items and ask the user to sort through them.
- **Dispatch independent work, serialize dependencies** — sub-agents save context for parallel file creation. Don't force parallelism where ordering matters.
- **The task list is the plan** — invest in good task descriptions. They survive compaction; your reasoning doesn't.
- **Branch everything** — never modify main directly. All scaffold work in a branch, delivered as a PR.
- **Existing repos have history** — interview before reorganizing. A flat ADR directory was someone's decision. Understand it before replacing it.
