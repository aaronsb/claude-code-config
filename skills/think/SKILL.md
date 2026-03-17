---
name: think
description: Manage cognitive scaffolding strategies. List, activate, cancel, or check status of think strategies. Use when the user explicitly asks to use a thinking strategy or wants to manage an active one.
allowed-tools: Bash, Read
---

# Think Strategies

Cognitive scaffolding that activates automatically when the problem shape matches. This skill is for **manual override only** — strategies normally activate and advance via hooks without user intervention.

## Usage

```
/think                    # Show status of active strategy (if any)
/think list               # List available strategies
/think <strategy>         # Manually activate a strategy
/think cancel             # Cancel the active strategy
```

## Available Strategies

| Strategy | When It Activates | Stages |
|----------|-------------------|--------|
| **tree-of-thoughts** | Multiple viable approaches, "explore options" | 7 |
| **trilemma** | Three competing objectives, "balance/trade-off" | 6 |
| **self-consistency** | High-stakes decisions, "are we sure" | 5 |
| **step-back** | Stuck, need first principles, "step back" | 5 |
| **react** | Investigation, systematic debugging, "figure out why" | 7 (cyclic) |

## How It Works

1. `UserPromptSubmit` hook (`think-check.sh`) detects problem shape via BM25 scoring against strategy signatures
2. Creates state file at `/tmp/.claude-think-{session_id}.json`
3. Each turn: injects current stage guidance as `additionalContext`
4. `Stop` hook (`think-advance.sh`) advances stage after each response
5. On final stage: state file removed, done marker prevents re-activation

## Manual Activation

To manually activate, write the state file:

```bash
# Read strategy to get stage count
strategy_file=~/.claude/hooks/ways/meta/think/strategies/<name>.md
total=$(grep -c '^### [0-9]\+\.' "$strategy_file")
stages=$(grep '^### [0-9]\+\.' "$strategy_file" | sed 's/^### [0-9]\+\. //' | jq -R . | jq -s .)

# Create state file
session_id="<from CLAUDE_SESSION_ID or /tmp markers>"
jq -n --arg s "<name>" --argjson t "$total" --argjson stages "$stages" \
  '{strategy: $s, stage: 1, total_stages: $t, stages: $stages, started_at: (now | todate)}' \
  > "/tmp/.claude-think-${session_id}.json"
```

## Status Check

```bash
# Check for active strategy
ls /tmp/.claude-think-*.json 2>/dev/null
cat /tmp/.claude-think-*.json 2>/dev/null | jq .
```

## Cancellation

The user can say "skip that", "we don't need that", or "cancel strategy" and the hook will detect the cancellation signal and remove the state file.
