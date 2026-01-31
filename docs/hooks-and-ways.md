# Hooks and Ways System

How contextual guidance gets injected into Claude Code sessions.

## Hook Events

Four Claude Code hook events drive the system. Each fires shell scripts that scan for matching ways and inject their content.

| Event | When | Scripts |
|-------|------|---------|
| **SessionStart** (startup) | Fresh session | `clear-markers.sh`, `show-core.sh`, `init-project-ways.sh`, `check-config-updates.sh` |
| **SessionStart** (compact) | After compaction | `clear-markers.sh`, `show-core.sh` |
| **UserPromptSubmit** | Every user message | `check-prompt.sh`, `check-state.sh` |
| **PreToolUse** (Edit\|Write) | Before file edit | `check-file-pre.sh` |
| **PreToolUse** (Bash) | Before command | `check-bash-pre.sh` |
| **PreToolUse** (TaskCreate) | Before task creation | `mark-tasks-active.sh` |
| **Stop** | After Claude responds | `check-response.sh` |

## What Each Script Does

### Session Lifecycle

- **`clear-markers.sh`** - Removes all `/tmp/.claude-way-*` and `/tmp/.claude-tasks-active-*` markers. Resets session state so ways can fire fresh.
- **`show-core.sh`** - Runs `macro.sh` to generate the Available Ways table, then outputs `core.md` (collaboration style, communication norms). This is the initial context Claude sees.
- **`init-project-ways.sh`** - Creates `$PROJECT/.claude/ways/_template.md` if the project has a `.claude/` or `.git/` dir but no ways directory yet.
- **`check-config-updates.sh`** - Once-per-day check for plugin updates.

### Trigger Evaluation

- **`check-prompt.sh`** - Scans all ways for `pattern:` (regex), `match: semantic`, or `match: model` fields. Tests the user's prompt against each. Fires matching ways via `show-way.sh`.
- **`check-bash-pre.sh`** - Scans ways for `commands:` patterns. Tests the command about to run. Also checks `pattern:` against the command description.
- **`check-file-pre.sh`** - Scans ways for `files:` patterns. Tests the file path about to be edited.
- **`check-state.sh`** - Evaluates `trigger:` fields (context-threshold, file-exists, session-start). See [State Triggers](#state-triggers).

### State Management

- **`mark-tasks-active.sh`** - Creates `/tmp/.claude-tasks-active-{session_id}`. Silences the context-threshold nag.
- **`check-response.sh`** - Extracts technical keywords from Claude's last response, writes to `/tmp/claude-response-topics-{session_id}`. These topics feed back into `check-prompt.sh` on the next turn, so ways can trigger based on what Claude discussed (not just what the user asked).

### Way Display

- **`show-way.sh`** - The central display function. Given a way path and session ID: checks domain disable list, checks marker, runs macro if configured, outputs content (stripping frontmatter), creates marker.
- **`macro.sh`** - Generates the dynamic Available Ways table by scanning all `way.md` files and extracting their trigger patterns.

## Session Lifecycle

```mermaid
sequenceDiagram
    participant CC as Claude Code
    participant CM as clear-markers.sh
    participant SC as show-core.sh
    participant IP as init-project-ways.sh
    participant Ctx as Claude Context

    rect rgba(66, 165, 245, 0.15)
        Note over CC,Ctx: Session Start (startup)
        CC->>CM: SessionStart:startup
        CM->>CM: rm /tmp/.claude-way-*
        CM->>CM: rm /tmp/.claude-tasks-active-*
        CC->>SC: SessionStart:startup
        SC->>SC: macro.sh → Available Ways table
        SC->>Ctx: core.md (collaboration norms)
        CC->>IP: SessionStart:startup
        IP->>IP: create $PROJECT/.claude/ways/_template.md
    end

    rect rgba(255, 152, 0, 0.15)
        Note over CC,Ctx: After Compaction
        CC->>CM: SessionStart:compact
        CM->>CM: rm /tmp/.claude-way-*
        CM->>CM: rm /tmp/.claude-tasks-active-*
        CC->>SC: SessionStart:compact
        SC->>Ctx: core.md (fresh guidance)
    end
```

## Way Matching Modes

Each way declares how it should be matched in its YAML frontmatter.

```mermaid
flowchart TD
    classDef regex fill:#4CAF50,stroke:#2E7D32,color:#fff
    classDef semantic fill:#2196F3,stroke:#1565C0,color:#fff
    classDef model fill:#9C27B0,stroke:#6A1B9A,color:#fff
    classDef decision fill:#FF9800,stroke:#E65100,color:#fff
    classDef result fill:#26A69A,stroke:#00796B,color:#fff

    W[way.md frontmatter]
    W -->|"match: regex (default)"| R
    W -->|"match: semantic"| S
    W -->|"match: model"| M

    subgraph RX [" "]
        R[Regex Match]:::regex
        R --> RP["pattern: → user prompt"]:::regex
        R --> RC["commands: → bash command"]:::regex
        R --> RF["files: → file path"]:::regex
    end

    subgraph SM [" "]
        S[Semantic Match]:::semantic
        S --> SK["Keyword Count<br/>vocabulary words in prompt ≥ 2"]:::semantic
        S --> SN["Gzip NCD<br/>compress description + prompt<br/>NCD &lt; threshold"]:::semantic
        SK --> OR{Either?}:::decision
        SN --> OR
    end

    subgraph ML [" "]
        M[Model Match]:::model
        M --> MC["Spawn claude -p<br/>'Does this relate to: description?'<br/>~800ms latency"]:::model
    end

    OR -->|yes| FIRE[Fire Way]:::result
    RP -->|match| FIRE
    RC -->|match| FIRE
    RF -->|match| FIRE
    MC -->|"'yes'"| FIRE
```

### Regex

```yaml
pattern: commit|push          # matched against user prompt
commands: git\ commit         # matched against bash commands
files: \.env$|config\.json    # matched against file paths
```

Fast and precise. Most ways use this.

### Semantic

```yaml
match: semantic
description: "API design, REST endpoints, request handling"
vocabulary: api endpoint route handler middleware
threshold: 0.55
```

Two-technique approach:
1. **Keyword counting** - counts vocabulary words in the prompt (match if >= 2)
2. **Gzip NCD** - compresses description + prompt together; similar text compresses better (match if NCD < threshold)

Either technique succeeding triggers the way.

### Model

```yaml
match: model
description: "security-sensitive operations, auth changes, credential handling"
```

Spawns a minimal Claude subprocess to classify yes/no. Most accurate but adds ~800ms latency.

## State Triggers

Evaluated by `check-state.sh` on every UserPromptSubmit. Unlike pattern-based ways, these fire based on session conditions.

### context-threshold

```yaml
trigger: context-threshold
threshold: 75
```

Estimates transcript size since last compaction (~4 chars/token, ~155K token window = ~620K chars). Fires when `transcript_bytes > 620K * threshold%`.

**Special behavior**: Does not use the standard marker system. Repeats on every prompt until a `/tmp/.claude-tasks-active-{session_id}` marker exists (created by `mark-tasks-active.sh` when `TaskCreate` is used).

### file-exists

```yaml
trigger: file-exists
path: .claude/todo-*.md
```

Fires once (standard marker) if the glob pattern matches any file relative to the project directory.

### session-start

```yaml
trigger: session-start
```

Always evaluates true. Uses standard marker, so fires exactly once per session on the first UserPromptSubmit.

## Once-Per-Session Gating

Most ways fire once then go silent for the rest of the session.

```mermaid
stateDiagram-v2
    classDef notShown fill:#E91E63,stroke:#AD1457,color:#fff,font-weight:bold
    classDef shown fill:#4CAF50,stroke:#2E7D32,color:#fff,font-weight:bold

    [*] --> NotShown
    NotShown --> Shown : trigger match → output + create marker
    Shown --> Shown : trigger match → no-op

    state "not_shown (no marker)" as NotShown:::notShown
    state "shown (marker exists)" as Shown:::shown

    note right of NotShown : /tmp/.claude-way-{domain}-{way}-{session}
    note right of Shown : Cleared on SessionStart (startup & compact)
```

**Exception**: context-threshold triggers bypass this system entirely. They repeat until the tasks-active marker exists.

## The Context-Threshold Nag

The `meta/todos` way uses context-threshold to ensure task lists exist before compaction.

```mermaid
sequenceDiagram
    participant U as User
    participant CC as Claude Code
    participant CS as check-state.sh
    participant MT as mark-tasks-active.sh
    participant Ctx as Claude Context

    rect rgba(244, 67, 54, 0.12)
        Note over U,Ctx: Context > 75%, no task list
        U->>CC: (any prompt)
        CC->>CS: UserPromptSubmit
        CS->>CS: transcript_bytes > 465K?
        Note right of CS: YES
        CS->>CS: /tmp/.claude-tasks-active-* exists?
        Note right of CS: NO
        CS->>Ctx: "Context checkpoint. Create tasks now."
    end

    rect rgba(244, 67, 54, 0.12)
        Note over U,Ctx: Still no task list — nags again
        U->>CC: (any prompt)
        CC->>CS: UserPromptSubmit
        CS->>CS: transcript_bytes > 465K?
        Note right of CS: YES
        CS->>CS: /tmp/.claude-tasks-active-* exists?
        Note right of CS: NO
        CS->>Ctx: "Context checkpoint. Create tasks now."
    end

    rect rgba(76, 175, 80, 0.15)
        Note over U,Ctx: Claude creates tasks — nag stops
        CC->>CC: TaskCreate (tool call)
        CC->>MT: PreToolUse:TaskCreate
        MT->>MT: touch /tmp/.claude-tasks-active-{session}
    end

    rect rgba(76, 175, 80, 0.15)
        Note over U,Ctx: Subsequent prompts — silence
        U->>CC: (any prompt)
        CC->>CS: UserPromptSubmit
        CS->>CS: transcript_bytes > 465K?
        Note right of CS: YES
        CS->>CS: /tmp/.claude-tasks-active-* exists?
        Note right of CS: YES — skip
    end
```

## Full Data Flow

```mermaid
sequenceDiagram
    participant U as User
    participant CC as Claude Code
    participant CP as check-prompt.sh
    participant CS as check-state.sh
    participant SW as show-way.sh
    participant CB as check-bash-pre.sh
    participant CF as check-file-pre.sh
    participant MA as mark-tasks-active.sh
    participant CR as check-response.sh
    participant Ctx as Claude Context

    rect rgba(66, 165, 245, 0.12)
        Note over U,Ctx: User sends message
        U->>CC: prompt
        par Prompt Triggers
            CC->>CP: UserPromptSubmit
            CP->>CP: scan ways (regex/semantic/model)
            CP->>SW: matched ways
            SW->>SW: check marker → check domain → run macro
            SW->>Ctx: way content (if not shown)
        and State Triggers
            CC->>CS: UserPromptSubmit
            CS->>CS: evaluate triggers
            CS->>Ctx: context-threshold nag (if applicable)
        end
    end

    rect rgba(156, 39, 176, 0.12)
        Note over U,Ctx: Claude uses tools
        alt Bash command
            CC->>CB: PreToolUse:Bash
            CB->>CB: scan commands: patterns
            CB->>Ctx: matching way content
        else File edit
            CC->>CF: PreToolUse:Edit|Write
            CF->>CF: scan files: patterns
            CF->>Ctx: matching way content
        else Task creation
            CC->>MA: PreToolUse:TaskCreate
            MA->>MA: touch tasks-active marker
        end
    end

    rect rgba(255, 152, 0, 0.12)
        Note over U,Ctx: Claude finishes responding
        CC->>CR: Stop
        CR->>CR: extract keywords from response
        CR->>CR: write /tmp/claude-response-topics-*
        Note right of CR: Topics feed into next check-prompt.sh
    end
```

## Macros

Ways can include a `macro.sh` alongside `way.md`. Frontmatter declares positioning:

```yaml
macro: prepend   # macro output before static content
macro: append    # macro output after static content
```

Macros generate dynamic content. Examples:
- `softwaredev/adr/macro.sh` - Tri-state detection: no tooling, tooling available, tooling installed
- `softwaredev/quality/macro.sh` - Scans for long files in the project, outputs priority list
- `softwaredev/github/macro.sh` - Detects solo vs team project, adjusts PR guidance

**Security**: Project-local macros only run if the project is listed in `~/.claude/trusted-project-macros`.

## Project-Local Ways

Projects can override or add ways at `$PROJECT/.claude/ways/{domain}/{way}/way.md`. Project-local takes precedence over global. Same-path ways share a marker, so only one fires.

```mermaid
flowchart TD
    classDef project fill:#FF9800,stroke:#E65100,color:#fff
    classDef global fill:#2196F3,stroke:#1565C0,color:#fff
    classDef marker fill:#26A69A,stroke:#00796B,color:#fff
    classDef result fill:#4CAF50,stroke:#2E7D32,color:#fff

    T["Trigger fires for softwaredev/github"] --> PL

    PL{"$PROJECT/.claude/ways/<br/>softwaredev/github/way.md<br/>exists?"}
    PL -->|yes| USE_P["Use project-local way"]:::project
    PL -->|no| GL{"~/.claude/hooks/ways/<br/>softwaredev/github/way.md<br/>exists?"}:::global
    GL -->|yes| USE_G["Use global way"]:::global
    GL -->|no| SKIP["No output"]

    USE_P --> MK["Shared marker:<br/>/tmp/.claude-way-softwaredev-github-{session}"]:::marker
    USE_G --> MK
    MK --> OUT["Output way content"]:::result
```

## Domain Enable/Disable

`~/.claude/ways.json` controls which domains are active:

```json
{
  "disabled": ["itops"]
}
```

Checked by `show-way.sh` before outputting any way.
