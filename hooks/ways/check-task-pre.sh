#!/bin/bash
# PreToolUse:Task — thin dispatcher to ways binary
#
# Phase 1 of two-phase subagent injection:
# 1. This script: ways scan task (matches ways, writes stash)
# 2. SubagentStart: inject-subagent.sh (reads stash, emits content)

INPUT=$(cat)
TASK_PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // empty' | tr '[:upper:]' '[:lower:]')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(echo "$INPUT" | jq -r '.cwd // empty')}"
TEAM_NAME=$(echo "$INPUT" | jq -r '.tool_input.team_name // empty')

[[ -z "$TASK_PROMPT" || -z "$SESSION_ID" ]] && exit 0

ARGS=(--query "$TASK_PROMPT" --session "$SESSION_ID" --project "$PROJECT_DIR")
[[ -n "$TEAM_NAME" ]] && ARGS+=(--team "$TEAM_NAME")

"${HOME}/.claude/bin/ways" scan task "${ARGS[@]}"

# Never block Task creation
exit 0
