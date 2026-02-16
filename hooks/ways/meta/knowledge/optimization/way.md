---
description: optimizing way vocabulary, tuning thresholds, reviewing matching quality, analyzing gaps and coverage
vocabulary: optimize vocabulary suggest gaps coverage unused threshold tune scoring health audit sparsity discrimination overlap
threshold: 2.0
macro: prepend
scope: agent
provenance:
  policy:
    - uri: docs/hooks-and-ways/extending.md
      type: governance-doc
  controls:
    - id: ISO 9001:2015 10.2 (Improvement)
      justifications:
        - Systematic vocabulary analysis ensures ways fire accurately
        - Gap/coverage metrics provide evidence-based improvement decisions
  verified: 2026-02-16
  rationale: >
    Optimization workflow for tuning way vocabulary and matching quality.
    Fires when discussing way improvement, not general authoring.
---
# Way Optimization

## Workflow

```
suggest → interpret → apply → test → verify
```

1. **Survey**: `/test-way suggest --all` (or `--all --summary` for overview)
2. **Interpret**: Gaps vs intentional unused (see below)
3. **Apply**: `/test-way suggest <way> --apply` (git-safe, shows diff)
4. **Test**: `/test-way score-all "<sample prompt>"` to verify discrimination
5. **Verify**: `bash tools/way-match/test-harness.sh --bm25-only` for regression

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
/test-way score-all "the ambiguous prompt"
```

Ideal outcome: one way scores well above threshold, others score well below. If two ways both match the same prompt, their semantic regions overlap — they need sharpening.

**Sharpening strategies:**
- Add discriminating terms unique to each way's domain
- Remove shared generic terms that don't differentiate
- Raise the threshold on the less-specific way
- Don't blindly expand vocabulary — more terms can *reduce* sparsity by creating new overlaps

## Which Ways Use Semantic Matching

Only ways with both `description:` and `vocabulary:` frontmatter fields use BM25/NCD semantic matching. Ways with `match: regex`, `files:`, or `commands:` triggers don't need vocabulary optimization — they match on patterns.

## Thresholds

- **BM25 threshold** (frontmatter `threshold:`): Score scale, higher = better match. Default 2.0. Range typically 1.5-5.0.
- **NCD threshold** (hardcoded 0.58 in check-prompt.sh): Distance scale, lower = more similar. Not tunable per-way — it's a fallback for when the BM25 binary isn't available.

Lowering BM25 threshold increases recall (more matches) but risks false positives. The test harness tracks FP rate — **0 FP is the hard constraint**.

## Health Indicators

- **Gap ratio**: gaps / (gaps + coverage). High ratio = vocabulary may be too narrow.
- **Unused ratio**: unused / total vocabulary. High ratio isn't bad — unused terms serve user-facing matching.
- **0 FP**: The test harness must maintain zero false positives. Accuracy can vary but FP cannot.

Stop when vocabulary changes stop changing test outcomes.
