#!/bin/bash
# Dynamic table generator for core.md
# Scans all way.md files and generates a table of triggers

WAYS_DIR="${HOME}/.claude/hooks/ways"

echo "## Available Ways"
echo ""

# Track current domain for section headers
CURRENT_DOMAIN=""

# Find all way.md files, sorted by path
while IFS= read -r wayfile; do
  # Extract relative path (e.g., "softwaredev/github")
  relpath="${wayfile#$WAYS_DIR/}"
  relpath="${relpath%/way.md}"

  # Skip if not in a domain subdirectory
  [[ "$relpath" != */* ]] && continue

  # Extract domain and way name
  domain="${relpath%%/*}"
  wayname="${relpath##*/}"

  # Print domain header if changed
  if [[ "$domain" != "$CURRENT_DOMAIN" ]]; then
    # Format domain name (capitalize first letter)
    domain_display="$(echo "${domain:0:1}" | tr '[:lower:]' '[:upper:]')${domain:1}"
    echo "### ${domain_display}"
    echo ""
    echo "| Way | Tool Trigger | Keyword Trigger |"
    echo "|-----|--------------|-----------------|"
    CURRENT_DOMAIN="$domain"
  fi

  # Extract frontmatter fields (only from first block, stop at second ---)
  frontmatter=$(awk 'NR==1 && /^---$/{p=1; next} p && /^---$/{exit} p{print}' "$wayfile")
  match_type=$(echo "$frontmatter" | awk '/^match:/{gsub(/^match: */, ""); print}')
  pattern=$(echo "$frontmatter" | awk '/^pattern:/{gsub(/^pattern: */, ""); print}')
  commands=$(echo "$frontmatter" | awk '/^commands:/{gsub(/^commands: */, ""); print}')
  files=$(echo "$frontmatter" | awk '/^files:/{gsub(/^files: */, ""); print}')

  # Build tool trigger description
  tool_trigger="—"
  if [[ -n "$commands" ]]; then
    # Simplify common patterns for display (strip regex escapes for matching)
    cmd_clean=$(echo "$commands" | sed 's/\\//g')
    case "$cmd_clean" in
      *"git commit"*) tool_trigger="Run \`git commit\`" ;;
      *"^gh"*|*"gh "*) tool_trigger="Run \`gh\`" ;;
      *"ssh"*|*"scp"*|*"rsync"*) tool_trigger="Run \`ssh\`, \`scp\`, \`rsync\`" ;;
      *"pytest"*|*"jest"*) tool_trigger="Run \`pytest\`, \`jest\`, etc" ;;
      *"npm install"*|*"pip install"*) tool_trigger="Run \`npm install\`, etc" ;;
      *"git apply"*) tool_trigger="Run \`git apply\`" ;;
      *) tool_trigger="Run command" ;;
    esac
  elif [[ -n "$files" ]]; then
    # Simplify file patterns for display
    case "$files" in
      *"docs/adr"*) tool_trigger="Edit \`docs/adr/*.md\`" ;;
      *"\.env"*) tool_trigger="Edit \`.env\`" ;;
      *"\.patch"*|*"\.diff"*) tool_trigger="Edit \`*.patch\`, \`*.diff\`" ;;
      *"todo-"*) tool_trigger="Edit \`.claude/todo-*.md\`" ;;
      *"ways/"*) tool_trigger="Edit \`.claude/ways/*.md\`" ;;
      *"README"*) tool_trigger="Edit \`README.md\`, \`docs/*.md\`" ;;
      *) tool_trigger="Edit files matching pattern" ;;
    esac
  fi

  # Format pattern for display (strip regex syntax, keep readable)
  keyword_display="—"
  if [[ "$match_type" == "semantic" || "$match_type" == "model" ]]; then
    keyword_display="_(${match_type})_"
  elif [[ -n "$pattern" ]]; then
    # Strip regex syntax, word boundaries, escapes — keep human-readable keywords
    # 1. Replace regex connectors with space (literal dot+quantifier patterns)
    # 2. Strip remaining regex syntax
    # 3. Normalize whitespace and comma formatting
    keyword_display=$(echo "$pattern" | \
      sed 's/[.][?]/ /g; s/[.][*]/ /g; s/[.][+]/ /g' | \
      sed 's/\\b//g; s/\\//g; s/[?]//g; s/\^//g; s/\$//g; s/(/ /g; s/)//g; s/|/,/g; s/\[//g; s/\]//g' | \
      sed 's/  */ /g; s/ *, */,/g; s/,,*/,/g; s/^,//; s/,$//; s/,/, /g' | \
      awk -F', ' '{
        for(i=1;i<=NF;i++){
          if(!seen[$i]++){
            w=$i
            # Append * to regex stems (truncated prefixes)
            if(length(w)>=5 && match(w,/(at|nc|ndl|pos|isz|rat|handl|mi)$/))w=w"*"
            printf "%s%s",(i>1?", ":""),w
          }
        }
        print""
      }')
  fi

  echo "| **${wayname}** | ${tool_trigger} | ${keyword_display} |"

done < <(find "$WAYS_DIR" -path "*/*/way.md" -type f | sort)

echo ""
echo "Project-local ways: \`\$PROJECT/.claude/ways/{domain}/{way}/way.md\` override global."
