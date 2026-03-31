---
description: Score way matching, analyze vocabulary, and validate frontmatter
---

# ways-tests: Way Matching & Vocabulary Tool

Test how well a way matches sample prompts, or analyze its vocabulary for gaps.

## Usage

The user invokes `/ways-tests` with one of these patterns:

### Score mode: test a way against prompts
```
/ways-tests score <path/to/{name}.md> "sample prompt here"
/ways-tests score security "how do i hash passwords with bcrypt"
```

### Score all ways: rank all ways against a prompt
```
/ways-tests score-all "sample prompt here"
```

### Suggest mode: analyze vocabulary gaps
```
/ways-tests suggest <path/to/{name}.md>
/ways-tests suggest security
/ways-tests suggest --all
```

### Suggest + apply: update vocabulary in-place
```
/ways-tests suggest <path/to/{name}.md> --apply
/ways-tests suggest --all --apply
```

### Lint mode: validate way frontmatter
```
/ways-tests lint <path/to/{name}.md>
/ways-tests lint --all
```

## Implementation

### Resolving way paths

When the user gives a short name like "security" instead of a full path:
1. Check `$CLAUDE_PROJECT_DIR/.claude/ways/` first (project-local)
2. Then check `~/.claude/hooks/ways/` recursively for `*/security/security.md`
3. If multiple matches, list them and ask the user to pick

### Score mode

Use the `ways match` subcommand:

```bash
# Score with BM25
ways match \
  --description "$description" \
  --vocabulary "$vocabulary" \
  --query "$prompt" \
  --threshold "${threshold:-2.0}"
# Exit code: 0 = match, 1 = no match
# Stderr: "match: score=X.XXXX threshold=Y.YYYY"
```

Display the score, threshold, and match/no-match result. If the way has no vocabulary, note that semantic matching is unavailable — only pattern matching applies.

### Score-all mode

For each way file found (project-local + global), extract description+vocabulary and run `way-match pair`. Display results as a ranked table:

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

Use the `ways suggest` subcommand:

```bash
ways suggest --file "$wayfile" --min-freq 2
```

Output is section-delimited (GAPS, COVERAGE, UNUSED, VOCABULARY). Parse and display in a readable format:

```
=== Vocabulary Analysis: softwaredev/code/security ===

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
   - Use `sed` to replace the `vocabulary:` line in the way file frontmatter
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
1. Find all way files in `~/.claude/hooks/ways/` recursively
2. Also check `$CLAUDE_PROJECT_DIR/.claude/ways/` if project dir is set
3. Process each file and aggregate results

### Check mode: test check scoring curve

```
/ways-tests check <path/to/{name}.check.md> "tool context" --distance N --fires N
/ways-tests check design "editing architecture file" --distance 20 --fires 0
```

Simulates the check scoring curve for a given `{name}.check.md` against tool context. Accepts optional `--distance` (epoch distance from parent way, default 10) and `--fires` (prior fire count this session, default 0).

Displays:
```
Check: softwaredev/architecture/design
  Match score:     2.40
  Distance factor: 3.30  (epoch distance: 20)
  Decay factor:    1.00  (fire count: 0)
  Effective score: 7.92
  Threshold:       2.00
  Result:          FIRES (anchored)

Simulate decay:
  Fire 1: effective=7.92  FIRES
  Fire 2: effective=3.96  FIRES
  Fire 3: effective=2.64  FIRES
  Fire 4: effective=1.98  stops
```

Implementation:
1. Extract frontmatter from check file (description, vocabulary, threshold)
2. Score the query with `way-match pair` to get match_score
3. Apply the curve: `effective = match_score × (ln(distance+1)+1) × (1/(fires+1))`
4. Show the breakdown and simulate successive firings until the check stops

### Check-all mode: rank all checks against context

```
/ways-tests check-all "editing a database schema migration"
```

Like `score-all` but for `*.check.md` files. Shows match score, effective score at various distances, and how many fires before decay silences each check.

### Lint mode (updated for checks)

Lint now also validates `*.check.md` files:

- Check required fields: `description` must be present
- Verify `## anchor` and `## check` sections exist in body
- Verify threshold is a number
- Check that parent way file exists in same directory (orphan check detection)
- Report issues per file

Use `--all` to lint all ways AND checks.

## Notes

- BM25 scoring is built into the `ways` binary. If `ways` is missing, run `make setup` in `~/.claude`
- The UNUSED section in suggest output is informational — unused vocabulary terms are often intentional (they catch user query terms that don't appear in the way body). Don't automatically remove them.
- When displaying results, use the human-readable format, not the raw machine output from the binary.
- Check scoring uses `awk` for floating-point math — ensure `awk` is available (standard on all Unix systems).
