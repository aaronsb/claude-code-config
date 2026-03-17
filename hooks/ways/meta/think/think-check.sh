#!/bin/bash
# Think strategy detection and stage injection
# Runs in UserPromptSubmit hook pipeline
#
# If no active strategy: match prompt against strategy signatures, activate if match
# If active strategy: inject current stage guidance
# If cancellation signal: deactivate strategy
#
# State file: /tmp/.claude-think-{session_id}.json

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' | tr '[:upper:]' '[:lower:]')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

[[ -z "$SESSION_ID" ]] && exit 0

STATE_FILE="/tmp/.claude-think-${SESSION_ID}.json"
STRATEGIES_DIR="${HOME}/.claude/hooks/ways/meta/think/strategies"
WAY_MATCH="${HOME}/.claude/bin/way-match"

# --- Cancellation detection ---
CANCEL_PATTERNS="skip that|we don't need that|just do it|stop thinking|cancel strategy|no strategy|drop the strategy"
if [[ -f "$STATE_FILE" ]] && echo "$PROMPT" | grep -qiE "$CANCEL_PATTERNS"; then
  rm -f "$STATE_FILE"
  echo '{"hookSpecificOutput":{"additionalContext":"Think strategy cancelled."}}'
  exit 0
fi

# --- Active strategy: inject current stage ---
if [[ -f "$STATE_FILE" ]]; then
  strategy=$(jq -r '.strategy' "$STATE_FILE" 2>/dev/null)
  stage=$(jq -r '.stage' "$STATE_FILE" 2>/dev/null)
  total=$(jq -r '.total_stages' "$STATE_FILE" 2>/dev/null)
  strategy_file="${STRATEGIES_DIR}/${strategy}.md"

  # Defensive cleanup: if stage exceeds total, the advance hook missed completion
  if [[ "$stage" -gt "$total" ]] || [[ -z "$stage" ]] || [[ -z "$total" ]]; then
    rm -f "$STATE_FILE"
    touch "/tmp/.claude-think-done-${SESSION_ID}"
    exit 0
  fi

  if [[ -f "$strategy_file" ]] && [[ "$stage" -le "$total" ]]; then
    # Extract the current stage's content (### N. heading through next ### or EOF)
    stage_content=$(awk -v n="$stage" '
      /^### [0-9]+\. / {
        match($0, /^### ([0-9]+)\./, arr)
        if (arr[1] == n) { found=1; print; next }
        if (found) exit
      }
      found { print }
    ' "$strategy_file")

    # Build context message
    strategy_name=$(head -1 "$strategy_file" | sed 's/^# //')
    context="**${strategy_name}** — Stage ${stage}/${total}\n\n${stage_content}"

    # JSON-escape the context
    escaped=$(printf '%s' "$context" | jq -Rs .)

    echo "{\"hookSpecificOutput\":{\"additionalContext\":${escaped}}}"
  fi
  exit 0
fi

# --- No active strategy: try to detect one ---
# Check for session marker (each strategy fires at most once per session)
MARKER="/tmp/.claude-think-done-${SESSION_ID}"
[[ -f "$MARKER" ]] && exit 0

# Only try detection if way-match binary exists
[[ ! -x "$WAY_MATCH" ]] && exit 0

# Score prompt against each strategy's keywords
best_score=0
best_strategy=""
best_file=""

for strategy_file in "${STRATEGIES_DIR}"/*.md; do
  [[ ! -f "$strategy_file" ]] && continue

  # Extract keywords and threshold from ## Signature section
  keywords=$(awk '/^## Signature/{found=1; next} found && /^keywords:/{gsub(/^keywords: */, ""); print; exit}' "$strategy_file")
  [[ -z "$keywords" ]] && continue
  strategy_threshold=$(awk '/^## Signature/{found=1; next} found && /^threshold:/{gsub(/^threshold: */, ""); print; exit}' "$strategy_file")
  strategy_threshold="${strategy_threshold:-6.0}"

  # Use way-match to score — same BM25 engine as ways
  score=$("$WAY_MATCH" pair \
    --description "$keywords" \
    --vocabulary "$keywords" \
    --query "$PROMPT" \
    --threshold 0.0 2>&1 | grep -oP 'score=\K[0-9.]+' || echo "0")

  # Use per-strategy threshold (author-tunable, same as way thresholds)
  if (( $(echo "$score > $strategy_threshold && $score > $best_score" | bc -l 2>/dev/null || echo 0) )); then
    best_score="$score"
    best_strategy=$(basename "$strategy_file" .md)
    best_file="$strategy_file"
  fi
done

# If no strategy matched, done
[[ -z "$best_strategy" ]] && exit 0

# Count stages in the matched strategy
total_stages=$(grep -c '^### [0-9]\+\.' "$best_file")
[[ "$total_stages" -eq 0 ]] && exit 0

# Extract stage names
stages=$(grep '^### [0-9]\+\.' "$best_file" | sed 's/^### [0-9]\+\. //')
stages_json=$(echo "$stages" | jq -R . | jq -s .)

# Create state file
jq -n \
  --arg strategy "$best_strategy" \
  --argjson stage 1 \
  --argjson total "$total_stages" \
  --argjson stages "$stages_json" \
  --arg started "$(date -Iseconds)" \
  '{strategy: $strategy, stage: $stage, total_stages: $total, stages: $stages, started_at: $started}' \
  > "$STATE_FILE"

# Extract stage 1 content
stage1_content=$(awk '
  /^### 1\. / { found=1; print; next }
  found && /^### [0-9]+\. / { exit }
  found { print }
' "$best_file")

strategy_name=$(head -1 "$best_file" | sed 's/^# //')
context="**${strategy_name}** activated — Stage 1/${total_stages}\n\n${stage1_content}"
escaped=$(printf '%s' "$context" | jq -Rs .)

echo "{\"hookSpecificOutput\":{\"additionalContext\":${escaped}}}"
