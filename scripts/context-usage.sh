#!/bin/bash
# Reports context window usage for the current session.
# Reads actual token counts from the transcript's API usage data.
#
# Usage: context-usage.sh [project-dir]
#   project-dir: defaults to $CLAUDE_PROJECT_DIR or $PWD
#
# Output: human-readable summary + JSON

# Parse flags
JSON_ONLY=false
for arg in "$@"; do
  case "$arg" in
    --json) JSON_ONLY=true ;;
    *) PROJECT_DIR="$arg" ;;
  esac
done
PROJECT_DIR="${PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$PWD}}"

# Derive project slug (Claude Code convention: / and . replaced by -)
PROJECT_SLUG=$(echo "$PROJECT_DIR" | sed 's|[/.]|-|g')
CONV_DIR="${HOME}/.claude/projects/${PROJECT_SLUG}"

# Find most recently modified transcript
TRANSCRIPT=$(find "$CONV_DIR" -maxdepth 1 -name "*.jsonl" ! -name "*.tmp" -printf '%T@ %p\n' 2>/dev/null \
  | sort -rn | head -1 | cut -d' ' -f2-)

if [[ -z "$TRANSCRIPT" || ! -f "$TRANSCRIPT" ]]; then
  echo "No active transcript found for project: $PROJECT_DIR"
  exit 1
fi

# Context window size (Claude's actual limit)
WINDOW_TOKENS=200000

# Get the most recent real token count from API usage data.
# cache_read_input_tokens reflects the actual context size sent to the API.
# We look for the largest recent value (most complete turn).
TOKENS_USED=$(jq -r '
  select(.type=="assistant" and .message.usage.cache_read_input_tokens > 0)
  | .message.usage
  | (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.input_tokens // 0)
' "$TRANSCRIPT" 2>/dev/null | sort -rn | head -1)

# Fallback: if no usage data found, estimate from transcript bytes
if [[ -z "$TOKENS_USED" || "$TOKENS_USED" == "0" ]]; then
  TOTAL_BYTES=$(wc -c < "$TRANSCRIPT")
  LAST_SUMMARY_POS=$(grep -bao '"type":"summary"' "$TRANSCRIPT" 2>/dev/null | tail -1 | cut -d: -f1)
  if [[ -n "$LAST_SUMMARY_POS" ]]; then
    ACTIVE_BYTES=$((TOTAL_BYTES - LAST_SUMMARY_POS))
  else
    ACTIVE_BYTES=$TOTAL_BYTES
  fi
  # Conservative estimate: transcript JSON is ~6.3 bytes per token
  TOKENS_USED=$((ACTIVE_BYTES * 10 / 63))
  ESTIMATE_METHOD="bytes"
else
  ESTIMATE_METHOD="api"
fi

TOKENS_REMAINING=$((WINDOW_TOKENS - TOKENS_USED))
PCT_USED=$((TOKENS_USED * 100 / WINDOW_TOKENS))
PCT_REMAINING=$((100 - PCT_USED))

# Clamp
[[ $TOKENS_REMAINING -lt 0 ]] && TOKENS_REMAINING=0
[[ $PCT_REMAINING -lt 0 ]] && PCT_REMAINING=0

# Format token counts with k suffix for readability
fmt_k() {
  if [[ $1 -ge 1000 ]]; then
    echo "$((($1 + 500) / 1000))k"
  else
    echo "$1"
  fi
}

if $JSON_ONLY; then
  # Compact single-line JSON for programmatic use
  jq -cn \
    --argjson used "$TOKENS_USED" \
    --argjson remaining "$TOKENS_REMAINING" \
    --argjson total "$WINDOW_TOKENS" \
    --argjson pct_used "$PCT_USED" \
    --argjson pct_remaining "$PCT_REMAINING" \
    --arg method "$ESTIMATE_METHOD" \
    --arg session "$(basename "$TRANSCRIPT" .jsonl)" \
    '{tokens_used:$used,tokens_remaining:$remaining,tokens_total:$total,pct_used:$pct_used,pct_remaining:$pct_remaining,method:$method,session:$session}'
else
  # Human-readable output
  echo "Context window: ~$(fmt_k $TOKENS_USED) / $(fmt_k $WINDOW_TOKENS) tokens used (${PCT_USED}%)"
  echo "Remaining:      ~$(fmt_k $TOKENS_REMAINING) tokens (${PCT_REMAINING}%)"
  if [[ "$ESTIMATE_METHOD" == "bytes" ]]; then
    echo "Note: estimated from transcript size (no API usage data found)"
  fi

  # JSON for programmatic use
  jq -n \
    --argjson used "$TOKENS_USED" \
    --argjson remaining "$TOKENS_REMAINING" \
    --argjson total "$WINDOW_TOKENS" \
    --argjson pct_used "$PCT_USED" \
    --argjson pct_remaining "$PCT_REMAINING" \
    --arg method "$ESTIMATE_METHOD" \
    --arg session "$(basename "$TRANSCRIPT" .jsonl)" \
    '{
      tokens_used: $used,
      tokens_remaining: $remaining,
      tokens_total: $total,
      pct_used: $pct_used,
      pct_remaining: $pct_remaining,
      method: $method,
      session: $session
    }'
fi
