---
description: auto-tuning locale thresholds, discrimination audit, fixing ambiguous descriptions, ways tune workflow
vocabulary: tune tuning threshold auto-tune discrimination audit confuser ambiguous gap signal noise sensitivity locales
threshold: 2.5
scope: agent
---
<!-- epistemic: convention -->
# Threshold Tuning and Discrimination Audit

## The Two Dimensions

**Discrimination** — how clearly a description separates *this* way from every other way. Measured as the gap between self-match score and best non-self score. Wide gap = the description precisely identifies this way. Narrow gap = the description is ambiguous.

**Sensitivity** — the `embed_threshold` that controls what scores pass. Auto-computed from discrimination data. Don't hand-tune.

Low discrimination cannot be fixed by threshold adjustment. If the description looks like three other ways, no threshold gives you both correct matches and zero false positives. The fix is revising the description.

## Workflow

```
ways tune              → preview optimal thresholds (dry run)
ways tune --apply      → write thresholds to .locales.jsonl
ways corpus            → recompile corpus with new thresholds
ways tune --audit      → flag ambiguous descriptions
```

### Tuning

```bash
# Full corpus — parallel, ~13s on 32 cores
ways tune

# Single way
ways tune --way "security"

# Apply (writes embed_threshold to .locales.jsonl files)
ways tune --apply

# Must recompile after applying
ways corpus
```

The tuner sets threshold = best_non_self_score + margin (default 0.03). This guarantees zero false positives while maximizing recall.

### Auditing

```bash
# Flag entries with gap < 0.15
ways tune --audit

# Stricter
ways tune --audit --audit-threshold 0.20

# Machine-readable
ways tune --audit --json
```

Output shows the **confusers** — which ways each ambiguous entry is confused with:

```
softwaredev/docs/mermaid
  ar — gap 0.07  (self 1.00, noise 0.93)  confused with: softwaredev/visualization/diagrams (0.93)
```

This tells you: the Arabic mermaid description is nearly identical to the diagrams way. Revise the vocabulary to distinguish them.

### Fixing Ambiguous Descriptions

When the audit flags an entry:

1. Read the confuser — understand *why* they overlap (shared vocabulary? similar concepts?)
2. Revise the description to emphasize what's *unique* to this way
3. Revise vocabulary to include terms that discriminate, remove terms shared with the confuser
4. Re-run `ways corpus && ways tune --audit` to verify the gap improved

Common confuser patterns:
- **Parent/child overlap** (e.g., `architecture` ↔ `architecture/design`) — child should use narrower, more specific terms
- **Synonym overlap** (e.g., `mermaid` ↔ `diagrams`) — one emphasizes the tool, the other the output format
- **Cross-domain overlap** (e.g., `adr-context` ↔ `implement`) — one is about *deciding*, the other about *executing*

## See Also

- knowledge/optimization(meta) — vocabulary tuning, sparsity, discrimination
- knowledge/authoring(meta) — way file format, creating new ways
