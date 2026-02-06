#!/bin/bash
# Dynamic context for GitHub way
# Two concerns:
#   1. Project scope (solo vs team) and workflow recommendations
#   2. Repository health — how well-configured is this repo?

# Early exit if not a GitHub repo
gh repo view &>/dev/null || {
  echo "**Note**: Not a GitHub repository - GitHub commands won't work"
  exit 0
}

# --- Parallel API calls ---
# We need: repo details, community profile, labels, branch protection
# Fire them all at once and collect results

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

# Repo details (description, topics, permissions, default branch)
timeout 3 gh api repos/:owner/:repo \
  --jq '{
    description: .description,
    topics: .topics,
    default_branch: .default_branch,
    permissions: .permissions,
    has_issues: .has_issues,
    has_discussions: .has_discussions
  }' >"$WORK_DIR/repo.json" 2>/dev/null &

# Community profile (README, license, CoC, contributing, templates, security)
timeout 3 gh api repos/:owner/:repo/community/profile \
  >"$WORK_DIR/community.json" 2>/dev/null &

# Contributors (save full response for reuse in team path)
timeout 3 gh api repos/:owner/:repo/contributors \
  >"$WORK_DIR/contributors.json" 2>/dev/null &

# Labels — paginate returns per-page jq results, so pipe aggregate through jq
timeout 3 gh api repos/:owner/:repo/labels --paginate \
  >"$WORK_DIR/labels.json" 2>/dev/null &

# Security policy (not in community profile, check both common locations)
(timeout 3 gh api repos/:owner/:repo/contents/SECURITY.md --jq '.name' >"$WORK_DIR/security.txt" 2>/dev/null ||
 timeout 3 gh api repos/:owner/:repo/contents/.github/SECURITY.md --jq '.name' >"$WORK_DIR/security.txt" 2>/dev/null) &

# Current user
timeout 3 gh api user --jq '.login' >"$WORK_DIR/user.txt" 2>/dev/null &

wait

# --- Parse results ---

CONTRIBUTORS=$(jq -r 'length' "$WORK_DIR/contributors.json" 2>/dev/null)
CURRENT_USER=$(cat "$WORK_DIR/user.txt" 2>/dev/null)

# Repo details
DESCRIPTION=$(jq -r '.description // empty' "$WORK_DIR/repo.json" 2>/dev/null)
TOPICS=$(jq -r '.topics | length' "$WORK_DIR/repo.json" 2>/dev/null)
DEFAULT_BRANCH=$(jq -r '.default_branch // "main"' "$WORK_DIR/repo.json" 2>/dev/null)
CAN_PUSH=$(jq -r '.permissions.push // false' "$WORK_DIR/repo.json" 2>/dev/null)
CAN_ADMIN=$(jq -r '.permissions.admin // false' "$WORK_DIR/repo.json" 2>/dev/null)

# Community profile checks — normalize to "yes" or "" for clean truthiness
HAS_README=$(jq -r 'if .files.readme then "yes" else "" end' "$WORK_DIR/community.json" 2>/dev/null)
HAS_LICENSE=$(jq -r 'if .files.license then "yes" else "" end' "$WORK_DIR/community.json" 2>/dev/null)
HAS_COC=$(jq -r 'if .files.code_of_conduct then "yes" else "" end' "$WORK_DIR/community.json" 2>/dev/null)
HAS_CONTRIBUTING=$(jq -r 'if .files.contributing then "yes" else "" end' "$WORK_DIR/community.json" 2>/dev/null)
HAS_ISSUE_TEMPLATE=$(jq -r 'if .files.issue_template then "yes" else "" end' "$WORK_DIR/community.json" 2>/dev/null)
HAS_PR_TEMPLATE=$(jq -r 'if .files.pull_request_template then "yes" else "" end' "$WORK_DIR/community.json" 2>/dev/null)
# Security policy — populated by parallel call above
HAS_SECURITY_POLICY=$(cat "$WORK_DIR/security.txt" 2>/dev/null)

# Labels — aggregate paginated JSON and count non-defaults
CUSTOM_LABELS=$(jq -s '[.[][] | select(.default == false)] | length' "$WORK_DIR/labels.json" 2>/dev/null)

# Branch protection (separate call - needs the default branch name)
HAS_BRANCH_PROTECTION=""
if [[ -n "$DEFAULT_BRANCH" ]]; then
  timeout 3 gh api "repos/:owner/:repo/branches/$DEFAULT_BRANCH/protection" \
    --jq '.url' >"$WORK_DIR/protection.txt" 2>/dev/null
  if [[ $? -eq 0 ]] && [[ -s "$WORK_DIR/protection.txt" ]]; then
    HAS_BRANCH_PROTECTION="yes"
  fi
fi

# --- Bail if API didn't respond ---
if [[ -z "$CONTRIBUTORS" ]] && [[ ! -s "$WORK_DIR/repo.json" ]]; then
  echo "**Note**: Could not reach GitHub API"
  exit 0
fi

# ============================================================
# SECTION 1: Project scope
# ============================================================

if [[ -n "$CONTRIBUTORS" ]]; then
  if [[ "$CONTRIBUTORS" -le 2 ]]; then
    echo "**Context**: Solo/pair project ($CONTRIBUTORS contributors)"
    echo "- PRs recommended even for solo work — they create history, enable CI, and build good habits"
    echo "- Lightweight PRs are fine: a title and a few bullet points"
  else
    # Reuse saved contributors response instead of re-fetching
    REVIEWERS=$(jq -r '.[0:5][].login' "$WORK_DIR/contributors.json" 2>/dev/null \
      | grep -v "$CURRENT_USER" | head -3 | tr '\n' ', ' | sed 's/,$//')
    echo "**Context**: Team project ($CONTRIBUTORS contributors)"
    echo "- PR required for all changes"
    if [[ -n "$REVIEWERS" ]]; then
      echo "- Potential reviewers: $REVIEWERS"
    fi
  fi
fi

# ============================================================
# SECTION 2: Repository health checks
# ============================================================

# Build array of checks: name, status (pass/fail)
declare -a CHECK_NAMES=()
declare -a CHECK_STATUS=()
declare -a CHECK_NEEDS_ADMIN=()

add_check() {
  local name="$1"
  local value="$2"
  local needs_admin="${3:-false}"
  CHECK_NAMES+=("$name")
  CHECK_NEEDS_ADMIN+=("$needs_admin")
  # Guard against empty, "null", "0", and "false" — all mean absent
  if [[ -n "$value" ]] && [[ "$value" != "null" ]] && [[ "$value" != "0" ]] && [[ "$value" != "false" ]]; then
    CHECK_STATUS+=("pass")
  else
    CHECK_STATUS+=("fail")
  fi
}

add_check "README"              "$HAS_README"             "false"
add_check "License"             "$HAS_LICENSE"            "false"
add_check "Description"         "$DESCRIPTION"            "false"
add_check "Topics"              "$TOPICS"                 "false"
add_check "Code of conduct"     "$HAS_COC"                "false"
add_check "Contributing guide"  "$HAS_CONTRIBUTING"       "false"
add_check "Issue templates"     "$HAS_ISSUE_TEMPLATE"     "false"
add_check "PR template"         "$HAS_PR_TEMPLATE"        "false"
add_check "Security policy"     "$HAS_SECURITY_POLICY"    "false"
add_check "Custom labels"       "$CUSTOM_LABELS"          "false"
add_check "Branch protection"   "$HAS_BRANCH_PROTECTION"  "true"

# Count passes and failures
TOTAL=${#CHECK_NAMES[@]}
PASS_COUNT=0
FAIL_COUNT=0
ADMIN_NEEDED=0
declare -a MISSING_NAMES=()
declare -a MISSING_FIXABLE=()

for i in "${!CHECK_STATUS[@]}"; do
  if [[ "${CHECK_STATUS[$i]}" == "pass" ]]; then
    ((PASS_COUNT++))
  else
    ((FAIL_COUNT++))
    MISSING_NAMES+=("${CHECK_NAMES[$i]}")
    # Determine if user can fix this
    if [[ "${CHECK_NEEDS_ADMIN[$i]}" == "true" ]]; then
      if [[ "$CAN_ADMIN" == "true" ]]; then
        MISSING_FIXABLE+=("yes")
      else
        MISSING_FIXABLE+=("needs admin")
        ((ADMIN_NEEDED++))
      fi
    else
      if [[ "$CAN_PUSH" == "true" ]]; then
        MISSING_FIXABLE+=("yes")
      else
        MISSING_FIXABLE+=("read-only")
      fi
    fi
  fi
done

# --- Tiered output ---

if [[ "$FAIL_COUNT" -eq 0 ]]; then
  # Silent — everything configured
  :
elif [[ "$FAIL_COUNT" -le 3 ]]; then
  # Brief hint with per-item fixability awareness
  MISSING_LIST=$(printf '%s' "${MISSING_NAMES[0]}"; printf ', %s' "${MISSING_NAMES[@]:1}")
  if [[ "$CAN_PUSH" == "true" ]]; then
    RIGHTS="you have push access"
  else
    RIGHTS="read-only access"
  fi
  # Note admin-only items separately if present
  if [[ "$ADMIN_NEEDED" -gt 0 ]]; then
    RIGHTS="$RIGHTS; $ADMIN_NEEDED need admin"
  fi
  echo ""
  echo "**Repo health**: $PASS_COUNT/$TOTAL — missing: $MISSING_LIST ($RIGHTS)"
else
  # Full table
  echo ""
  echo "**Repo health**: $PASS_COUNT/$TOTAL checks pass"
  echo ""
  echo "| Check | Status | Can fix |"
  echo "|-------|--------|---------|"
  for i in "${!CHECK_NAMES[@]}"; do
    NAME="${CHECK_NAMES[$i]}"
    if [[ "${CHECK_STATUS[$i]}" == "pass" ]]; then
      STATUS="ok"
      FIXABLE="—"
    else
      STATUS="missing"
      if [[ "${CHECK_NEEDS_ADMIN[$i]}" == "true" ]]; then
        if [[ "$CAN_ADMIN" == "true" ]]; then
          FIXABLE="yes"
        else
          FIXABLE="needs admin"
        fi
      else
        if [[ "$CAN_PUSH" == "true" ]]; then
          FIXABLE="yes"
        else
          FIXABLE="read-only"
        fi
      fi
    fi
    echo "| $NAME | $STATUS | $FIXABLE |"
  done
fi
