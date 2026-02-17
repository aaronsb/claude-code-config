#!/bin/bash
# Show a "way" once per session (strips frontmatter, runs macro if configured)
# Usage: show-way.sh <way-path> <session-id>
#
# Way paths can be nested: "softwaredev/delivery/github", "awsops/iam", etc.
# Looks for: {way-path}/way.md and optionally {way-path}/macro.sh
#
# STATE MACHINE:
# ┌─────────────────┬────────────────────────────────────┐
# │ Marker State    │ Action                             │
# ├─────────────────┼────────────────────────────────────┤
# │ not exists      │ output way, create marker          │
# │ exists          │ no-op (idempotent)                 │
# └─────────────────┴────────────────────────────────────┘
#
# MACRO SUPPORT:
# If frontmatter contains `macro: prepend` or `macro: append`,
# runs {way-path}/macro.sh and combines output with static content.
#
# Marker: /tmp/.claude-way-{wayname-sanitized}-{session_id}

WAY="$1"
SESSION_ID="$2"
TRIGGER="${3:-unknown}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

# Detect execution scope and team
source "${HOME}/.claude/hooks/ways/detect-scope.sh"
SCOPE=$(detect_scope "$SESSION_ID")
TEAM=$(detect_team "$SESSION_ID")

[[ -z "$WAY" ]] && exit 1

# Check if domain is disabled via ~/.claude/ways.json
# Example: { "disabled": ["itops", "softwaredev"] }
WAYS_CONFIG="${HOME}/.claude/ways.json"
DOMAIN="${WAY%%/*}"  # First path component (e.g., "softwaredev" from "softwaredev/delivery/github")
if [[ -f "$WAYS_CONFIG" ]]; then
  if jq -e --arg d "$DOMAIN" '.disabled | index($d) != null' "$WAYS_CONFIG" >/dev/null 2>&1; then
    exit 0
  fi
fi

# Sanitize way path for marker filename (replace / with -)
WAY_MARKER_NAME=$(echo "$WAY" | tr '/' '-')

# Project-local takes precedence over global
# SECURITY: Project-local macros only run if project is in trusted list
WAY_DIR=""
IS_PROJECT_LOCAL=false
if [[ -f "$PROJECT_DIR/.claude/ways/${WAY}/way.md" ]]; then
  WAY_FILE="$PROJECT_DIR/.claude/ways/${WAY}/way.md"
  WAY_DIR="$PROJECT_DIR/.claude/ways/${WAY}"
  IS_PROJECT_LOCAL=true
elif [[ -f "${HOME}/.claude/hooks/ways/${WAY}/way.md" ]]; then
  WAY_FILE="${HOME}/.claude/hooks/ways/${WAY}/way.md"
  WAY_DIR="${HOME}/.claude/hooks/ways/${WAY}"
else
  exit 0
fi

# Check if project is trusted for macro execution
# Add trusted project paths (one per line) to ~/.claude/trusted-project-macros
is_project_trusted() {
  local trust_file="${HOME}/.claude/trusted-project-macros"
  [[ -f "$trust_file" ]] && grep -qxF "$PROJECT_DIR" "$trust_file"
}

# Marker: scoped to session_id
MARKER="/tmp/.claude-way-${WAY_MARKER_NAME}-${SESSION_ID:-$(date +%Y%m%d)}"

if [[ ! -f "$MARKER" ]]; then
  # Extract macro field from frontmatter (prepend or append)
  MACRO_POS=$(awk '/^---$/{p=!p; next} p && /^macro:/{gsub(/^macro: */, ""); print; exit}' "$WAY_FILE")

  # Check for macro script (same directory as way file)
  MACRO_FILE="${WAY_DIR}/macro.sh"
  MACRO_OUT=""

  if [[ -n "$MACRO_POS" && -x "$MACRO_FILE" ]]; then
    # SECURITY: Skip project-local macros unless project is explicitly trusted
    if $IS_PROJECT_LOCAL && ! is_project_trusted; then
      echo "**Note**: Project-local macro skipped (add $PROJECT_DIR to ~/.claude/trusted-project-macros to enable)"
    else
      # Run macro, capture output
      MACRO_OUT=$("$MACRO_FILE" 2>/dev/null)
    fi
  fi

  # Output based on macro position
  if [[ "$MACRO_POS" == "prepend" && -n "$MACRO_OUT" ]]; then
    echo "$MACRO_OUT"
    echo ""
  fi

  # Output static content, stripping YAML frontmatter
  awk 'BEGIN{fm=0} /^---$/{fm++; next} fm!=1' "$WAY_FILE"

  if [[ "$MACRO_POS" == "append" && -n "$MACRO_OUT" ]]; then
    echo ""
    echo "$MACRO_OUT"
  fi

  touch "$MARKER"

  # Log event
  LOG_ARGS=(event=way_fired way="$WAY" domain="$DOMAIN"
    trigger="$TRIGGER" scope="$SCOPE" project="$PROJECT_DIR" session="$SESSION_ID")
  [[ -n "$TEAM" ]] && LOG_ARGS+=(team="$TEAM")
  "${HOME}/.claude/hooks/ways/log-event.sh" "${LOG_ARGS[@]}"
fi
