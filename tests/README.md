# Testing

Tests live here and in the tools they validate. This page covers all test types across the project.

```bash
# Run all automated tests from one place
tests/run-all.sh
```

## Way Matching Tests

Three layers, from fast/automated to slow/interactive. See [way-match/results.md](way-match/results.md) for typical output with BM25 vs NCD comparison and interpretation.

### 1. Fixture Tests (BM25 vs NCD scorer comparison)

Runs 54 test prompts against a fixed 18-way corpus (all softwaredev ways with BM25 semantic matching). Compares BM25 binary against gzip NCD baseline. Reports TP/FP/TN/FN for each scorer.

```bash
tests/way-match/run-tests.sh fixture --verbose
# or directly:
bash tools/way-match/test-harness.sh --verbose
```

Options: `--bm25-only`, `--ncd-only`, `--verbose`

**What it covers**: Scorer accuracy, false positive rate, head-to-head comparison. Tests direct vocabulary matches, synonym/paraphrase variants, and negative controls.

**Current baseline**: BM25 48/54, 0 FP.

### 2. Integration Tests (real way files)

Scores 31 test prompts against actual `way.md` files extracted from the live ways directory. Tests the real frontmatter extraction pipeline.

```bash
tests/way-match/run-tests.sh integration
# or directly:
bash tools/way-match/test-integration.sh
```

**What it covers**: End-to-end scoring with real way vocabulary, multi-way discrimination (does the right way win?), threshold behavior with actual threshold values.

**Current baseline**: BM25 27/31 (0 FP), NCD 15/31 (3 FP).

### 3. Activation Test (live agent + subagent)

Interactive test protocol that verifies the full hook pipeline in a running Claude Code session. Tests regex matching, BM25 semantic matching (established and newly-added vocabularies), co-activation of related ways, negative controls, and subagent injection.

**To run**: Start a fresh session from `~/.claude/` and type:

```
read and run the activation test at tests/way-activation-test.md
```

Claude reads the test file (avoiding prompt-hook contamination), then walks you through 9 steps:

| Step | Who | Tests |
|------|-----|-------|
| 1 | Claude | Session baseline (no premature domain activation) |
| 2 | User types prompt | Regex pattern matching (delivery/commits) |
| 3 | User types prompt | BM25 semantic matching, established way (code/security) |
| 4 | User types prompt | BM25 semantic matching, newly-semantic way (code/performance) |
| 5 | User types prompt | Co-activation of multiple related ways (delivery/migrations + others) |
| 6 | User types prompt | Negative control (no false positives) |
| 7 | Claude | Subagent injection (Testing Way via SubagentStart) |
| 8 | Claude | Subagent negative (no fresh injection; parent context OK) |
| 9 | Claude | Summary table |

Takes about 5 minutes. **Current baseline**: 8/8 PASS (steps 1-8).

### Ad-Hoc Vocabulary Testing

The `/test-way` skill scores a prompt against all semantic ways and reports BM25 scores. Use it during vocabulary tuning to check discrimination between ways.

```
/test-way "write some unit tests for this module"
```

## Documentation Tests

### Doc-Graph (link integrity)

Builds a link graph from all git-tracked markdown files. Finds dead ends, orphans, and broken internal links.

```bash
bash scripts/doc-graph.sh --stats     # broken links, orphans, dead ends
bash scripts/doc-graph.sh --mermaid   # Mermaid diagram of link graph
bash scripts/doc-graph.sh --json      # JSON adjacency list
bash scripts/doc-graph.sh --all       # all outputs
```

**What it covers**: Every internal markdown link resolves to a real file. No orphaned docs (unreachable from any other doc). No dead ends (docs with no outgoing links to the rest of the tree).

### Governance Provenance Verification

Validates that provenance metadata in way frontmatter is structurally sound: policy URIs point to real files, verified dates aren't stale, controls have justifications.

```bash
bash governance/provenance-verify.sh         # human-readable report
bash governance/provenance-verify.sh --json  # machine-readable
bash governance/governance.sh --lint         # full governance lint
```

**What it covers**: Provenance chain integrity — every `policy.uri` in way frontmatter resolves, every control has justifications, verified dates are within staleness window.

## When to Run Which

| Scenario | Test |
|----------|------|
| Changed `way-match.c` or rebuilt binary | Fixture tests + integration tests |
| Changed a way's vocabulary or threshold | Integration tests + `/test-way` |
| Changed hook scripts (check-*.sh, inject-*.sh, match-way.sh) | Activation test |
| Added a new way | Integration tests + `/test-way` + activation test |
| Restructured way directories | All three test layers + symlink/path verification |
| Added semantic matching to a way | Fixture tests + integration tests + activation test (step 4) |
| Renamed or moved documentation files | Doc-graph |
| Changed provenance metadata in way frontmatter | Governance verification |
| Changed policy source documents | Governance verification |
| Sanity check after merge | All of the above |
