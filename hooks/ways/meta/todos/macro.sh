#!/usr/bin/env bash
# Inject context budget into the task list checkpoint

SCRIPT="${HOME}/.claude/scripts/context-usage.sh"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

if [[ -x "$SCRIPT" ]]; then
  JSON=$("$SCRIPT" --json "$PROJECT_DIR" 2>/dev/null)
  if [[ -n "$JSON" ]]; then
    REMAINING=$(echo "$JSON" | jq -r '.tokens_remaining')
    PCT=$(echo "$JSON" | jq -r '.pct_remaining')
    echo "**Context budget: ~${REMAINING} tokens remaining (${PCT}% of window).**"
    echo ""
  fi
fi
