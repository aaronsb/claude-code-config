#!/bin/bash
# ADR way macro — tri-state detection of ADR tooling in project
#
# States:
#   declined  → .claude/no-adr-tooling exists → one-liner, stop nagging
#   installed → docs/scripts/adr (or similar) found → command reference
#   available → neither → suggest installation

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

# State 1: Declined
if [[ -f "$PROJECT_DIR/.claude/no-adr-tooling" ]]; then
  echo "ADR tooling declined for this project. Remove \`.claude/no-adr-tooling\` to enable."
  exit 0
fi

# State 2: Installed — check common locations
ADR_SCRIPT=""
for path in "docs/scripts/adr" "scripts/adr" "tools/adr"; do
  if [[ -x "$PROJECT_DIR/$path" ]]; then
    ADR_SCRIPT="$path"
    break
  fi
done

if [[ -n "$ADR_SCRIPT" ]]; then
  echo "## ADR Tooling"
  echo ""
  echo "Use \`$ADR_SCRIPT\` for ADR management:"
  echo ""
  echo "| Command | Purpose |"
  echo "|---------|---------|"
  echo "| \`$ADR_SCRIPT new <domain> <title>\` | Create new ADR |"
  echo "| \`$ADR_SCRIPT list [--group]\` | List all ADRs |"
  echo "| \`$ADR_SCRIPT view <number>\` | View an ADR |"
  echo "| \`$ADR_SCRIPT lint [--check]\` | Validate ADRs |"
  echo "| \`$ADR_SCRIPT index -y\` | Regenerate index |"
  echo "| \`$ADR_SCRIPT domains\` | Show domain series |"
  echo ""
  echo "**Always use \`$ADR_SCRIPT new\` to create ADRs** — it handles numbering, domain routing, and templates."

  # Check if project script differs from universal template
  UNIVERSAL="${HOME}/.claude/hooks/ways/softwaredev/architecture/adr/adr-tool"
  if [[ -f "$UNIVERSAL" ]] && ! diff -q "$PROJECT_DIR/$ADR_SCRIPT" "$UNIVERSAL" &>/dev/null; then
    echo ""
    echo "_Note: Project script differs from the universal template. This is expected for customized setups._"
  fi
  exit 0
fi

# State 3: Not installed
echo "## ADR Tooling Available"
echo ""
echo "This project doesn't have ADR management tooling installed."
echo "A script-based system is available that provides:"
echo "- Automatic numbering by domain"
echo "- Template generation with frontmatter"
echo "- Linting and validation"
echo "- Index generation"
echo ""
echo "To install: \`mkdir -p docs/scripts && cp ~/.claude/hooks/ways/softwaredev/architecture/adr/adr-tool docs/scripts/adr && chmod +x docs/scripts/adr && mkdir -p docs/architecture && cp ~/.claude/hooks/ways/softwaredev/architecture/adr/adr.yaml.template docs/architecture/adr.yaml\`"
echo ""
echo "To decline permanently: \`mkdir -p .claude && touch .claude/no-adr-tooling\`"
