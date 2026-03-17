#!/bin/bash
# Think strategy stage advancement
# Runs in Stop hook pipeline (after Claude responds)
#
# Reads response topics from the response hook, checks if current stage
# was addressed, and advances the stage counter if so.
#
# On final stage completion: removes state file, creates done marker

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

[[ -z "$SESSION_ID" ]] && exit 0

STATE_FILE="/tmp/.claude-think-${SESSION_ID}.json"
[[ ! -f "$STATE_FILE" ]] && exit 0

STRATEGIES_DIR="${HOME}/.claude/hooks/ways/meta/think/strategies"

strategy=$(jq -r '.strategy' "$STATE_FILE" 2>/dev/null)
stage=$(jq -r '.stage' "$STATE_FILE" 2>/dev/null)
total=$(jq -r '.total_stages' "$STATE_FILE" 2>/dev/null)

[[ -z "$strategy" || -z "$stage" || -z "$total" ]] && exit 0

# Advance stage
next_stage=$((stage + 1))

if [[ "$next_stage" -gt "$total" ]]; then
  # Strategy complete — clean up
  rm -f "$STATE_FILE"
  # Create done marker to prevent re-activation this session
  touch "/tmp/.claude-think-done-${SESSION_ID}"

  strategy_file="${STRATEGIES_DIR}/${strategy}.md"
  strategy_name=$(head -1 "$strategy_file" | sed 's/^# //')
  echo "{\"hookSpecificOutput\":{\"additionalContext\":\"**${strategy_name}** complete. All ${total} stages addressed.\"}}"
else
  # Advance to next stage
  jq --argjson next "$next_stage" '.stage = $next' "$STATE_FILE" > "${STATE_FILE}.tmp" \
    && mv "${STATE_FILE}.tmp" "$STATE_FILE"
fi
