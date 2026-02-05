#!/bin/bash
# Check if claude-code-config is up to date with upstream
# Handles three install scenarios: direct clone, fork, plugin
#
# Detection order:
#   1. Is ~/.claude a git repo? If not, exit.
#   2. Is origin aaronsb/claude-code-config? → direct clone
#   3. Is origin a fork of aaronsb/claude-code-config? → fork
#   4. Is CLAUDE_PLUGIN_ROOT set? → plugin install
#
# Network calls (git fetch, gh api) are rate-limited to once per hour.
# Display fires every session if cached state shows "behind".

CLAUDE_DIR="${HOME}/.claude"
UPSTREAM_REPO="aaronsb/claude-code-config"
UPSTREAM_URL="https://github.com/${UPSTREAM_REPO}"
CACHE_FILE="/tmp/.claude-config-update-state-$(id -u)"
ONE_HOUR=3600
CURRENT_TIME=$(date +%s)

# --- Helpers ---

needs_refresh() {
  [[ ! -f "$CACHE_FILE" ]] && return 0
  local last_fetch
  last_fetch=$(sed -n 's/^fetched=//p' "$CACHE_FILE" 2>/dev/null)
  [[ -z "$last_fetch" ]] && return 0
  (( CURRENT_TIME - last_fetch >= ONE_HOUR ))
}

write_cache() {
  local type="$1" behind="$2" extra="$3"
  cat > "$CACHE_FILE" <<CACHE
fetched=${CURRENT_TIME}
type=${type}
behind=${behind}
${extra}
CACHE
}

read_cache() {
  [[ -f "$CACHE_FILE" ]] || return 1
  CACHED_TYPE=$(sed -n 's/^type=//p' "$CACHE_FILE")
  CACHED_BEHIND=$(sed -n 's/^behind=//p' "$CACHE_FILE")
  CACHED_HAS_UPSTREAM=$(sed -n 's/^has_upstream=//p' "$CACHE_FILE")
  CACHED_FORK_OWNER=$(sed -n 's/^fork_owner=//p' "$CACHE_FILE")
  return 0
}

show_clone_notice() {
  local behind="$1"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Update Available — ${behind} commit(s) behind origin/main"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "  cd ~/.claude && git pull"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

show_fork_notice() {
  local has_upstream="$1"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Update Available — your fork is behind ${UPSTREAM_REPO}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  if [[ "$has_upstream" != "true" ]]; then
    echo "  git -C ~/.claude remote add upstream ${UPSTREAM_URL}"
  fi
  echo "  cd ~/.claude && git fetch upstream && git merge upstream/main"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

show_plugin_notice() {
  local installed="$1" latest="$2"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Plugin Update Available (v${installed} → v${latest})"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "  /plugin update disciplined-methodology"
  echo ""
  echo "  Release notes:"
  echo "  ${UPSTREAM_URL}/releases/tag/v${latest}"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

# Check gh CLI availability and auth status.
# Returns 0 if gh is ready, 1 if not (with reason cached for display).
check_gh() {
  if ! command -v gh &>/dev/null; then
    GH_ISSUE="gh CLI not installed (needed for fork detection)"
    return 1
  fi

  # Check auth status
  local auth_output
  auth_output=$(gh auth status 2>&1)
  local auth_rc=$?

  if [[ $auth_rc -ne 0 ]]; then
    if echo "$auth_output" | grep -qi "not logged in"; then
      GH_ISSUE="gh CLI not logged in — run: gh auth login"
    elif echo "$auth_output" | grep -qi "token.*expired"; then
      GH_ISSUE="gh auth token expired — run: gh auth refresh"
    else
      GH_ISSUE="gh auth failed: $(echo "$auth_output" | head -1)"
    fi
    return 1
  fi

  GH_ISSUE=""
  return 0
}

# Show a non-blocking note when gh isn't available (once per day)
GH_NOTICE_MARKER="/tmp/.claude-gh-notice-$(id -u)"
ONE_DAY=86400

show_gh_notice() {
  if [[ -f "$GH_NOTICE_MARKER" ]]; then
    local last_shown
    last_shown=$(cat "$GH_NOTICE_MARKER" 2>/dev/null)
    if [[ -n "$last_shown" ]] && (( CURRENT_TIME - last_shown < ONE_DAY )); then
      return
    fi
  fi
  echo "$CURRENT_TIME" > "$GH_NOTICE_MARKER"
  echo ""
  echo "  Note: Update check skipped — ${GH_ISSUE}"
  echo "  If you don't use gh as part of your flow, other git platforms have"
  echo "  similar CLI tools. Use Claude Code to adjust this check for your environment."
  echo "  (This script: ~/.claude/hooks/check-config-updates.sh)"
  echo ""
}

# --- Scenario 1 & 2: Git repo (clone or fork) ---

if git -C "$CLAUDE_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  REMOTE_URL=$(git -C "$CLAUDE_DIR" remote get-url origin 2>/dev/null)

  # Extract owner/repo from URL (handles https and ssh formats)
  OWNER_REPO=$(echo "$REMOTE_URL" | sed -E 's#.*github\.com[:/]##; s/\.git$//')

  if [[ "$OWNER_REPO" == "$UPSTREAM_REPO" ]]; then
    # --- Direct clone ---
    if needs_refresh; then
      git -C "$CLAUDE_DIR" fetch origin --quiet 2>/dev/null
      BEHIND=$(git -C "$CLAUDE_DIR" rev-list HEAD..origin/main --count 2>/dev/null || echo 0)
      write_cache "clone" "$BEHIND"
    else
      read_cache
      BEHIND="$CACHED_BEHIND"
    fi

    if [[ "$BEHIND" -gt 0 ]]; then
      show_clone_notice "$BEHIND"
    fi
    exit 0

  else
    # --- Possible fork ---
    # Need gh CLI to detect forks
    if check_gh; then
      if needs_refresh; then
        # Check if this repo is a fork of ours
        GH_OUTPUT=$(gh api "repos/${OWNER_REPO}" 2>&1)
        GH_RC=$?

        if [[ $GH_RC -ne 0 ]]; then
          # API call failed — permission issue, rate limit, or other
          if echo "$GH_OUTPUT" | grep -qi "404\|not found"; then
            write_cache "gh_error" "0" "reason=repo not found on GitHub (${OWNER_REPO})"
          elif echo "$GH_OUTPUT" | grep -qi "403\|rate limit"; then
            write_cache "gh_error" "0" "reason=GitHub API rate limited — try again later"
          else
            write_cache "gh_error" "0" "reason=$(echo "$GH_OUTPUT" | head -1)"
          fi
          read_cache
          exit 0
        fi

        PARENT=$(echo "$GH_OUTPUT" | jq -r '.parent.full_name // empty' 2>/dev/null)

        if [[ "$PARENT" == "$UPSTREAM_REPO" ]]; then
          # It's a fork. Check if upstream remote exists locally.
          HAS_UPSTREAM=false
          if git -C "$CLAUDE_DIR" remote get-url upstream >/dev/null 2>&1; then
            HAS_UPSTREAM=true
          fi

          # Compare local HEAD against upstream's main via ls-remote
          UPSTREAM_HEAD=$(git ls-remote "${UPSTREAM_URL}" refs/heads/main 2>/dev/null | cut -f1)
          LOCAL_HEAD=$(git -C "$CLAUDE_DIR" rev-parse HEAD 2>/dev/null)
          FORK_OWNER=$(echo "$OWNER_REPO" | cut -d/ -f1)

          if [[ -n "$UPSTREAM_HEAD" && "$UPSTREAM_HEAD" != "$LOCAL_HEAD" ]]; then
            write_cache "fork" "1" "has_upstream=${HAS_UPSTREAM}
fork_owner=${FORK_OWNER}"
          else
            write_cache "fork" "0" "has_upstream=${HAS_UPSTREAM}
fork_owner=${FORK_OWNER}"
          fi
        else
          # Not a fork of ours, nothing to do
          write_cache "unrelated" "0"
          exit 0
        fi
      else
        read_cache
      fi

      if [[ "$CACHED_TYPE" == "fork" && "$CACHED_BEHIND" -gt 0 ]]; then
        show_fork_notice "$CACHED_HAS_UPSTREAM"
      fi
      exit 0
    else
      # gh not available — show why (once, via cache)
      if needs_refresh; then
        write_cache "gh_unavailable" "0" "reason=${GH_ISSUE}"
      fi
      show_gh_notice
      exit 0
    fi
  fi
fi

# --- Scenario 3: Plugin install (no git repo, or non-github remote) ---

if [[ -n "$CLAUDE_PLUGIN_ROOT" && -f "$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json" ]]; then
  INSTALLED_VERSION=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' \
    "$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json" | cut -d'"' -f4)

  if check_gh; then
    if needs_refresh; then
      LATEST_VERSION=$(gh api "repos/${UPSTREAM_REPO}/releases/latest" --jq '.tag_name' 2>&1)
      GH_RC=$?
      LATEST_VERSION=$(echo "$LATEST_VERSION" | tr -d 'v')

      if [[ $GH_RC -ne 0 || -z "$LATEST_VERSION" ]]; then
        write_cache "plugin" "0" "reason=failed to fetch latest release"
      elif [[ "$INSTALLED_VERSION" != "$LATEST_VERSION" ]]; then
        write_cache "plugin" "1" "installed=${INSTALLED_VERSION}
latest=${LATEST_VERSION}"
      else
        write_cache "plugin" "0"
      fi
    else
      read_cache
    fi

    if [[ "$CACHED_TYPE" == "plugin" && "$CACHED_BEHIND" -gt 0 ]]; then
      INSTALLED=$(sed -n 's/^installed=//p' "$CACHE_FILE")
      LATEST=$(sed -n 's/^latest=//p' "$CACHE_FILE")
      show_plugin_notice "$INSTALLED" "$LATEST"
    fi
  else
    show_gh_notice
  fi
fi
