---
name: ways-tests
description: Score way matching, analyze vocabulary, and validate frontmatter. Use when testing how well a way matches prompts, checking for vocabulary gaps, or validating way files.
allowed-tools: Bash, Read, Glob, Grep, Edit
---

# ways-tests: Way Matching & Vocabulary Tool

Test how well a way matches sample prompts, analyze vocabulary for gaps, and validate frontmatter.

## Usage

```
/ways-tests score <way> "prompt"          # Score one way against a prompt
/ways-tests score-all "prompt"            # Rank all ways against a prompt
/ways-tests suggest <way>                 # Analyze vocabulary gaps
/ways-tests suggest <way> --apply         # Update vocabulary in-place
/ways-tests suggest --all [--apply]       # Analyze/update all ways
/ways-tests lint <way>                    # Validate frontmatter
/ways-tests lint --all                    # Validate all ways
/ways-tests check <check> "context"       # Test check scoring curve
/ways-tests check-all "context"           # Rank all checks against context
/ways-tests tree <path>                   # Analyze progressive disclosure tree structure
/ways-tests budget <path>                 # Token cost analysis for a way tree
/ways-tests crowding "prompt"             # Detect vocabulary crowding across all ways
/ways-tests compare <path1> <path2>       # Side-by-side tree metrics comparison
/ways-tests metrics                       # Show tree disclosure metrics for current session
```

## Resolving Way Paths

When the user gives a short name like "security" instead of a full path:
1. Check `$CLAUDE_PROJECT_DIR/.claude/ways/` first (project-local)
2. Then check `~/.claude/hooks/ways/` recursively for `*/security/way.md`
3. If multiple matches, list them and ask the user to pick

## Score Mode

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

### Cross-Way Context (automatic)

**When scoring a single way, always include cross-way context.** After showing the target way's score, automatically run a score-all for the same prompt and display the top 5-8 ways as a ranking table. This answers the real questions:

- Does this way **win** when it should?
- Does it **defer** to the right way when another is more specific?
- Are there **unhealthy overlaps** where two ways compete at similar scores?
- Do any **unexpected ways** fire that shouldn't?

Present as:

```
=== "add a make target for linting" ===

Target: softwaredev/environment/makefile
  Score: 5.2716  Threshold: 1.5  Result: MATCH

Cross-way ranking:
  Score   Thr    Match  Way
  ------  -----  -----  ---
  5.2716  1.5    YES    softwaredev/environment/makefile  ← target
  1.9580  2.0    no     softwaredev/docs/standards
  0.0000  2.0    no     softwaredev/environment/deps
  ...

Assessment: Clean win. No competing ways above threshold.
```

Flag these patterns:
- **Overlap**: Two ways both match with scores within 20% of each other → potential conflict
- **False dominance**: Another way scores higher than the target → the target may need vocabulary tuning
- **Healthy co-fire**: Both match but serve complementary purposes → note as expected

## Score-All Mode

For each way.md file found (project-local + global), extract description+vocabulary and run `way-match pair`. Display results as a ranked table:

```
Score   Threshold  Match  Way
------  ---------  -----  ---
4.7570  2.0        YES    softwaredev/security
2.3573  2.0        YES    softwaredev/api
1.6812  2.0        no     softwaredev/debugging
```

Include ways that have pattern matches too (mark those as "REGEX" in the Match column).

### Prompt Battery (automatic for score-all)

When running score-all without a specific prompt, or when the user asks for a broad evaluation, generate a battery of 8-12 diverse prompts that stress-test coverage:

- 2-3 prompts that should clearly match one specific way
- 2-3 prompts that should trigger healthy co-fires (multiple ways relevant)
- 2-3 prompts at the boundary (could go either way)
- 2-3 prompts that shouldn't match any way strongly

This gives a landscape view of how the way ecosystem behaves.

## Suggest Mode

Use the `way-match suggest` command:

```bash
~/.claude/bin/way-match suggest --file "$wayfile" --min-freq 2
```

Output is section-delimited (GAPS, COVERAGE, UNUSED, VOCABULARY). Parse and display readably:

```
=== Vocabulary Analysis: softwaredev/code/security ===

Gaps (body terms not in vocabulary, freq >= 2):
  parameterized  freq=3
  endpoints      freq=2

Coverage (vocabulary terms found in body):
  sql            freq=3
  secrets        freq=3

Unused (vocabulary terms not in body):
  owasp, csrf, cors   (catch user prompts, not body text — likely intentional)

Suggested vocabulary line:
  vocabulary: <current> <+ gaps>
```

The UNUSED section is informational — unused vocabulary terms are often intentional (they catch user query terms that don't appear in the way body). Don't automatically remove them.

### Suggest + Apply

When `--apply` is specified:

1. **Git safety check**: Verify the way file is inside a git worktree
2. **If NOT git-tracked**: Warn and refuse unless `--force` is also specified
3. **If git-tracked**: Replace the vocabulary line, show diff, report count
4. **For `--all --apply`**: Process each way that has gaps, showing progress

## Lint Mode

Validate way frontmatter and tree structure:

### Frontmatter Validation
- `description` must be present
- If vocabulary present: check both description and vocabulary exist
- If `pattern` present: verify valid regex
- `threshold` must be numeric if present
- `scope` values must be valid (agent, subagent, teammate)
- For check.md files: verify `## anchor` and `## check` sections exist, and parent way.md exists

### Progressive Disclosure Validation (when `--all`)
When linting all ways, also check tree structural health:
- **Threshold progression**: Flag child ways with threshold <= parent threshold
- **Vocabulary isolation**: Flag siblings with Jaccard > 0.15
- **Orphan detection**: Flag way.md files in subdirectories with no ancestor way.md
- **Token budget**: Flag individual ways > 500 tokens (frontmatter-stripped)
- **Tree depth**: Warn if any tree exceeds depth 4

## Check Mode

Simulates the check scoring curve:

```bash
/ways-tests check design "editing architecture file" --distance 20 --fires 0
```

Displays match score, distance factor, decay factor, effective score, and simulates successive firings until decay silences the check.

## Tree Mode

Analyze the progressive disclosure structure of a way tree. The path can be a short name (e.g., `supplychain`) or full path.

Walk the tree recursively, finding all `way.md` and `check.md` files. For each file, extract frontmatter and compute structural metrics.

### What to Report

```
=== Tree Analysis: softwaredev/code/supplychain ===

Structure:
  Depth: 3 levels (root → depscan → python)
  Breadth: 5 at level 1, 4 at level 2
  Total ways: 8 way.md + 1 check.md = 9 files

Threshold Progression:
  Level 0  way.md          threshold=1.8  ✓
  Level 1  repoaudit       threshold=2.0  ✓
  Level 1  sourceaudit     threshold=2.0  ✓
  Level 1  depscan         threshold=1.8  ⚠ same as parent
  Level 1  automation      threshold=2.0  ✓
  Level 1  historysever    threshold=2.0  ✓
  Level 2  depscan/python  threshold=2.5  ✓
  Level 2  depscan/node    threshold=2.5  ✓
  Level 2  depscan/go      threshold=2.5  ✓
  Level 2  depscan/rust    threshold=2.5  ✓

Assessment: Thresholds increase with depth (1.8→2.0→2.5). Good.
```

### What to Flag

- **Threshold inversion**: Child has lower threshold than parent → fires more easily than its parent, breaks progressive disclosure
- **Flat threshold**: Parent and child share exact threshold → no progressive narrowing
- **Vocabulary overlap**: Sibling ways with Jaccard similarity > 0.15 → competing triggers

To compute **sibling vocabulary Jaccard**: for each pair of sibling way.md files at the same directory level, split vocabulary into word sets, compute `|A ∩ B| / |A ∪ B|`.

```bash
# Extract vocabulary words from two sibling ways
vocab_a=$(awk '...' way_a.md)  # frontmatter extraction
vocab_b=$(awk '...' way_b.md)
# Compute Jaccard in awk or python
```

- **Orphan ways**: A way.md in a subdirectory where no parent directory has a way.md → no progressive disclosure root
- **Deep trees**: Depth > 4 levels → likely over-decomposed
- **Wide trees**: Breadth > 7 at any level → may need sub-grouping

## Budget Mode

Estimate token cost for a way tree. Uses `wc -c` on frontmatter-stripped content divided by 4 as a rough token estimate.

### What to Report

```
=== Token Budget: softwaredev/code/supplychain ===

Per-way:
  way.md              ~300 tokens
  check.md            ~150 tokens
  repoaudit/way.md    ~450 tokens
  sourceaudit/way.md  ~280 tokens
  depscan/way.md      ~430 tokens
  depscan/python      ~250 tokens
  depscan/node        ~240 tokens
  depscan/go          ~230 tokens
  depscan/rust        ~210 tokens
  automation/way.md   ~720 tokens
  historysever/way.md ~580 tokens

Paths (root → leaf):
  → repoaudit                    ~900 tokens
  → sourceaudit                  ~730 tokens
  → depscan → python             ~980 tokens
  → depscan → node               ~970 tokens
  → depscan → go                 ~960 tokens
  → depscan → rust               ~940 tokens
  → automation                   ~1020 tokens
  → historysever                 ~1030 tokens

Worst case (all fire):           ~3840 tokens
Average path:                    ~940 tokens
Longest path:                    ~1030 tokens

Benchmarks:
  Realistic path target: ~1200 tokens
  Worst-case target:     ~4000 tokens
```

### How to Compute

```bash
# Strip frontmatter, count bytes, divide by 4
strip_frontmatter() {
  awk 'NR==1 && /^---$/{skip=1;next} skip&&/^---$/{skip=0;next} !skip{print}' "$1"
}
tokens=$(strip_frontmatter "$wayfile" | wc -c | awk '{printf "%.0f", $1/4}')
```

### What to Flag

- **Per-way > 500 tokens**: Way may be too long, consider splitting
- **Path > 1500 tokens**: Path exceeds target, content may need trimming
- **Worst-case > 5000 tokens**: Tree is heavy, may crowd context on broad prompts
- **Single way dominates**: One way accounts for >40% of tree's total tokens

## Crowding Mode

Detect vocabulary overlap and semantic crowding across the entire ways corpus. This matters as the way count grows — at 50+ ways, BM25 vocabulary space gets contested.

### What to Report

```
=== Vocabulary Crowding Analysis ===
Prompt: "check the npm dependencies for vulnerabilities"

Score Clusters (ways within 20% of each other):
  Cluster 1: 4.23-5.01
    supplychain         4.87  threshold=1.8  MATCH
    supplychain/depscan 5.01  threshold=1.8  MATCH
    deps                4.23  threshold=2.0  MATCH
  → Assessment: Expected co-fire (supplychain tree + deps are complementary)

  Cluster 2: 1.80-2.10
    security            2.10  threshold=2.0  MATCH
    supplychain/node    1.80  threshold=2.5  no
  → Assessment: Security fires marginally. Node misses (good — prompt is generic npm, not node-specific)

Vocabulary Overlap (Jaccard > 0.15):
  deps ↔ supplychain/depscan     Jaccard=0.22  ⚠
  security ↔ supplychain         Jaccard=0.18  ⚠
  commits ↔ release              Jaccard=0.12  ✓

Top 10 most contested terms (appear in 3+ way vocabularies):
  "vulnerability"  in: security, supplychain, supplychain/depscan
  "dependency"     in: deps, supplychain/depscan, supplychain/automation
```

### What to Flag

- **Unhealthy clusters**: 3+ ways all MATCH with similar scores and serve overlapping purposes
- **High Jaccard pairs**: Sibling or unrelated ways with Jaccard > 0.25 → vocabulary collision
- **Contested terms**: Any term in 4+ vocabularies → may be too generic, consider removing from some

### How to Compute

1. Run `score-all` for the given prompt
2. Sort results by score, identify clusters within 20% of each other
3. For each pair of semantic ways, compute vocabulary Jaccard:
```bash
# For each pair of way.md files with vocabulary fields
# Split vocab into word sets, compute |A∩B| / |A∪B|
```
4. Count term frequency across all vocabularies

## Compare Mode

Side-by-side comparison of two way trees. Useful for evaluating whether a refactoring improved or degraded a tree.

### What to Report

```
=== Compare: supplychain vs testing ===

                    supplychain     testing
Depth               3               2
Total ways          9               3
Threshold range     1.8 - 2.5      1.8 - 2.5
Avg threshold       2.08            2.07
Worst-case tokens   ~3840           ~1100
Avg path tokens     ~940            ~680
Max sibling Jaccard 0.08            0.05
Has check.md        yes             no
Has macro.sh        yes (2)         no

Assessment: supplychain is deeper and broader (8 domain-specific leaves).
testing is compact (3 nodes). Both have clean threshold progression.
```

Present the comparison as a table, then an assessment noting which tree is more mature and whether the simpler tree has room to grow.

## Metrics Mode

Show tree disclosure metrics from the current session. The metrics file is written by `show-way.sh` at `/tmp/.claude-way-metrics-{session_id}.jsonl`.

### How to Read Metrics

```bash
# Find the session's metrics file
ls /tmp/.claude-way-metrics-*.jsonl 2>/dev/null

# Parse and display
cat /tmp/.claude-way-metrics-*.jsonl | jq -s .
```

### What to Report

```
=== Session Disclosure Metrics ===

Tree Coverage:
  softwaredev/code/security      root fired epoch 3
    → secrets                     fired epoch 5   (distance: 2)
    → injection                   fired epoch 8   (distance: 5)
    → auth                        not fired
    Coverage: 3/4 (75%)

  softwaredev/docs                root fired epoch 1
    → readme                      fired epoch 4   (distance: 3)
    → mermaid                     fired epoch 12  (distance: 11)
    → docstrings                  not fired
    → api                         not fired
    → standards                   not fired
    Coverage: 3/6 (50%)

Parent-Activated Threshold Lowering:
  injection scored 1.8 (below normal threshold 2.0)
    → Parent "security" was active → effective threshold 1.6 → MATCH
    Without parent: would have been a miss

Epoch Distance Distribution:
  Root-to-first-child: avg 3.2 epochs
  Root-to-deepest-child: avg 8.5 epochs
```

### What to Flag

- **Orphaned roots**: Root fires but no children ever fire → tree may be too deep or children too narrowly triggered
- **Instant cascades**: Parent and child fire at same epoch → vocabulary overlap between levels (they're not progressively disclosed, they're co-disclosed)
- **Never-fire children**: A child way that never fires across multiple sessions → vocabulary may be too narrow, consider lowering threshold or broadening vocabulary
- **Parent-only sessions**: Root fires but no children needed → the root was sufficient (this is fine, means progressive disclosure is working)

## Evaluation Guidelines

When presenting results, always include an **assessment** that interprets the numbers:

- **Clean win**: Target way is the clear top scorer with daylight to the next
- **Healthy co-fire**: Multiple ways fire but serve complementary roles (e.g., `deps` + `makefile` for "install npm dependencies")
- **Overlap concern**: Two ways compete at similar scores for the same prompt — may need vocabulary differentiation or threshold tuning
- **False negative**: Target way doesn't fire for a prompt it clearly should — vocabulary gap
- **False positive**: Way fires strongly for a prompt it shouldn't own — vocabulary too broad

## Notes

- The `way-match` binary must exist at `~/.claude/bin/way-match`. If missing, report that BM25 is unavailable and suggest building it.
- When displaying results, use human-readable format, not raw machine output.
- Check scoring uses `awk` for floating-point math.
