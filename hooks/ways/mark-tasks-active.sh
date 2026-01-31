#!/bin/bash
# PreToolUse hook for TaskCreate
# Sets marker so context-threshold nag stops repeating
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[[ -n "$SESSION_ID" ]] && touch "/tmp/.claude-tasks-active-${SESSION_ID}"
