#!/bin/bash
# way-tree-analyze.sh — Analyze progressive disclosure tree structure
#
# Usage:
#   way-tree-analyze.sh tree <path>      # Structural analysis
#   way-tree-analyze.sh budget <path>    # Token cost analysis
#   way-tree-analyze.sh jaccard <path>   # Vocabulary overlap for siblings
#
# Output: Tab-delimited for easy parsing by the ways-tests skill.

set -euo pipefail

WAYS_ROOT="${HOME}/.claude/hooks/ways"
WAY_MATCH="${HOME}/.claude/bin/way-match"

# Extract a frontmatter field from a way.md file
extract_field() {
  local file="$1" field="$2"
  awk -v f="$field" '
    NR==1 && /^---$/ {p=1; next}
    p && /^---$/ {exit}
    p && $0 ~ "^"f":" {
      sub("^"f": *", "")
      print
      exit
    }
  ' "$file"
}

# Strip frontmatter, return body only
strip_frontmatter() {
  awk '
    NR==1 && /^---$/ {skip=1; next}
    skip && /^---$/ {skip=0; next}
    !skip {print}
  ' "$1"
}

# Estimate tokens from a way file (body only, bytes / 4)
estimate_tokens() {
  local bytes
  bytes=$(strip_frontmatter "$1" | wc -c)
  echo $(( bytes / 4 ))
}

# Compute Jaccard similarity between two space-separated word lists
jaccard() {
  local a="$1" b="$2"
  python3 -c "
import sys
a = set(sys.argv[1].split())
b = set(sys.argv[2].split())
if not a and not b:
    print('0.00')
else:
    j = len(a & b) / len(a | b) if (a | b) else 0
    print(f'{j:.2f}')
" "$a" "$b"
}

# Resolve a short name or relative path to absolute ways path
resolve_path() {
  local input="$1"
  # Already absolute
  if [[ "$input" == /* ]]; then
    echo "$input"
    return
  fi
  # Check if it's a relative path under WAYS_ROOT
  if [[ -d "${WAYS_ROOT}/${input}" ]]; then
    echo "${WAYS_ROOT}/${input}"
    return
  fi
  # Search recursively
  local matches
  matches=$(find "$WAYS_ROOT" -type d -name "$input" 2>/dev/null | head -5)
  if [[ -z "$matches" ]]; then
    echo "ERROR: Cannot resolve '$input'" >&2
    exit 1
  fi
  local count
  count=$(echo "$matches" | wc -l)
  if [[ "$count" -gt 1 ]]; then
    echo "AMBIGUOUS: Multiple matches for '$input':" >&2
    echo "$matches" >&2
    exit 1
  fi
  echo "$matches"
}

# Get relative path from WAYS_ROOT
relpath() {
  local full="$1"
  echo "${full#${WAYS_ROOT}/}"
}

# === tree command ===
cmd_tree() {
  local tree_path
  tree_path=$(resolve_path "$1")

  echo "TREE_ROOT	$(relpath "$tree_path")"

  # Find all way.md and check.md files
  while IFS= read -r wayfile; do
    local rel dir depth threshold vocab description type
    rel=$(relpath "$wayfile")
    dir=$(dirname "$wayfile")
    # Depth = directory levels below tree_path
    local subpath="${dir#${tree_path}}"
    subpath="${subpath#/}"
    if [[ -z "$subpath" ]]; then
      depth=0
    else
      depth=$(echo "$subpath" | tr '/' '\n' | wc -l)
    fi

    threshold=$(extract_field "$wayfile" "threshold")
    vocab=$(extract_field "$wayfile" "vocabulary")
    description=$(extract_field "$wayfile" "description")

    if [[ "$(basename "$wayfile")" == "check.md" ]]; then
      type="check"
    else
      type="way"
    fi

    # Output: depth, relative path, threshold, type, vocab word count, token estimate
    local tokens vocabcount
    tokens=$(estimate_tokens "$wayfile")
    vocabcount=$(echo "$vocab" | wc -w)
    echo "NODE	${depth}	${rel}	${threshold:-none}	${type}	${vocabcount}	${tokens}"
  done < <(find "$tree_path" -name 'way.md' -o -name 'check.md' | sort)
}

# === budget command ===
cmd_budget() {
  local tree_path
  tree_path=$(resolve_path "$1")

  echo "BUDGET_ROOT	$(relpath "$tree_path")"

  # Per-way token costs
  while IFS= read -r wayfile; do
    local rel tokens
    rel=$(relpath "$wayfile")
    tokens=$(estimate_tokens "$wayfile")
    echo "WAY	${rel}	${tokens}"
  done < <(find "$tree_path" -name 'way.md' -o -name 'check.md' | sort)

  # Path costs (root to each leaf)
  local root_tokens=0
  local root_way="${tree_path}/way.md"
  if [[ -f "$root_way" ]]; then
    root_tokens=$(estimate_tokens "$root_way")
  fi

  # Find leaf directories (dirs with way.md but no subdirectory way.md)
  while IFS= read -r wayfile; do
    local dir="${wayfile%/way.md}"
    [[ "$dir" == "$tree_path" ]] && continue

    # Build path from root to this way
    local path_tokens=$root_tokens
    local current="$tree_path"
    local segments="${dir#${tree_path}/}"

    # Walk intermediate directories
    local accumulated=""
    IFS='/' read -ra parts <<< "$segments"
    for part in "${parts[@]}"; do
      accumulated="${accumulated:+${accumulated}/}${part}"
      local mid_way="${tree_path}/${accumulated}/way.md"
      if [[ -f "$mid_way" ]]; then
        local mid_tokens
        mid_tokens=$(estimate_tokens "$mid_way")
        path_tokens=$((path_tokens + mid_tokens))
      fi
    done

    echo "PATH	$(relpath "$dir")	${path_tokens}"
  done < <(find "$tree_path" -name 'way.md' | sort)
}

# === jaccard command ===
cmd_jaccard() {
  local tree_path
  tree_path=$(resolve_path "$1")

  echo "JACCARD_ROOT	$(relpath "$tree_path")"

  # Find directories containing way.md, group by parent
  declare -A parent_children
  while IFS= read -r wayfile; do
    local dir parent
    dir=$(dirname "$wayfile")
    parent=$(dirname "$dir")
    parent_children["$parent"]+="${wayfile}"$'\n'
  done < <(find "$tree_path" -name 'way.md' | sort)

  # For each parent, compute pairwise Jaccard of children's vocabularies
  for parent in "${!parent_children[@]}"; do
    local children=()
    local vocabs=()
    while IFS= read -r child; do
      [[ -z "$child" ]] && continue
      children+=("$child")
      vocabs+=("$(extract_field "$child" "vocabulary")")
    done <<< "${parent_children[$parent]}"

    local n=${#children[@]}
    if [[ $n -lt 2 ]]; then
      continue
    fi

    for ((i=0; i<n; i++)); do
      for ((j=i+1; j<n; j++)); do
        local j_score
        j_score=$(jaccard "${vocabs[$i]}" "${vocabs[$j]}")
        echo "PAIR	$(relpath "${children[$i]}")	$(relpath "${children[$j]}")	${j_score}"
      done
    done
  done
}

# === main ===
case "${1:-}" in
  tree)
    cmd_tree "${2:?Usage: $0 tree <path>}"
    ;;
  budget)
    cmd_budget "${2:?Usage: $0 budget <path>}"
    ;;
  jaccard)
    cmd_jaccard "${2:?Usage: $0 jaccard <path>}"
    ;;
  *)
    echo "Usage: $0 {tree|budget|jaccard} <path>" >&2
    exit 1
    ;;
esac
