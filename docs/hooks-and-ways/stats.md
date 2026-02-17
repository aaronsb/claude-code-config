# Stats and Observability

You can't manage what you can't see. The ways system logs every firing event and provides tools to understand how governance is actually being applied across sessions, projects, and teams.

## What Gets Logged

Every time a way fires, `log-event.sh` appends a line to `~/.claude/stats/events.jsonl`:

```json
{"ts":"2026-02-05T19:00:34Z","event":"way_fired","way":"softwaredev/delivery/commits","domain":"softwaredev","trigger":"bash","scope":"agent","project":"/home/you/myproject","session":"abc-123"}
```

Session start events are also logged. For teammates, the team name is included:

```json
{"ts":"2026-02-05T19:01:12Z","event":"way_fired","way":"meta/teams","domain":"meta","trigger":"state","scope":"teammate","project":"/home/you/myproject","session":"def-456","team":"my-refactor-team"}
```

The log is append-only JSONL. Each line is self-contained. Nothing reads this file during normal operation — it's purely for after-the-fact analysis.

## Reading the Stats

Run the stats tool:

```bash
bash ~/.claude/hooks/ways/stats.sh
```

### Sample Output

```
Ways of Working - Usage Stats
==============================
Period: 2026-02-05 → 2026-02-06

Sessions: 11  |  Way fires: 458

Top ways:
  meta/todos                      96  ████████████████████
  meta/memory                     96  ████████████████████
  meta/knowledge                  30  ██████
  softwaredev/delivery/commits    19  ███
  softwaredev/architecture/design 18  ███

By scope:
  agent        319
  unknown       34
  teammate      32
  subagent      27

By team:
  adr-500-spec                    26 fires

By trigger:
  state      197 (43%)
  bash        76 (16%)
  prompt      71 (15%)

By project:
  ~/Projects/ai/knowledge-graph    391 fires (20 sessions)
  ~/.claude                         55 fires (10 sessions)

Last 24h: 11 sessions, 458 way fires
```

### How to Interpret It

**Top ways** tells you which governance is actually active. If `meta/todos` and `meta/memory` dominate, your sessions are long enough to hit context thresholds regularly — the system is doing its job keeping state persistent. If a domain-specific way never appears, either the trigger patterns don't match your workflow or the domain is disabled.

**By scope** shows who's receiving governance. `agent` is your main sessions. `teammate` means team members got their coordination norms. `subagent` means delegated tasks received relevant ways. `unknown` is from older events logged before scope tracking existed — it ages out naturally.

**By team** appears only when teams have been used. It shows which teams triggered the most governance. A team with many fires was doing complex, varied work. A team with few fires was focused on something narrow that only matched a couple of ways.

**By trigger** reveals *how* ways are being activated:
- `state` — context-threshold and session-start triggers (the system managing itself)
- `bash` — command matching (git commit, npm install, etc.)
- `prompt` — keyword/semantic matching against what you typed
- `file` — file path matching (editing .env, README.md, etc.)
- `teammate`/`subagent` — injected into spawned agents

**By project** shows governance distribution across your work. A project with many fires is one where the ways are highly relevant. A project with few fires either doesn't trigger many patterns or has a focused workflow.

### Filtering

```bash
# Last 7 days
bash ~/.claude/hooks/ways/stats.sh --days 7

# Single project
bash ~/.claude/hooks/ways/stats.sh --project /path/to/project

# Machine-readable JSON
bash ~/.claude/hooks/ways/stats.sh --json

# Project overview (sessions, memory, way fires per project)
bash ~/.claude/hooks/ways/stats.sh --projects
```

### JSON Output

The `--json` flag returns structured data for tooling:

```json
{
  "total_events": 458,
  "sessions": 11,
  "way_fires": 412,
  "by_way": {"meta/todos": 96, "meta/memory": 96, ...},
  "by_trigger": {"state": 197, "bash": 76, ...},
  "by_scope": {"agent": 319, "teammate": 32, ...},
  "by_team": {"adr-500-spec": 26},
  "by_project": {"/home/you/project": 391, ...}
}
```

## What the Stats Don't Tell You

The stats show *what fired*, not *whether it helped*. A way that fires 96 times isn't necessarily 96 times useful — it might be triggering too broadly. A way that never fires isn't necessarily broken — it might be waiting for a workflow you haven't hit yet.

Use the stats to spot patterns: ways that fire too often (noisy triggers), ways that never fire (dead patterns or disabled domains), scopes that are unexpectedly empty (scope gating too aggressive), and teams that generate unusual activity (worth investigating what they were doing).

## Where the Data Lives

| File | Purpose |
|------|---------|
| `~/.claude/stats/events.jsonl` | Append-only event log |
| `/tmp/.claude-config-update-state-{uid}` | Update check cache (hourly) |
| `/tmp/.claude-way-{name}-{session}` | Way firing markers (per-session) |
| `/tmp/.claude-teammate-{session}` | Teammate scope markers (contains team name) |
| `/tmp/.claude-tasks-active-{session}` | Context-threshold nag suppression |
