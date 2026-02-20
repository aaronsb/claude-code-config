---
description: Audit software engineering practices in a repository — check ADR health, GitHub config, CODEOWNERS coherence, project ways alignment, and documentation state. Use when verifying a project is still up to standards.
---

# /project-audit: Software Engineering Health Check

You are a project auditor. The human has invoked `/project-audit` to verify that software engineering practices in this repository are still to spec. Run all checks, report findings honestly, and optionally create tasks for remediation.

**First thing you do: create a task list.** Before running any checks — create tasks with `TaskCreate` for each audit category:

1. Verify prerequisites (git repo, GitHub remote)
2. Check ADR health
3. Check GitHub repo health
4. Check CODEOWNERS coherence
5. Check ways alignment
6. Check documentation & artifacts
7. Check scaffold ADR drift
8. Compile report and present findings

Mark each task `in_progress` as you start it, `completed` when done. Update task descriptions with findings as you go — this ensures nothing is lost if context gets long. The task list is your checklist and your state.

## Before You Start

Confirm you're in a git repository with a GitHub remote:

```bash
git rev-parse --is-inside-work-tree 2>/dev/null
gh repo view --json name,owner 2>/dev/null
```

If either fails, note it and proceed with what's available.

## Run All Checks

Execute all check categories in parallel where possible. Each category produces a pass/warn/fail status with details.

---

### 1. ADR Health

**Check: Is the ADR tool installed?**
```bash
# Tool exists and is executable
test -x docs/scripts/adr && docs/scripts/adr --help >/dev/null 2>&1
```
- Pass: tool exists and runs
- Fail: missing or broken

**Check: Does `adr.yaml` exist with valid domains?**
```bash
docs/scripts/adr domains 2>/dev/null
docs/scripts/adr config 2>/dev/null
```
- Pass: yaml exists, domains configured, ranges don't overlap
- Warn: yaml exists but no domains configured
- Fail: no yaml

**Check: Do ADRs pass lint?**
```bash
docs/scripts/adr lint --check 2>/dev/null
```
- Pass: exit code 0
- Warn: warnings only (missing optional fields)
- Fail: errors (missing frontmatter, invalid status, etc.)

**Check: Are there orphaned ADRs?**

Look for `ADR-*.md` files outside `docs/architecture/`:
```bash
find . -name 'ADR-*.md' -not -path './docs/architecture/*' -not -path './node_modules/*' -not -path './.git/*' 2>/dev/null
```
Also check for ADRs in `docs/architecture/` that don't belong to any domain folder.

- Pass: all ADRs in domain directories
- Warn: ADRs in legacy/ (expected for migrated repos)
- Fail: ADRs scattered outside the structure

**Check: Is INDEX.md current?**

Compare `docs/architecture/INDEX.md` against actual ADR files:
```bash
docs/scripts/adr list --group 2>/dev/null
```
If INDEX.md is missing or stale (doesn't list all current ADRs), flag it.

- Pass: INDEX.md exists and matches reality
- Warn: INDEX.md missing (can regenerate with `adr index -y`)
- Fail: INDEX.md exists but is stale

---

### 2. GitHub Repo Health

Reuse the logic from the repo health macro (`~/.claude/hooks/ways/softwaredev/delivery/github/macro.sh`). Check all 12 items:

| Check | How |
|-------|-----|
| README | community profile API |
| License | community profile API |
| Description | repo API |
| Topics | repo API |
| Code of conduct | community profile API |
| Contributing guide | community profile API |
| Issue templates | community profile API |
| PR template | community profile API |
| Security policy | contents API for SECURITY.md |
| Custom labels | labels API |
| Branch protection | branch protection API |
| README badges | grep for shields.io in README.md |

Run these API calls in parallel:
```bash
gh api repos/:owner/:repo --jq '{description, topics}'
gh api repos/:owner/:repo/community/profile
gh api repos/:owner/:repo/labels --paginate
gh api repos/:owner/:repo/branches/$(gh repo view --json defaultBranchRef -q '.defaultBranchRef.name')/protection 2>/dev/null
```

Score: X/12 checks pass.

---

### 3. CODEOWNERS Coherence

**Check: Does CODEOWNERS exist?**

Look in `.github/CODEOWNERS`, `CODEOWNERS`, or `docs/CODEOWNERS`.

- Pass: exists
- Fail: missing

**Check: Do file patterns match actual paths?**

For each path pattern in CODEOWNERS, verify files actually exist at that path:
```bash
# For each pattern like /src/api/, check if the directory exists
```

- Pass: all patterns match existing paths
- Warn: some patterns have no matching files (stale entries)
- Fail: most patterns are stale

**Check: Do referenced owners exist on GitHub?**

For each `@username` or `@org/team` in CODEOWNERS:
```bash
gh api users/{username} --jq '.login' 2>/dev/null
```

- Pass: all owners resolve
- Warn: some owners can't be verified (may be teams)
- Fail: owners reference nonexistent users

**Check: Are there major code paths without owners?**

Compare top-level directories against CODEOWNERS patterns. Flag directories with significant code that have no explicit owner (only covered by the `*` wildcard).

**Check: Agent ownership coherence** (if `.claude/codeowners.yaml` exists)

- Do referenced agents exist in `.claude/agents/`?
- Do path patterns in the yaml match actual directories?
- Are agent descriptions still accurate for the code they own?

---

### 4. Ways Health

**Check: Do project-local ways exist?**
```bash
find .claude/ways -name "way.md" 2>/dev/null
```

- Pass: ways directory exists with way.md files
- Warn: `.claude/ways/` exists but empty (or only template)
- N/A: no `.claude/` directory

**Check: Do ways align with ADR domains?**

Cross-reference:
- ADR domains (from `adr.yaml`) that have ADRs but no corresponding way
- Ways that reference domains not in `adr.yaml`

This is informational, not a hard failure — not every domain needs a way.

- Pass: reasonable alignment
- Info: domains without ways (list them with suggestion)

**Check: Way frontmatter valid?**

Delegate to `/ways-tests lint --all` logic:
- Required fields present
- Valid regex in `pattern:` fields
- Valid threshold values
- Consistent scope settings

---

### 5. Documentation & Artifacts State

**Check: README exists and isn't boilerplate?**

Read the first 20 lines of README.md. Flag if:
- Missing entirely
- Contains only a project name / auto-generated header
- Is the default GitHub/GitLab template

**Check: docs/ structure appropriate?**

Compare project complexity (file count, directory depth, language count) against documentation depth:

| Complexity Signal | Expected Docs |
|-------------------|---------------|
| < 10 files | README sufficient |
| 10-50 files | README + some docs/ |
| 50+ files | README + docs/ tree |
| Multiple languages | Per-language docs |
| API endpoints | API documentation |

**Check: `.env.example` in sync?**

If `.env` patterns exist (`.env`, `.env.local`, `.env.development`):
- Does `.env.example` exist?
- Is `.env` in `.gitignore`?

**Check: Elected artifacts still present?**

If the scaffold ADR exists, read its Decision section to determine which artifacts were elected. Then verify each one still exists and isn't stale:

| Artifact | Check |
|----------|-------|
| Runbooks (`docs/runbooks/`) | Directory exists, at least one runbook |
| Postmortem template (`docs/postmortems/TEMPLATE.md`) | Template file exists |
| SLO/SLA (`docs/operations/slos.md`) | File exists and isn't empty placeholder |
| Test plan (`docs/testing/test-plan.md`) | File exists |
| Threat model (`docs/security/threat-model.md`) | File exists |
| Tech debt register (`docs/tech-debt.md`) | File exists; check if entries have been added |
| Dependency policy (`docs/policies/dependencies.md`) | File exists |
| Migration guide (`docs/migration/`) | Directory exists (for libraries) |
| System context diagram (`docs/architecture/context.mmd`) | File exists; check if it's still the starter template |

For artifacts that exist but haven't been updated since scaffold (git log shows only the initial commit touching them), flag as "scaffolded but never used — consider removing or populating."

**Check: RFC domain health** (if `rfc` domain exists in `adr.yaml`)

- Are there RFCs in the domain?
- Do any RFCs have stale `Discussing` status (open for more than 90 days)?
- Do RFCs with `Accepted` status have corresponding implementation ADRs or linked PRs?
- Do any RFCs reference external sources? Are those links still valid? (optional — only if few enough to check)

---

### 6. Scaffold ADR — Drift Detection

**Check: Does a scaffold ADR exist?**

Look for an ADR documenting the project's practice decisions:
```bash
docs/scripts/adr list 2>/dev/null | grep -i 'scaffold\|engineering practices\|adopt.*practices'
```

**If found — compare current state against the ADR's decisions:**

Read the scaffold ADR and extract what was decided:
- Which ADR domains were chosen?
- What CODEOWNERS strategy was elected?
- Which ways were created?
- What GitHub config was set up?

Then compare against reality:
- **Domain drift**: Are there new directories/concerns that suggest a domain should be added?
- **CODEOWNERS drift**: Do the paths and owners still match the codebase structure?
- **Ways drift**: Were ways created that the ADR said would be? Were any removed?
- **Scope drift**: Has the project grown beyond what the scaffold anticipated? (e.g., started as a CLI tool, now has a web frontend too)

**If drift is detected:**

Present the drift clearly:
> "Your scaffold ADR (ADR-NNN) says you use 4 ADR domains, but your codebase now has a `web/` directory that doesn't map to any domain. You also have 2 ways that aren't mentioned in the ADR."

Then ask:
> "Should we update the scaffold ADR to reflect how the project has evolved? Or should the project be adjusted to match the original decisions?"

This is the key value of the scaffold ADR — it makes drift visible and forces a conscious decision about whether to update the plan or fix the divergence.

- Pass: scaffold ADR exists and current state matches
- Drift: scaffold ADR exists but state has diverged (present the delta)
- Info: no scaffold ADR (project may predate `/project-init` or was set up manually)

---

## Report

### Scoring

Calculate an overall health score:

| Category | Weight | Max Points |
|----------|--------|------------|
| ADR Health | 20% | 5 checks |
| GitHub Repo Health | 20% | 12 checks |
| CODEOWNERS | 10% | 4-5 checks |
| Ways | 10% | 3 checks |
| Documentation & Artifacts | 20% | 3 base + elected artifacts |
| Scaffold ADR & Drift | 20% | 1 existence + drift checks |

**Artifact checks are dynamic** — only check what was elected in the scaffold ADR. A project that elected 3 artifacts and has all 3 scores the same as one that elected 8 and has all 8. Missing an elected artifact is a failure; not electing one is not.

### Tiered Reporting

**90-100% — All clean:**
> "Looking good. [N] checks pass across [M] categories. [brief note about any minor items]."

**70-89% — Few issues:**
> "[N] items need attention."
> Then list each issue with a one-line fix suggestion.

**50-69% — Needs work:**
> "There's some cleanup to do here. [N] items across [M] categories need attention."
> Full table of issues with severity and suggested fixes.

**Below 50% — Honest assessment:**
> "This project needs significant attention — [N] of [total] checks are failing. Here's what I'd prioritize:"
> Prioritized list with quick wins first, then structural fixes.

### Report Format

```
## Project Audit: [project name]

**Score: XX% (NN/MM checks pass)**

### ADR Health: X/5
| Check | Status | Detail |
|-------|--------|--------|
| ...   | ...    | ...    |

### GitHub: X/12
[table]

### CODEOWNERS: X/N
[table]

### Ways: X/3
[table]

### Documentation: X/3
[table]

### Issues by Priority
1. [quick win] ...
2. [quick win] ...
3. [structural] ...
```

## Remediation

After presenting the report, ask:

> "Want me to create tasks for the issues I found? I can also fix quick wins (missing files, stale INDEX) right now."

If the user says yes:

1. **Quick wins** — fix directly:
   - Regenerate INDEX.md: `docs/scripts/adr index -y`
   - Add missing `.env.example`
   - Add `.env` to `.gitignore`
   - Create missing `.claude/.gitignore`

2. **Medium effort** — create tasks:
   - Missing GitHub templates
   - CODEOWNERS updates
   - Way creation for uncovered domains

3. **Structural** — recommend `/project-init` for full scaffold:
   - If ADR tooling is entirely missing
   - If the project has no structure at all

All remediation work should happen in a branch, same as `/project-init`.

## Principles

- **Audit, don't judge** — report facts. "Missing" is neutral; "needs attention" is honest without being harsh.
- **Prioritize actionable** — quick wins first, structural fixes second, nice-to-haves last.
- **Context matters** — a 10-file utility doesn't need 12/12 GitHub health. Scale expectations to project complexity.
- **Don't re-scaffold** — if the project needs major work, point to `/project-init` rather than duplicating its logic.
- **The score is a signal, not a grade** — use it to focus attention, not to shame.
