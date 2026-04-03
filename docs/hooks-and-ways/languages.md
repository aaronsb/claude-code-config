# Multi-Language Support

Ways supports multilingual matching and output across 52 languages. The system uses two embedding models: a precise English model and a broad multilingual model, routed automatically by the corpus builder.

## Setting output language

The agent writes commit messages, comments, and documentation in the configured language. Resolution order:

1. **`ways.json`** `output_language` field — explicit override
2. **Claude Code** `settings.json` `language` field — agent config (project then user)
3. **System locale** (`$LC_ALL` → `$LC_MESSAGES` → `$LANG`)
4. **Default**: `en`

```json
// ways.json — explicit override
{"disabled": [], "output_language": "ja"}
```

```json
// Claude Code settings.json — agent-level
{"language": "japanese"}
```

Setting `output_language: "auto"` skips the override and cascades to Claude Code settings → system locale.

The output language directive is injected via `core.md` at session start. Way content (the guidance text) stays English — the agent reads it fine in any language. Only the file output changes.

## How matching works across languages

Two embedding models handle different matching scenarios:

| Model | File | Size | Languages | Use case |
|-------|------|------|-----------|----------|
| all-MiniLM-L6-v2 | `minilm-l6-v2.gguf` | 21MB | English | Precise EN matching (default) |
| paraphrase-multilingual-MiniLM-L12-v2 | `multilingual-minilm-l12-v2-q8.gguf` | 127MB | 52 | Cross-language and same-language matching |

Both are downloaded by `make setup` and stored in `~/.cache/claude-ways/user/`.

Model routing is automatic — no frontmatter field needed:

- **`.md` ways** → English model (all-MiniLM-L6-v2)
- **`.locales.jsonl` entries** → multilingual model (paraphrase-multilingual-MiniLM-L12-v2)

The corpus builder splits entries into `ways-corpus-en.jsonl` and `ways-corpus-multi.jsonl`, each embedded with the appropriate model.

## Locale stubs — packed format

Locale stubs provide native-language matching vocabulary for existing ways. They're stored as **packed JSONL**, one file per way, co-located with the way they belong to:

```
hooks/ways/softwaredev/code/security/
  security.md                # English way — full body + frontmatter
  security.locales.jsonl     # all language stubs (one line per language)
```

Each line in the `.locales.jsonl` is a self-contained locale entry:

```jsonl
{"lang":"ja","description":"セキュリティ脆弱性スキャンと監査","vocabulary":"セキュリティ 脆弱性 CVE 監査","embed_threshold":0.74}
{"lang":"de","description":"Sicherheitsüberblick, sichere Programmierstandards","vocabulary":"Sicherheit Schwachstelle schützen OWASP","embed_threshold":0.79}
{"lang":"es","description":"Seguridad general, codificación segura","vocabulary":"seguridad vulnerable defensa OWASP","embed_threshold":0.78}
{"lang":"ar","description":"نظرة عامة على الأمان والبرمجة الآمنة","vocabulary":"أمان برمجة آمنة حماية ثغرات","embed_threshold":0.84}
```

When a Japanese user types a prompt, the scanner:
1. Scores the Japanese stub's description using the multilingual model
2. Injects `security.md`'s English body (the guidance text)

### Format rules

- **`embed_threshold`** is optional — omit it and the corpus generator defaults to 0.25. Use `ways tune --apply` to compute optimal values automatically.
- **Model routing** is automatic — locale stubs always use the multilingual model (not stored in the file).
- **No body content** — just the JSONL line. If someone writes a full native-language way, they create `security.ja.md` as a regular file, which overrides the packed entry.

### Override mechanism

If `security.ja.md` exists as a real file alongside `security.locales.jsonl`, the `.md` file wins for Japanese. This lets authors graduate a stub into a full native-language way with body content, without touching the packed file.

### Why same-language stubs matter

Cross-language matching (Japanese prompt → English description) scores ~0.69. Same-language matching (Japanese prompt → Japanese description) scores ~0.93. The native stub dramatically improves matching precision.

| Scenario | Cosine similarity |
|----------|----------------:|
| EN prompt → EN description (baseline) | 0.76 |
| JA prompt → EN description (cross-language) | 0.69 |
| JA prompt → JA description (same-language stub) | 0.93 |

See `docs/architecture/system/multilingual-model-evaluation.md` for full test results.

## Tuning and auditing

### Auto-tuning thresholds

`ways tune` computes the optimal `embed_threshold` for each locale entry by scoring it against the full corpus and finding the discrimination boundary:

```bash
# Preview what would change (dry run)
ways tune

# Tune a specific way
ways tune --way security

# Apply tuned thresholds to .locales.jsonl files
ways tune --apply

# Regenerate corpus with tuned values
ways corpus
```

The tuner runs in parallel (all cores minus 4). ~13 seconds for 328 entries on a 32-core machine.

### Discrimination audit

`ways tune --audit` flags entries where the description doesn't clearly separate this way from others — no threshold can fix an ambiguous description:

```bash
# Flag entries with discrimination gap < 0.15
ways tune --audit

# Adjust the gap threshold
ways tune --audit --audit-threshold 0.20
```

The audit shows **confusers** — which ways the ambiguous entry is being confused with:

```
softwaredev/docs/mermaid
  ar — gap 0.07  (self 1.00, noise 0.93)  confused with: softwaredev/visualization/diagrams (0.93)
```

This tells the author: "your Arabic mermaid description looks too similar to the diagrams way — revise the vocabulary to distinguish them."

### Full authoring cycle

```
write stubs → compile → tune → audit → revise → repeat
```

1. Write/generate locale entries in `.locales.jsonl`
2. `ways corpus` — compile into embeddings
3. `ways tune --apply` — auto-set thresholds
4. `ways tune --audit` — flag ambiguous descriptions
5. Revise flagged descriptions, go to step 2

Two dimensions to optimize:
- **Discrimination** (gap): how clearly the description identifies this way vs others. Property of description quality.
- **Sensitivity** (threshold): how much signal required before firing. Auto-tuned from discrimination data.

## Supported languages

Languages are defined in `tools/ways-cli/languages.json`. Each entry specifies:

- **`name`** / **`native`** — display names for normalization
- **`bm25_stemmer`** — Snowball stemmer algorithm name, or `"impossible"` if BM25 cannot support this language

### BM25 feasibility

BM25 is the fallback matching engine when the embedding model is unavailable. It works for languages with whitespace word boundaries and suffix-stripping morphology:

**BM25 works**: Danish, Dutch, English, Finnish, French, German, Greek, Hungarian, Italian, Norwegian, Portuguese, Romanian, Russian, Spanish, Swedish, Turkish

**BM25 impossible**: Arabic, Burmese, Chinese, Georgian, Gujarati, Hebrew, Hindi, Japanese, Korean, Marathi, Mongolian, Thai, Urdu, Vietnamese — and others marked `"impossible"` in `languages.json`

For "impossible" languages, the embedding engine is required — not optional. Without it, only keyword/regex patterns fire.

## Checking language status

```bash
# Language coverage report
ways language

# Filter to a specific language
ways language --filter ja

# Machine-readable
ways language --json

# Engine status with corpus breakdown
ways status
```

`ways status` warns if multilingual ways exist in the corpus but the multilingual model is missing.

## Architecture decisions

- **ADR-107**: Full design rationale — language cascade, dual model approach, matching tiers
- **Evaluation report**: `docs/architecture/system/multilingual-model-evaluation.md` — test data across 11 languages × 3 domains
