---
description: Test way matching scores and suggest vocabulary improvements
---

# test-way: Way Authoring Tool

Test how well a way matches sample prompts, or analyze its vocabulary for gaps.

## Usage

The user invokes `/test-way` with one of these patterns:

### Score mode: test a way against prompts
```
/test-way score <path/to/way.md> "sample prompt here"
/test-way score security "how do i hash passwords with bcrypt"
```

### Score all ways: rank all ways against a prompt
```
/test-way score-all "sample prompt here"
```

### Suggest mode: analyze vocabulary gaps
```
/test-way suggest <path/to/way.md>
/test-way suggest security
/test-way suggest --all
```

### Suggest + apply: update vocabulary in-place
```
/test-way suggest <path/to/way.md> --apply
/test-way suggest --all --apply
```

### Lint mode: validate way frontmatter
```
/test-way lint <path/to/way.md>
/test-way lint --all
```

## Implementation

### Resolving way paths

When the user gives a short name like "security" instead of a full path:
1. Check `$CLAUDE_PROJECT_DIR/.claude/ways/` first (project-local)
2. Then check `~/.claude/hooks/ways/` recursively for `*/security/way.md`
3. If multiple matches, list them and ask the user to pick

### Score mode

Use the `way-match` binary at `~/.claude/bin/way-match`:

```bash
# Extract frontmatter fields from the way.md
description=$(awk 'NR==1 && /^---$/{p=1;next} p&&/^---$/{exit} p && /^description:/{gsub(/^description: */,"");print;exit}' "$wayfile")
vocabulary=$(awk 'NR==1 && /^---$/{p=1;next} p&&/^---$/{exit} p && /^vocabulary:/{gsub(/^vocabulary: */,"");print;exit}' "$wayfile")
threshold=$(awk 'NR==1 && /^---$/{p=1;next} p&&/^---$/{exit} p && /^threshold:/{gsub(/^threshold: */,"");print;exit}' "$wayfile")

# Score with BM25
~/.claude/bin/way-match pair \
  --description "$description" \
  --vocabulary "$vocabulary" \
  --query "$prompt" \
  --threshold "${threshold:-2.0}"
# Exit code: 0 = match, 1 = no match
# Stderr: "match: score=X.XXXX threshold=Y.YYYY"
```

Display the score, threshold, and match/no-match result. If the way has no vocabulary, note that semantic matching is unavailable — only pattern matching applies.

### Score-all mode

For each way.md file found (project-local + global), extract description+vocabulary and run `way-match pair`. Display results as a ranked table:

```
Score   Threshold  Match  Way
------  ---------  -----  ---
4.7570  2.0        YES    softwaredev/security
2.3573  2.0        YES    softwaredev/api
1.6812  2.0        no     softwaredev/debugging
0.0000  2.0        no     softwaredev/design
```

Include ways that have pattern matches too (mark those as "REGEX" in the Match column).

### Suggest mode

Use the `way-match suggest` command:

```bash
~/.claude/bin/way-match suggest --file "$wayfile" --min-freq 2
```

Output is section-delimited (GAPS, COVERAGE, UNUSED, VOCABULARY). Parse and display in a readable format:

```
=== Vocabulary Analysis: softwaredev/security ===

Gaps (body terms not in vocabulary, freq >= 2):
  parameterized  freq=3
  endpoints      freq=2
  hardcoded      freq=2

Coverage (vocabulary terms found in body):
  sql            freq=3
  secrets        freq=3
  input          freq=4

Unused (vocabulary terms not in body):
  owasp, csrf, cors, xss   (these catch user prompts, not body text — likely intentional)

Suggested vocabulary line:
  vocabulary: <current> <+ gaps>
```

### Suggest + apply

When `--apply` is specified:

1. **Git safety check**: Verify the way file is inside a git worktree:
   ```bash
   cd "$(dirname "$wayfile")" && git rev-parse --is-inside-work-tree 2>/dev/null
   ```

2. **If NOT git-tracked**: Display a warning and refuse unless `--force` is also specified:
   ```
   WARNING: <path> is NOT in a git repository.
   Changes cannot be easily reverted. Use --force to apply anyway.
   ```

3. **If git-tracked** (or --force):
   - Parse the VOCABULARY line from suggest output
   - Use `sed` to replace the `vocabulary:` line in the way.md frontmatter
   - Show the diff: `git diff "$wayfile"`
   - Report: "Updated vocabulary in <path> (+N terms)"

4. **For `--all --apply`**: Process each way file that has gaps, showing progress.

### Lint mode

Validate way frontmatter for correctness:

- Check required fields: `description` must be present
- If `match: semantic` or vocabulary is present: check that both `description` and `vocabulary` exist
- If `pattern` is present: verify it's valid regex (test with `[[ "" =~ $pattern ]]`)
- Check `threshold` is a number if present
- Check `scope` values are valid (agent, subagent, teammate)
- Report issues per file

### `--all` flag

When `--all` is specified for suggest or lint:
1. Find all way.md files in `~/.claude/hooks/ways/` recursively
2. Also check `$CLAUDE_PROJECT_DIR/.claude/ways/` if project dir is set
3. Process each file and aggregate results

## Notes

- The `way-match` binary must exist at `~/.claude/bin/way-match`. If missing, report that BM25 is unavailable and suggest building it: `make -f tools/way-match/Makefile local`
- The UNUSED section in suggest output is informational — unused vocabulary terms are often intentional (they catch user query terms that don't appear in the way body). Don't automatically remove them.
- When displaying results, use the human-readable format, not the raw machine output from the binary.
