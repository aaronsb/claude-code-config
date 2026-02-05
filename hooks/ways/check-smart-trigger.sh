#!/bin/bash
# Smart way triggering with model confirmation
#
# Instead of firing every pattern match, this:
# 1. Collects all candidate ways (pattern matched, not yet fired)
# 2. Asks model which are genuinely relevant
# 3. Fires only confirmed ways
#
# This reduces noise from "trigger happy" patterns while keeping
# the speed benefit of pattern-based pre-filtering.

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' | tr '[:upper:]' '[:lower:]')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(echo "$INPUT" | jq -r '.cwd // empty')}"
WAYS_DIR="${HOME}/.claude/hooks/ways"

# Collect candidates: ways that pattern-match but haven't fired
declare -a CANDIDATES
declare -A CANDIDATE_DESC

collect_candidates() {
  local dir="$1"
  [[ ! -d "$dir" ]] && return

  while IFS= read -r -d '' wayfile; do
    local waypath="${wayfile#$dir/}"
    waypath="${waypath%/way.md}"

    # Skip if already fired this session
    local marker="/tmp/.claude-way-${waypath//\//-}-${SESSION_ID}"
    [[ -f "$marker" ]] && continue

    # Extract frontmatter
    local frontmatter=$(awk 'NR==1 && /^---$/{p=1; next} p && /^---$/{exit} p{print}' "$wayfile")
    get_field() { echo "$frontmatter" | awk "/^$1:/"'{gsub(/^'"$1"': */, ""); print; exit}'; }

    local match_mode=$(get_field "match")
    local pattern=$(get_field "pattern")
    local trigger=$(get_field "trigger")
    local description=$(get_field "description")

    # Skip state-based triggers (handled by check-state.sh)
    [[ -n "$trigger" ]] && continue

    # Skip model-based (would be recursive)
    [[ "$match_mode" == "model" ]] && continue

    # Check if pattern matches
    local matched=false
    if [[ "$match_mode" == "semantic" ]]; then
      local vocabulary=$(get_field "vocabulary")
      local threshold=$(get_field "threshold")
      if "${WAYS_DIR}/semantic-match.sh" "$PROMPT" "$description" "$vocabulary" "$threshold" 2>/dev/null; then
        matched=true
      fi
    elif [[ -n "$pattern" && "$PROMPT" =~ $pattern ]]; then
      matched=true
    fi

    if $matched; then
      CANDIDATES+=("$waypath")
      # Get description from first heading or frontmatter
      if [[ -n "$description" ]]; then
        CANDIDATE_DESC["$waypath"]="$description"
      else
        # Extract first markdown heading as description
        local heading=$(awk '/^#+ /{gsub(/^#+ */, ""); print; exit}' "$wayfile")
        CANDIDATE_DESC["$waypath"]="${heading:-$waypath}"
      fi
    fi
  done < <(find "$dir" -name "way.md" -print0 2>/dev/null)
}

# Collect from project-local and global
collect_candidates "$PROJECT_DIR/.claude/ways"
collect_candidates "${WAYS_DIR}"

# No candidates? Exit silently
[[ ${#CANDIDATES[@]} -eq 0 ]] && exit 0

# Single candidate? Fire directly (no need for model call)
if [[ ${#CANDIDATES[@]} -eq 1 ]]; then
  CONTEXT=$("${WAYS_DIR}/show-way.sh" "${CANDIDATES[0]}" "$SESSION_ID" "smart")
  if [[ -n "$CONTEXT" ]]; then
    jq -n --arg ctx "$CONTEXT" '{"additionalContext": $ctx}'
  fi
  exit 0
fi

# Multiple candidates - ask model which are relevant
CANDIDATE_LIST=""
for i in "${!CANDIDATES[@]}"; do
  num=$((i + 1))
  way="${CANDIDATES[$i]}"
  desc="${CANDIDATE_DESC[$way]}"
  CANDIDATE_LIST+="${num}. ${way}: ${desc}"$'\n'
done

# Model confirmation call
CLASSIFICATION_PROMPT="User message: \"${PROMPT}\"

These contextual guides matched but need confirmation. Which are genuinely relevant to the user's current intent?

${CANDIDATE_LIST}
Return only the numbers of relevant items (e.g., \"1,3\") or \"none\" if none are relevant.
Be selective - only confirm ways that directly help with what the user is doing."

RESULT=$(timeout 15 claude -p --max-turns 1 --tools "" --no-session-persistence \
  "$CLASSIFICATION_PROMPT" 2>/dev/null)

# Parse result and fire confirmed ways
CONTEXT=""
if [[ "$RESULT" != *"none"* ]]; then
  for i in "${!CANDIDATES[@]}"; do
    num=$((i + 1))
    if echo "$RESULT" | grep -q "$num"; then
      way="${CANDIDATES[$i]}"
      output=$("${WAYS_DIR}/show-way.sh" "$way" "$SESSION_ID" "smart")
      [[ -n "$output" ]] && CONTEXT+="$output"$'\n\n'
    fi
  done
fi

# Output accumulated context
if [[ -n "$CONTEXT" ]]; then
  jq -n --arg ctx "${CONTEXT%$'\n\n'}" '{"additionalContext": $ctx}'
fi
