# Ways System Architecture

Visual documentation of the ways trigger system.

## Hook Flow

How ways get triggered during a Claude Code session:

```mermaid
flowchart TB
    subgraph Session["Claude Code Session"]
        SS[SessionStart] --> Core["show-core.sh<br/>Dynamic table + core.md"]

        UP[UserPromptSubmit] --> CP["check-prompt.sh<br/>Regex OR semantic"]

        subgraph PreTool["PreToolUse"]
            Bash[Bash tool] --> CB["check-bash-pre.sh<br/>Scan commands"]
            Edit[Edit/Write tool] --> CF["check-file-pre.sh<br/>Scan file paths"]
        end
    end

    CP -->|match: semantic| SM["semantic-match.sh<br/>gzip NCD + keywords"]
    CP -->|regex| SW["show-way.sh"]
    SM --> SW
    CB --> SW
    CF --> SW

    SW --> Check{Marker exists?}
    Check -->|No| Output["Output way content<br/>Create marker"]
    Check -->|Yes| Silent["No-op (silent)"]
```

## Way State Machine

Each (way, session) pair has exactly two states:

```mermaid
stateDiagram-v2
    [*] --> NotShown: Session starts

    NotShown: not_shown
    NotShown: No marker file exists

    Shown: shown
    Shown: Marker file exists

    NotShown --> Shown: Keyword/command/file match<br/>→ Output + create marker
    Shown --> Shown: Any subsequent match<br/>→ No-op (idempotent)

    Shown --> [*]: Session ends<br/>(markers in /tmp auto-cleanup)
```

## Trigger Matching

How prompts and tool use get matched to ways:

```mermaid
flowchart LR
    subgraph Input
        Prompt["User prompt<br/>(lowercased)"]
        Cmd["Bash command"]
        File["File path"]
    end

    subgraph Scan["Recursive Scan"]
        Find["find */way.md"]
        Extract["Extract frontmatter:<br/>pattern, commands, files"]
    end

    subgraph Match["Regex Match"]
        KW["pattern: regex"]
        CM["commands: pattern"]
        FL["files: pattern"]
    end

    Prompt --> Find
    Cmd --> Find
    File --> Find

    Find --> Extract
    Extract --> KW
    Extract --> CM
    Extract --> FL

    KW -->|match| SW["show-way.sh waypath session_id"]
    CM -->|match| SW
    FL -->|match| SW
```

## Semantic Matching

For ways with `match: semantic`, regex is replaced with gzip NCD + keyword counting:

```mermaid
flowchart TB
    subgraph Input
        Prompt["User prompt"]
        Desc["Way description"]
        Keywords["Domain vocabulary"]
    end

    subgraph Tech1["Technique 1: Keyword Counting"]
        Split["Split prompt into words"]
        Filter["Remove stopwords"]
        Count["Count matches in vocabulary"]
        KWResult["kw_count >= 2?"]
    end

    subgraph Tech2["Technique 2: Gzip NCD"]
        Compress["Compress separately:<br/>C(desc), C(prompt)"]
        Combined["Compress together:<br/>C(desc+prompt)"]
        Formula["NCD = (C(ab) - min) / max"]
        NCDResult["ncd < 0.58?"]
    end

    Prompt --> Split
    Keywords --> Count
    Split --> Filter --> Count --> KWResult

    Desc --> Compress
    Prompt --> Compress
    Compress --> Combined --> Formula --> NCDResult

    KWResult -->|Yes| Match["✓ MATCH"]
    NCDResult -->|Yes| Match
    KWResult -->|No| NCDResult
    NCDResult -->|No| NoMatch["✗ No match"]
```

**Why gzip NCD works**: Similar texts share patterns that compress well together.

```
NCD("software design", "design the database schema") = 0.52 (similar)
NCD("software design", "button design looks off")    = 0.63 (different)
```

## Macro Injection

Ways with `macro: prepend|append` run dynamic scripts:

```mermaid
sequenceDiagram
    participant Hook as check-*.sh
    participant Show as show-way.sh
    participant Macro as macro.sh
    participant Way as way.md
    participant Out as Output

    Hook->>Show: waypath, session_id
    Show->>Show: Check marker

    alt Marker exists
        Show-->>Hook: (silent return)
    else No marker
        Show->>Way: Read frontmatter

        alt macro: prepend
            Show->>Macro: Execute
            Macro-->>Out: Dynamic context
            Show->>Way: Strip frontmatter
            Way-->>Out: Static guidance
        else macro: append
            Show->>Way: Strip frontmatter
            Way-->>Out: Static guidance
            Show->>Macro: Execute
            Macro-->>Out: Dynamic context
        else no macro
            Show->>Way: Strip frontmatter
            Way-->>Out: Static guidance
        end

        Show->>Show: Create marker
    end
```

## Directory Structure

```mermaid
flowchart TB
    subgraph Global["~/.claude/hooks/ways/"]
        Core[core.md]
        Macro[macro.sh]
        ShowCore[show-core.sh]
        CheckP[check-prompt.sh]
        CheckB[check-bash-post.sh]
        CheckF[check-file-post.sh]
        ShowW[show-way.sh]
        Semantic[semantic-match.sh]

        subgraph Domain["softwaredev/"]
            subgraph WayDir["github/"]
                WayMD[way.md]
                WayMacro[macro.sh]
            end
            subgraph DesignDir["design/"]
                DesignMD["way.md<br/>(match: semantic)"]
            end
            Other["adr/, commits/, ..."]
        end
    end

    subgraph Project["$PROJECT/.claude/ways/"]
        ProjDomain["{domain}/"]
        ProjWay["{wayname}/way.md"]
    end

    CheckP -->|semantic way| Semantic
    ProjWay -.->|overrides| WayMD
```

## Multi-Trigger Semantics

What happens when multiple triggers fire:

```mermaid
flowchart TB
    Prompt["'Let's review the PR and fix the bug'"]

    Prompt --> KW1["pattern: github|pr"]
    Prompt --> KW2["pattern: debug|bug"]
    Prompt --> KW3["pattern: review"]

    KW1 -->|match| GH["github way"]
    KW2 -->|match| DB["debugging way"]
    KW3 -->|match| QA["quality way"]

    GH --> M1{Marker?}
    DB --> M2{Marker?}
    QA --> M3{Marker?}

    M1 -->|No| O1["✓ Output github"]
    M2 -->|No| O2["✓ Output debugging"]
    M3 -->|No| O3["✓ Output quality"]

    M1 -->|Yes| S1["✗ Silent"]
    M2 -->|Yes| S2["✗ Silent"]
    M3 -->|Yes| S3["✗ Silent"]
```

Each way has its own marker - multiple ways can fire from one prompt, but each only fires once per session.

## Project-Local Override

```mermaid
flowchart TB
    subgraph Scan["Way Lookup Order"]
        P["1. Project: $PROJECT/.claude/ways/"]
        G["2. Global: ~/.claude/hooks/ways/"]
    end

    P -->|found| Use["Use project way"]
    P -->|not found| G
    G -->|found| UseG["Use global way"]
    G -->|not found| Skip["No match"]

    Use --> Mark["Single marker<br/>(by waypath)"]
    UseG --> Mark
```

Project ways take precedence. Only one marker per waypath regardless of source.
