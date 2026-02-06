#!/usr/bin/env bash
# Inject context budget facts into introspection way

SCRIPT="${HOME}/.claude/scripts/context-usage.sh"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

if [[ -x "$SCRIPT" ]]; then
  JSON=$("$SCRIPT" --json "$PROJECT_DIR" 2>/dev/null)
  if [[ -n "$JSON" ]]; then
    REMAINING=$(echo "$JSON" | jq -r '.tokens_remaining')
    PCT=$(echo "$JSON" | jq -r '.pct_remaining')
    USED=$(echo "$JSON" | jq -r '.tokens_used')

    echo "**Context budget: ~${USED} tokens used, ~${REMAINING} remaining (${PCT}% of window).**"
    if [[ $PCT -le 25 ]]; then
      echo "After compaction, this conversation's history is summarized and details are lost. Any corrections or guidance the human gave this session that aren't captured as ways will not survive. This is the window to act on that."
    elif [[ $PCT -le 50 ]]; then
      echo "There is room to work, but this is a good time to capture session learnings. Doing it now means the introspection gets full context rather than a post-compaction summary."
    fi
    echo ""
  fi
fi
