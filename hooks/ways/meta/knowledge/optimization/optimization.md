---
description: optimizing way vocabulary, tuning thresholds, reviewing matching quality, analyzing gaps and coverage
vocabulary: optimize vocabulary suggest gaps coverage unused threshold tune scoring health audit sparsity discrimination overlap
threshold: 2.0
macro: prepend
scope: agent
---
<!-- epistemic: heuristic -->
# Way Optimization

## Workflow

```
suggest → interpret → apply → test → verify
```

1. **Survey**: `/ways-tests suggest --all` (or `--all --summary` for overview)
2. **Interpret**: Gaps vs intentional unused (see below)
3. **Apply**: `/ways-tests suggest <way> --apply` (git-safe, shows diff)
4. **Test**: `/ways-tests score-all "<sample prompt>"` to verify discrimination
5. **Verify**: `make test-sim` for regression

## Reading Suggest Output

| Section | Meaning | Action |
|---------|---------|--------|
| **GAPS** | Body terms not in vocabulary (freq >= 2) | Add if the term catches user prompts |
| **COVERAGE** | Vocabulary terms found in body | Healthy — these are working |
| **UNUSED** | Vocabulary terms not in body | Often intentional — they catch *user* terms, not body terms |

**Don't blindly add all gaps.** Body text uses terms like "the", "code", "use" that don't discriminate between ways. Good vocabulary terms are *domain-specific* words users would say when asking about this topic.

**Don't remove unused terms.** Terms like `owasp`, `csrf`, `xss` in security vocabulary exist to catch user prompts, not because they appear in the way body.

## Sparsity and Discrimination

The goal isn't to maximize each way's score — it's to maximize the **semantic distance between ways**. Narrow, distinct vocabularies create sparsity: each way occupies its own region of the scoring space with minimal overlap. This means prompts activate exactly the right guidance, not a cluster of partially-relevant ways.

```bash
/ways-tests score-all "the ambiguous prompt"
```

Ideal outcome: one way scores well above threshold, others score well below. If two ways both match the same prompt, their semantic regions overlap — they need sharpening.

**Sharpening strategies:**
- Add discriminating terms unique to each way's domain
- Remove shared generic terms that don't differentiate
- Raise the threshold on the less-specific way
- Don't blindly expand vocabulary — more terms can *reduce* sparsity by creating new overlaps

## Which Ways Use Semantic Matching

Only ways with both `description:` and `vocabulary:` frontmatter fields use semantic matching. Ways with `match: regex`, `files:`, or `commands:` triggers don't need vocabulary optimization — they match on patterns.

## Thresholds

- **Embedding threshold** (frontmatter `embed_threshold:`): Cosine similarity, 0–1 scale. Default set per-way in corpus.
- **BM25 threshold** (frontmatter `threshold:`): Score scale, higher = better match. Default 2.0. Range typically 1.5-5.0.

Lowering BM25 threshold increases recall (more matches) but risks false positives. The test harness tracks FP rate — **0 FP is the hard constraint**.

### Auto-tuning with `ways tune`

Don't hand-tune embed thresholds. The tuner computes optimal values from corpus similarity data:

```bash
ways tune              # preview (dry run)
ways tune --apply      # write tuned thresholds
ways tune --way "ea/"  # tune a subset
ways corpus            # recompile after tuning
```

For locale stubs in `.locales.jsonl`, the tuner writes `embed_threshold` per entry. For English ways, thresholds stay in frontmatter.

### Discrimination audit

Two dimensions to optimize:
- **Discrimination** (gap): how clearly the description identifies *this* way vs others. Wide gap = precise. Narrow gap = ambiguous.
- **Sensitivity** (threshold): how much signal required before firing. Auto-computed from discrimination.

```bash
ways tune --audit                    # flag entries with gap < 0.15
ways tune --audit --audit-threshold 0.20  # stricter
```

The audit names the **confusers** — which ways the description is being confused with. Low discrimination means revising the description, not adjusting the threshold.

## Health Indicators

- **Gap ratio**: gaps / (gaps + coverage). High ratio = vocabulary may be too narrow.
- **Unused ratio**: unused / total vocabulary. High ratio isn't bad — unused terms serve user-facing matching.
- **0 FP**: The test harness must maintain zero false positives. Accuracy can vary but FP cannot.

Stop when vocabulary changes stop changing test outcomes.
