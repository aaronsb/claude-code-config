#!/bin/bash
# State-based way trigger evaluator
# Scans ways for `trigger:` declarations and evaluates conditions
#
# Supported triggers:
#   trigger: context-threshold
#   threshold: 90                 # percentage (0-100)
#
#   trigger: file-exists
#   path: .claude/todo-*.md       # glob pattern relative to project
#
#   trigger: session-start        # fires once at session begin
#
# Runs every UserPromptSubmit, evaluates conditions, fires matching ways.
# Uses standard marker system for once-per-session gating.

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(echo "$INPUT" | jq -r '.cwd // empty')}"

WAYS_DIR="${HOME}/.claude/hooks/ways"
CONTEXT=""

# Detect execution scope (agent vs teammate)
source "${WAYS_DIR}/detect-scope.sh"
CURRENT_SCOPE=$(detect_scope "$SESSION_ID")

# Get transcript size since last compaction (bytes after last summary line)
# Caches line number to avoid repeated full-file scans
get_transcript_size() {
  [[ ! -f "$TRANSCRIPT" ]] && echo 0 && return

  local cache_file="/tmp/claude-summary-line-${SESSION_ID}"
  local file_size=$(wc -c < "$TRANSCRIPT")
  local cached_pos=0
  local cached_size=0

  # Read cache if exists
  if [[ -f "$cache_file" ]]; then
    read cached_pos cached_size < "$cache_file" 2>/dev/null
  fi

  # If file grew, check only new content for summary markers
  if [[ $file_size -gt $cached_size ]]; then
    # Check last 100KB for new summary markers (compactions are rare)
    local new_summary=$(tail -c 100000 "$TRANSCRIPT" 2>/dev/null | grep -n '"type":"summary"' | tail -1 | cut -d: -f1)
    if [[ -n "$new_summary" ]]; then
      # Found new summary - recalculate from there
      cached_pos=$(tail -c 100000 "$TRANSCRIPT" | head -n $new_summary | wc -c)
      cached_pos=$((file_size - 100000 + cached_pos))
    fi
    echo "$cached_pos $file_size" > "$cache_file"
  fi

  # Return bytes since last summary
  if [[ $cached_pos -gt 0 ]]; then
    echo $((file_size - cached_pos))
  else
    echo $file_size
  fi
}

# Evaluate a trigger condition
# Returns 0 if condition met, 1 otherwise
evaluate_trigger() {
  local trigger="$1"
  local wayfile="$2"

  case "$trigger" in
    context-threshold)
      local threshold=$(awk '/^threshold:/' "$wayfile" | sed 's/^threshold: *//')
      threshold=${threshold:-90}

      # ~4 chars/token, ~155K window = 620K chars
      # threshold% of 620K
      local limit=$((620000 * threshold / 100))
      local size=$(get_transcript_size)

      [[ $size -gt $limit ]]
      return $?
      ;;

    file-exists)
      local pattern=$(awk '/^path:/' "$wayfile" | sed 's/^path: *//')
      [[ -z "$pattern" ]] && return 1

      # Expand glob relative to project dir
      local matches=$(ls "${PROJECT_DIR}"/${pattern} 2>/dev/null | head -1)
      [[ -n "$matches" ]]
      return $?
      ;;

    session-start)
      # Always true on first eval - marker handles once-per-session
      return 0
      ;;

    *)
      # Unknown trigger type
      return 1
      ;;
  esac
}

# Scan ways for state triggers
scan_state_triggers() {
  local dir="$1"
  [[ ! -d "$dir" ]] && return

  while IFS= read -r -d '' wayfile; do
    # Extract way path relative to ways dir
    local waypath="${wayfile#$dir/}"
    waypath="${waypath%/way.md}"

    # Check for trigger: field in frontmatter
    local trigger=$(awk 'NR==1 && /^---$/{p=1; next} p && /^---$/{exit} p && /^trigger:/' "$wayfile" | sed 's/^trigger: *//')

    [[ -z "$trigger" ]] && continue

    # Check scope -- skip if current scope not in way's scope list
    local scope=$(awk 'NR==1 && /^---$/{p=1; next} p && /^---$/{exit} p && /^scope:/' "$wayfile" | sed 's/^scope: *//')
    scope="${scope:-agent}"
    scope_matches "$scope" "$CURRENT_SCOPE" || continue

    # Evaluate the trigger condition
    if evaluate_trigger "$trigger" "$wayfile"; then
      case "$trigger" in
        context-threshold)
          # Repeat on every prompt until tasks-active marker exists
          local tasks_marker="/tmp/.claude-tasks-active-${SESSION_ID}"
          if [[ ! -f "$tasks_marker" ]]; then
            local output=$(awk 'BEGIN{fm=0} /^---$/{fm++; next} fm!=1' "$wayfile")
            if [[ -n "$output" ]]; then
              CONTEXT+="$output"$'\n\n'
              "${WAYS_DIR}/log-event.sh" \
                event=way_fired way="$waypath" domain="${waypath%%/*}" \
                trigger="state" scope="$CURRENT_SCOPE" project="$PROJECT_DIR" session="$SESSION_ID"
            fi
          fi
          ;;
        *)
          # Other triggers use standard once-per-session marker
          local output=$("${WAYS_DIR}/show-way.sh" "$waypath" "$SESSION_ID" "state")
          [[ -n "$output" ]] && CONTEXT+="$output"$'\n\n'
          ;;
      esac
    fi

  done < <(find "$dir" -name "way.md" -print0 2>/dev/null)
}

# Safety net: re-inject core if context was cleared without SessionStart
# (e.g., plan mode "clear context"). Detects the contradiction:
#   core marker exists (we think we injected) + tiny context + old marker
# Fires once — show-core.sh recreates the marker, gating further runs.
CORE_MARKER="/tmp/.claude-core-${SESSION_ID}"
if [[ -n "$SESSION_ID" ]]; then
  if [[ ! -f "$CORE_MARKER" ]]; then
    # No marker at all — session_id changed or first run without SessionStart
    CORE_OUTPUT=$("${WAYS_DIR}/show-core.sh" <<< "{\"session_id\":\"${SESSION_ID}\"}")
    [[ -n "$CORE_OUTPUT" ]] && CONTEXT+="$CORE_OUTPUT"$'\n\n'
  else
    # Marker exists — check for stale injection (context cleared under us)
    ctx_size=$(get_transcript_size)
    marker_ts=$(cat "$CORE_MARKER" 2>/dev/null)
    now_ts=$(date +%s)
    age=$(( now_ts - ${marker_ts:-$now_ts} ))
    if [[ $ctx_size -lt 5000 && $age -gt 30 ]]; then
      # Small context + marker older than 30s = context was cleared
      rm -f "$CORE_MARKER"
      CORE_OUTPUT=$("${WAYS_DIR}/show-core.sh" <<< "{\"session_id\":\"${SESSION_ID}\"}")
      [[ -n "$CORE_OUTPUT" ]] && CONTEXT+="$CORE_OUTPUT"$'\n\n'
    fi
  fi
fi

# Scan project-local first, then global
scan_state_triggers "$PROJECT_DIR/.claude/ways"
scan_state_triggers "${WAYS_DIR}"

# Output accumulated context
if [[ -n "$CONTEXT" ]]; then
  jq -n --arg ctx "${CONTEXT%$'\n\n'}" '{"additionalContext": $ctx}'
fi
