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

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Repo details (description, topics, permissions, default branch)
timeout 3 gh api repos/:owner/:repo \
  --jq '{
    description: .description,
    topics: .topics,
    default_branch: .default_branch,
    permissions: .permissions,
    has_issues: .has_issues,
    has_discussions: .has_discussions
  }' >"$TMPDIR/repo.json" 2>/dev/null &

# Community profile (README, license, CoC, contributing, templates, security)
timeout 3 gh api repos/:owner/:repo/community/profile \
  >"$TMPDIR/community.json" 2>/dev/null &

# Contributors
timeout 3 gh api repos/:owner/:repo/contributors \
  --jq 'length' >"$TMPDIR/contributors.txt" 2>/dev/null &

# Labels (count non-default labels)
timeout 3 gh api repos/:owner/:repo/labels --paginate \
  --jq '[.[] | select(.default == false)] | length' >"$TMPDIR/custom_labels.txt" 2>/dev/null &

# Security policy (not in community profile, check both common locations)
(timeout 3 gh api repos/:owner/:repo/contents/SECURITY.md --jq '.name' >"$TMPDIR/security.txt" 2>/dev/null ||
 timeout 3 gh api repos/:owner/:repo/contents/.github/SECURITY.md --jq '.name' >"$TMPDIR/security.txt" 2>/dev/null) &

# Current user
timeout 3 gh api user --jq '.login' >"$TMPDIR/user.txt" 2>/dev/null &

wait

# --- Parse results ---

CONTRIBUTORS=$(cat "$TMPDIR/contributors.txt" 2>/dev/null)
CURRENT_USER=$(cat "$TMPDIR/user.txt" 2>/dev/null)

# Repo details
DESCRIPTION=$(jq -r '.description // empty' "$TMPDIR/repo.json" 2>/dev/null)
TOPICS=$(jq -r '.topics | length' "$TMPDIR/repo.json" 2>/dev/null)
DEFAULT_BRANCH=$(jq -r '.default_branch // "main"' "$TMPDIR/repo.json" 2>/dev/null)
CAN_PUSH=$(jq -r '.permissions.push // false' "$TMPDIR/repo.json" 2>/dev/null)
CAN_ADMIN=$(jq -r '.permissions.admin // false' "$TMPDIR/repo.json" 2>/dev/null)

# Community profile checks
HAS_README=$(jq -r '.files.readme // empty' "$TMPDIR/community.json" 2>/dev/null)
HAS_LICENSE=$(jq -r '.files.license // empty' "$TMPDIR/community.json" 2>/dev/null)
HAS_COC=$(jq -r '.files.code_of_conduct // empty' "$TMPDIR/community.json" 2>/dev/null)
HAS_CONTRIBUTING=$(jq -r '.files.contributing // empty' "$TMPDIR/community.json" 2>/dev/null)
HAS_ISSUE_TEMPLATE=$(jq -r '.files.issue_template // empty' "$TMPDIR/community.json" 2>/dev/null)
HAS_PR_TEMPLATE=$(jq -r '.files.pull_request_template // empty' "$TMPDIR/community.json" 2>/dev/null)
# Security policy — populated by parallel call above
HAS_SECURITY_POLICY=$(cat "$TMPDIR/security.txt" 2>/dev/null)

CUSTOM_LABELS=$(cat "$TMPDIR/custom_labels.txt" 2>/dev/null)

# Branch protection (separate call - needs the default branch name)
HAS_BRANCH_PROTECTION=""
if [[ -n "$DEFAULT_BRANCH" ]]; then
  timeout 3 gh api "repos/:owner/:repo/branches/$DEFAULT_BRANCH/protection" \
    --jq '.url' >"$TMPDIR/protection.txt" 2>/dev/null
  if [[ $? -eq 0 ]] && [[ -s "$TMPDIR/protection.txt" ]]; then
    HAS_BRANCH_PROTECTION="yes"
  fi
fi

# --- Bail if API didn't respond ---
if [[ -z "$CONTRIBUTORS" ]] && [[ ! -s "$TMPDIR/repo.json" ]]; then
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
    REVIEWERS=$(timeout 2 gh api repos/:owner/:repo/contributors \
      --jq '.[0:5][].login' 2>/dev/null | grep -v "$CURRENT_USER" | head -3 | tr '\n' ', ' | sed 's/,$//')
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
  if [[ -n "$value" ]] && [[ "$value" != "null" ]] && [[ "$value" != "0" ]]; then
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
add_check "Custom labels"       "$CUSTOM_LABELS"          "true"
add_check "Branch protection"   "$HAS_BRANCH_PROTECTION"  "true"

# Count passes and failures
TOTAL=${#CHECK_NAMES[@]}
PASS_COUNT=0
FAIL_COUNT=0
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
  # Brief hint
  MISSING_LIST=$(printf '%s' "${MISSING_NAMES[0]}"; printf ', %s' "${MISSING_NAMES[@]:1}")
  if [[ "$CAN_PUSH" == "true" ]]; then
    RIGHTS="you have push access"
  else
    RIGHTS="read-only access"
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
