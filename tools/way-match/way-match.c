/*
 * way-match: BM25 semantic matcher for the ways system
 *
 * A lightweight text similarity tool that scores user prompts against
 * way descriptions using the Okapi BM25 ranking function.
 *
 * Two modes:
 *   pair  - score one description+vocabulary against a query (exit 0/1)
 *   score - score a JSONL corpus against a query (ranked output)
 *
 * Build: cosmocc -O2 -o way-match way-match.c
 * See: ADR-014 (docs/adr/ADR-014-tfidf-semantic-matcher.md)
 */

#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define VERSION "0.1.0"
#define MAX_TOKENS    4096
#define MAX_TOKEN_LEN 128
#define MAX_DOCS      256
#define MAX_LINE      8192

/* ========================================================================
 * Stopwords — same list as semantic-match.sh
 * ======================================================================== */

static const char *STOPWORDS[] = {
    "the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
    "have", "has", "had", "do", "does", "did", "will", "would", "could",
    "should", "may", "might", "must", "shall", "can", "this", "that",
    "these", "those", "it", "its", "what", "how", "why", "when", "where",
    "who", "let", "lets", "just", "to", "for", "of", "in", "on", "at",
    "by", "and", "or", "but", "not", "with", "from", "into", "about",
    "than", "then", "so", "if", "up", "out", "no", "yes", "all", "some",
    "any", "each", "my", "your", "our", "me", "we", "you", "i",
    NULL
};

static int is_stopword(const char *word) {
    for (int i = 0; STOPWORDS[i]; i++) {
        if (strcmp(word, STOPWORDS[i]) == 0) return 1;
    }
    return 0;
}

/* ========================================================================
 * Tokenizer — whitespace + punctuation split, lowercase
 * ======================================================================== */

typedef struct {
    char tokens[MAX_TOKENS][MAX_TOKEN_LEN];
    int count;
} TokenList;

static void tokenize(const char *text, TokenList *out) {
    out->count = 0;
    int i = 0, len = strlen(text);

    while (i < len && out->count < MAX_TOKENS) {
        /* skip non-alpha */
        while (i < len && !isalpha((unsigned char)text[i])) i++;
        if (i >= len) break;

        /* collect alpha characters */
        int start = i;
        char token[MAX_TOKEN_LEN];
        int t = 0;
        while (i < len && isalpha((unsigned char)text[i]) && t < MAX_TOKEN_LEN - 1) {
            token[t++] = tolower((unsigned char)text[i]);
            i++;
        }
        token[t] = '\0';

        /* skip short words and stopwords */
        if (t < 3) continue;
        if (is_stopword(token)) continue;

        strcpy(out->tokens[out->count], token);
        out->count++;
    }
}

/* ========================================================================
 * Term frequency — count occurrences of each unique term
 * ======================================================================== */

typedef struct {
    char term[MAX_TOKEN_LEN];
    int count;
} TermFreq;

typedef struct {
    TermFreq entries[MAX_TOKENS];
    int count;
    int total_tokens; /* total tokens before dedup (document length) */
} TermFreqMap;

static void build_tf(const TokenList *tokens, TermFreqMap *tf) {
    tf->count = 0;
    tf->total_tokens = tokens->count;

    for (int i = 0; i < tokens->count; i++) {
        /* search existing entries */
        int found = 0;
        for (int j = 0; j < tf->count; j++) {
            if (strcmp(tf->entries[j].term, tokens->tokens[i]) == 0) {
                tf->entries[j].count++;
                found = 1;
                break;
            }
        }
        if (!found && tf->count < MAX_TOKENS) {
            strcpy(tf->entries[tf->count].term, tokens->tokens[i]);
            tf->entries[tf->count].count = 1;
            tf->count++;
        }
    }
}

static int tf_get(const TermFreqMap *tf, const char *term) {
    for (int i = 0; i < tf->count; i++) {
        if (strcmp(tf->entries[i].term, term) == 0)
            return tf->entries[i].count;
    }
    return 0;
}

/* ========================================================================
 * BM25 scorer
 *
 * BM25(q, d) = sum over query terms t:
 *   IDF(t) * (tf(t,d) * (k1 + 1)) / (tf(t,d) + k1 * (1 - b + b * |d|/avgdl))
 *
 * IDF(t) = ln((N - df(t) + 0.5) / (df(t) + 0.5) + 1)
 *   where N = number of documents, df(t) = docs containing term t
 * ======================================================================== */

typedef struct {
    char id[256];
    char description[MAX_LINE];
    char vocabulary[MAX_LINE];
    double threshold;
    TermFreqMap tf;
} Document;

typedef struct {
    Document docs[MAX_DOCS];
    int count;
    double avg_dl; /* average document length */
} Corpus;

static double bm25_k1 = 1.2;
static double bm25_b  = 0.75;

/* Count how many documents contain a given term */
static int doc_freq(const Corpus *corpus, const char *term) {
    int df = 0;
    for (int i = 0; i < corpus->count; i++) {
        if (tf_get(&corpus->docs[i].tf, term) > 0) df++;
    }
    return df;
}

/* Score a single document against a query */
static double bm25_score(const Corpus *corpus, const Document *doc,
                         const TokenList *query) {
    double score = 0.0;
    int N = corpus->count;
    double dl = doc->tf.total_tokens;
    double avgdl = corpus->avg_dl;

    for (int i = 0; i < query->count; i++) {
        const char *term = query->tokens[i];
        int tf = tf_get(&doc->tf, term);
        if (tf == 0) continue;

        int df = doc_freq(corpus, term);

        /* IDF with floor of 0 to avoid negative values for very common terms */
        double idf = log(((double)(N - df) + 0.5) / ((double)df + 0.5) + 1.0);
        if (idf < 0.0) idf = 0.0;

        /* BM25 TF component */
        double tf_norm = ((double)tf * (bm25_k1 + 1.0)) /
                         ((double)tf + bm25_k1 * (1.0 - bm25_b + bm25_b * dl / avgdl));

        score += idf * tf_norm;
    }

    return score;
}

/* ========================================================================
 * Corpus building — from arguments or JSONL file
 * ======================================================================== */

static void index_document(Document *doc) {
    /* Combine description and vocabulary into one token stream */
    char combined[MAX_LINE * 2];
    snprintf(combined, sizeof(combined), "%s %s", doc->description, doc->vocabulary);

    TokenList tokens;
    tokenize(combined, &tokens);
    build_tf(&tokens, &doc->tf);
}

static void compute_avg_dl(Corpus *corpus) {
    double total = 0;
    for (int i = 0; i < corpus->count; i++) {
        total += corpus->docs[i].tf.total_tokens;
    }
    corpus->avg_dl = corpus->count > 0 ? total / corpus->count : 1.0;
}

/* ========================================================================
 * JSONL corpus loading
 *
 * Minimal JSON parsing — expects one object per line with string fields:
 *   {"id":"...", "description":"...", "vocabulary":"...", "threshold":N.N}
 * ======================================================================== */

/* Extract a string value for a given key from a JSON line */
static int json_get_string(const char *json, const char *key, char *out, int maxlen) {
    char pattern[256];
    snprintf(pattern, sizeof(pattern), "\"%s\"", key);
    const char *p = strstr(json, pattern);
    if (!p) return 0;

    p += strlen(pattern);
    /* skip whitespace and colon */
    while (*p && (*p == ' ' || *p == ':' || *p == '\t')) p++;
    if (*p != '"') return 0;
    p++; /* skip opening quote */

    int i = 0;
    while (*p && *p != '"' && i < maxlen - 1) {
        if (*p == '\\' && *(p + 1)) {
            p++; /* skip escape */
        }
        out[i++] = *p++;
    }
    out[i] = '\0';
    return 1;
}

static double json_get_number(const char *json, const char *key, double def) {
    char pattern[256];
    snprintf(pattern, sizeof(pattern), "\"%s\"", key);
    const char *p = strstr(json, pattern);
    if (!p) return def;

    p += strlen(pattern);
    while (*p && (*p == ' ' || *p == ':' || *p == '\t')) p++;

    char buf[64];
    int i = 0;
    while (*p && (isdigit((unsigned char)*p) || *p == '.' || *p == '-') && i < 63) {
        buf[i++] = *p++;
    }
    buf[i] = '\0';
    return i > 0 ? atof(buf) : def;
}

static int load_corpus_jsonl(const char *path, Corpus *corpus) {
    FILE *f = fopen(path, "r");
    if (!f) {
        fprintf(stderr, "error: cannot open corpus file: %s\n", path);
        return -1;
    }

    char line[MAX_LINE];
    while (fgets(line, sizeof(line), f) && corpus->count < MAX_DOCS) {
        Document *doc = &corpus->docs[corpus->count];

        if (!json_get_string(line, "id", doc->id, sizeof(doc->id))) continue;
        if (!json_get_string(line, "description", doc->description, sizeof(doc->description))) continue;
        json_get_string(line, "vocabulary", doc->vocabulary, sizeof(doc->vocabulary));
        doc->threshold = json_get_number(line, "threshold", 0.4);

        index_document(doc);
        corpus->count++;
    }

    fclose(f);
    compute_avg_dl(corpus);
    return 0;
}

/* ========================================================================
 * Pair mode — single description+vocabulary vs query
 * ======================================================================== */

/* Built-in corpus for IDF computation in pair mode.
 * These are the 7 semantic ways — enough for meaningful IDF without
 * requiring a corpus file. Pair mode adds the target as an additional
 * document if it's not already one of these. */
static const struct { const char *id; const char *desc; const char *vocab; } BUILTIN_WAYS[] = {
    {"testing",     "writing unit tests, test coverage, mocking dependencies, test-driven development",
                    "unittest coverage mock tdd assertion jest pytest rspec testcase"},
    {"api",         "designing REST APIs, HTTP endpoints, API versioning, request response structure",
                    "endpoint api rest route http status pagination versioning"},
    {"debugging",   "debugging code issues, troubleshooting errors, investigating broken behavior, fixing bugs",
                    "debug breakpoint stacktrace investigate troubleshoot regression bisect"},
    {"security",    "application security, authentication, secrets management, input validation, vulnerability prevention",
                    "authentication secrets password credentials owasp injection xss sql sanitize vulnerability"},
    {"design",      "software system design architecture patterns database schema component modeling",
                    "architecture pattern database schema modeling interface component modules factory observer strategy"},
    {"config",      "application configuration, environment variables, dotenv files, config file management",
                    "dotenv environment configuration envvar config.json config.yaml"},
    {"adr-context", "planning how to implement a feature, deciding an approach, understanding existing project decisions, starting work on an item, investigating why something was built a certain way",
                    "plan approach debate implement build work pick understand investigate why how decision context"},
    {NULL, NULL, NULL}
};

static int cmd_pair(const char *description, const char *vocabulary,
                    const char *query, double threshold) {
    Corpus *corpus = calloc(1, sizeof(Corpus));
    if (!corpus) { fprintf(stderr, "error: out of memory\n"); return 1; }

    /* Load built-in ways as corpus for IDF computation */
    for (int i = 0; BUILTIN_WAYS[i].id; i++) {
        Document *doc = &corpus->docs[corpus->count];
        snprintf(doc->id, sizeof(doc->id), "%s", BUILTIN_WAYS[i].id);
        strncpy(doc->description, BUILTIN_WAYS[i].desc, sizeof(doc->description) - 1);
        strncpy(doc->vocabulary, BUILTIN_WAYS[i].vocab, sizeof(doc->vocabulary) - 1);
        index_document(doc);
        corpus->count++;
    }

    /* Find or add the target document */
    int target_idx = -1;
    for (int i = 0; i < corpus->count; i++) {
        if (strcmp(corpus->docs[i].description, description) == 0) {
            target_idx = i;
            break;
        }
    }
    if (target_idx < 0 && corpus->count < MAX_DOCS) {
        target_idx = corpus->count;
        Document *doc = &corpus->docs[corpus->count];
        snprintf(doc->id, sizeof(doc->id), "target");
        strncpy(doc->description, description, sizeof(doc->description) - 1);
        strncpy(doc->vocabulary, vocabulary, sizeof(doc->vocabulary) - 1);
        index_document(doc);
        corpus->count++;
    }

    compute_avg_dl(corpus);

    /* Tokenize query and score with full BM25 */
    TokenList *qtokens = calloc(1, sizeof(TokenList));
    if (!qtokens) { free(corpus); return 1; }
    tokenize(query, qtokens);

    double score = bm25_score(corpus, &corpus->docs[target_idx], qtokens);

    fprintf(stderr, "match: score=%.4f threshold=%.4f\n", score, threshold);

    int result = score >= threshold ? 0 : 1;
    free(qtokens);
    free(corpus);
    return result;
}

/* ========================================================================
 * Score mode — batch scoring against JSONL corpus
 * ======================================================================== */

typedef struct {
    int index;
    double score;
} ScoredDoc;

static int cmp_scored_desc(const void *a, const void *b) {
    double sa = ((const ScoredDoc *)a)->score;
    double sb = ((const ScoredDoc *)b)->score;
    if (sb > sa) return 1;
    if (sb < sa) return -1;
    return 0;
}

static int cmd_score(const char *corpus_path, const char *query, double threshold) {
    Corpus *corpus = calloc(1, sizeof(Corpus));
    if (!corpus) { fprintf(stderr, "error: out of memory\n"); return 1; }

    if (load_corpus_jsonl(corpus_path, corpus) != 0) { free(corpus); return 1; }

    if (corpus->count == 0) {
        fprintf(stderr, "error: empty corpus\n");
        free(corpus);
        return 1;
    }

    TokenList *qtokens = calloc(1, sizeof(TokenList));
    if (!qtokens) { free(corpus); return 1; }
    tokenize(query, qtokens);

    /* Score all documents */
    ScoredDoc scored[MAX_DOCS];
    for (int i = 0; i < corpus->count; i++) {
        scored[i].index = i;
        scored[i].score = bm25_score(corpus, &corpus->docs[i], qtokens);
    }

    /* Sort descending by score */
    qsort(scored, corpus->count, sizeof(ScoredDoc), cmp_scored_desc);

    /* Output matches above threshold */
    int printed = 0;
    for (int i = 0; i < corpus->count; i++) {
        Document *doc = &corpus->docs[scored[i].index];
        double doc_thresh = doc->threshold > 0 ? doc->threshold : threshold;

        if (scored[i].score >= doc_thresh) {
            /* Truncate description for display */
            char snippet[60];
            strncpy(snippet, doc->description, 56);
            snippet[56] = '\0';
            if (strlen(doc->description) > 56) strcat(snippet, "...");

            printf("%s\t%.4f\t%s\n", doc->id, scored[i].score, snippet);
            printed++;
        }
    }

    free(qtokens);
    free(corpus);

    if (printed == 0) {
        fprintf(stderr, "no matches above threshold\n");
        return 1;
    }

    return 0;
}

/* ========================================================================
 * Usage and main
 * ======================================================================== */

static void usage(void) {
    fprintf(stderr,
        "way-match %s — BM25 semantic matcher for the ways system\n"
        "\n"
        "Usage:\n"
        "  way-match pair  --description DESC --vocabulary VOCAB --query Q [--threshold T]\n"
        "  way-match score --corpus FILE --query Q [--threshold T]\n"
        "\n"
        "Pair mode:\n"
        "  Score a single description+vocabulary against a query.\n"
        "  Exit 0 if match (score >= threshold), 1 if no match.\n"
        "  Drop-in replacement for semantic-match.sh.\n"
        "\n"
        "Score mode:\n"
        "  Score all documents in a JSONL corpus against a query.\n"
        "  Output: id<TAB>score<TAB>description (ranked, above threshold only)\n"
        "\n"
        "Options:\n"
        "  --description  Way description text\n"
        "  --vocabulary   Space-separated domain keywords\n"
        "  --query        User prompt to match against\n"
        "  --corpus       Path to JSONL corpus file\n"
        "  --threshold    Minimum score to match (default: 0.4)\n"
        "  --k1           BM25 k1 parameter (default: 1.2)\n"
        "  --b            BM25 b parameter (default: 0.75)\n"
        "  --version      Show version\n"
        "  --help         Show this help\n"
        , VERSION);
}

static const char *get_arg(int argc, char **argv, int i) {
    if (i + 1 >= argc) {
        fprintf(stderr, "error: %s requires a value\n", argv[i]);
        exit(1);
    }
    return argv[i + 1];
}

int main(int argc, char **argv) {
    if (argc < 2) {
        usage();
        return 1;
    }

    /* Check for --version or --help first */
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--version") == 0) {
            printf("way-match %s\n", VERSION);
            return 0;
        }
        if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            usage();
            return 0;
        }
    }

    const char *command = argv[1];
    const char *description = NULL;
    const char *vocabulary = "";
    const char *query = NULL;
    const char *corpus_path = NULL;
    double threshold = 0.4;

    /* Parse arguments */
    for (int i = 2; i < argc; i++) {
        if (strcmp(argv[i], "--description") == 0) {
            description = get_arg(argc, argv, i); i++;
        } else if (strcmp(argv[i], "--vocabulary") == 0) {
            vocabulary = get_arg(argc, argv, i); i++;
        } else if (strcmp(argv[i], "--query") == 0) {
            query = get_arg(argc, argv, i); i++;
        } else if (strcmp(argv[i], "--corpus") == 0) {
            corpus_path = get_arg(argc, argv, i); i++;
        } else if (strcmp(argv[i], "--threshold") == 0) {
            threshold = atof(get_arg(argc, argv, i)); i++;
        } else if (strcmp(argv[i], "--k1") == 0) {
            bm25_k1 = atof(get_arg(argc, argv, i)); i++;
        } else if (strcmp(argv[i], "--b") == 0) {
            bm25_b = atof(get_arg(argc, argv, i)); i++;
        } else {
            fprintf(stderr, "error: unknown option: %s\n", argv[i]);
            return 1;
        }
    }

    /* Dispatch */
    if (strcmp(command, "pair") == 0) {
        if (!description || !query) {
            fprintf(stderr, "error: pair mode requires --description and --query\n");
            return 1;
        }
        return cmd_pair(description, vocabulary, query, threshold);

    } else if (strcmp(command, "score") == 0) {
        if (!corpus_path || !query) {
            fprintf(stderr, "error: score mode requires --corpus and --query\n");
            return 1;
        }
        return cmd_score(corpus_path, query, threshold);

    } else {
        fprintf(stderr, "error: unknown command: %s (expected 'pair' or 'score')\n", command);
        return 1;
    }
}
