---
name: context-status
description: Check how much context window remains in this session. Use when you want to know token budget, context usage, or how much room is left before compaction. Also use proactively when working on long tasks to gauge remaining capacity.
allowed-tools: Bash
---

# Context Status

Run the context usage script and capture the JSON output:

```bash
~/.claude/scripts/context-usage.sh --json "${CLAUDE_PROJECT_DIR:-$PWD}"
```

Then render a visual gauge using the chart tool. Build the JSON and pipe it:

```bash
# Parse the values from the --json output, then:
echo '{"type":"hbar","data":{"Used (PCT%)":USED,"Free (RPCT%)":REMAINING},"title":"Context: USEDk / TOTALk tokens (MODEL)","width":60,"format":"human"}' \
  | ~/.claude/hooks/ways/softwaredev/visualization/charts/chart-tool
```

Replace `USED`, `REMAINING`, `TOTAL`, `PCT`, `RPCT`, and `MODEL` with actual values from the JSON output. Use `jq` to extract them.

The script auto-detects the context window size from the model in the transcript (1M for Opus 4.6, 200k for others). Override with `CLAUDE_CONTEXT_WINDOW` env var.

If the remaining percentage is below 20%, mention that compaction is approaching and suggest wrapping up or prioritizing remaining work.
