# Way-Match Test Results

Typical output from the BM25 vs NCD scorer comparison tests. These results document the current baseline and illustrate the behavioral differences between the two matching engines.

Last run: 2026-02-17

## Fixture Tests (synthetic corpus)

32 test prompts scored against a fixed 7-way corpus. Both scorers use a curated vocabulary and description per way.

```
=== Way-Match Test Harness ===
Scorers:  NCD BM25

 1  [direct ] NCD:TP     BM25:TP     add unit tests for the auth module
 2  [direct ] NCD:FN     BM25:TP     write pytest fixtures for the database layer
 3  [direct ] NCD:FN     BM25:TP     increase test coverage to 80%
 4  [direct ] NCD:TP     BM25:TP     mock the payment gateway in tests
 5  [direct ] NCD:TP     BM25:TP     how should I structure the REST API endpoints
 6  [direct ] NCD:TP     BM25:TP     add pagination to the users endpoint
 7  [direct ] NCD:TP     BM25:TP     what HTTP status code for a deleted resource
 8  [direct ] NCD:TP     BM25:TP     debug this segfault in the parser
 9  [direct ] NCD:TP     BM25:TP     investigate why the build is broken
10  [direct ] NCD:FN     BM25:FN     add a breakpoint and step through the logic
11  [direct ] NCD:TP     BM25:TP     fix the XSS vulnerability in the comment form
12  [direct ] NCD:TP     BM25:TP     rotate the database credentials
13  [direct ] NCD:TP     BM25:TP     sanitize user input before SQL queries
14  [direct ] NCD:TP     BM25:TP     design the database schema for orders
15  [direct ] NCD:TP     BM25:TP     which architecture pattern for the notification service
16  [direct ] NCD:TP     BM25:TP     set up environment variables for staging
17  [direct ] NCD:TP     BM25:TP     manage the dotenv files across environments
18  [direct ] NCD:TP     BM25:TP     plan how to implement the search feature
19  [direct ] NCD:FN     BM25:TP     why was the caching layer built this way
20  [synonym] NCD:FN     BM25:FN     speed up the SQL queries
21  [synonym] NCD:FN     BM25:FN     harden the login endpoints against brute force
22  [synonym] NCD:FN     BM25:FN     the app crashes when you submit the form
23  [synonym] NCD:TP     BM25:FN     verify the service handles bad input gracefully
24  [synonym] NCD:TP     BM25:TP     set up the connection string for postgres
25  [synonym] NCD:TP     BM25:FN     how do the microservices talk to each other
26  [synonym] NCD:FN     BM25:TP     make the API respond with proper error codes
27  [negative] NCD:TN     BM25:TN     what's the weather today
28  [negative] NCD:TN     BM25:TN     hello
29  [negative] NCD:TN     BM25:TN     tell me a joke about programmers
30  [negative] NCD:TN     BM25:TN     what time zone is Tokyo in
31  [negative] NCD:TN     BM25:TN     summarize this document for me
32  [negative] NCD:TN     BM25:TN     translate this paragraph to Spanish

=== Results (32 tests) ===

NCD (gzip):  TP=18 FP=0 TN=6 FN=8  accuracy=24/32
BM25:        TP=20 FP=0 TN=6 FN=6  accuracy=26/32

Head-to-head: BM25 wins=4  NCD wins=2  ties=26
```

### Fixture test interpretation

| Metric | BM25 | NCD |
|--------|------|-----|
| True positives | 20/26 (77%) | 18/26 (69%) |
| False positives | 0/6 (0%) | 0/6 (0%) |
| Overall accuracy | 26/32 (81%) | 24/32 (75%) |

Both scorers achieve zero false positives — neither fires on unrelated prompts. BM25 wins on recall: it catches more true matches, particularly on prompts where vocabulary terms appear in stemmed or derived forms (e.g., "pytest fixtures" → testing, "caching layer built this way" → adr-context).

NCD wins 2 tests where byte-level compression similarity catches patterns that term-frequency misses: "verify the service handles bad input gracefully" (testing) and "how do the microservices talk to each other" (design). These are cases where the prompt shares no vocabulary terms but compresses well against the description.

The 4 shared false negatives (both scorers miss) represent genuine vocabulary gaps — prompts using synonyms or domain jargon not present in any way's vocabulary or description.

## Integration Tests (real way files)

31 test prompts scored against actual `way.md` files extracted from the live ways directory. This tests the real pipeline: frontmatter extraction, vocabulary parsing, threshold behavior.

```
=== Integration Test: Real Way Files ===

Found 9 semantic ways

 1  NCD:FAIL BM25:OK   expect=testing    got=[testing]           write some unit tests for this module
 2  NCD:OK   BM25:OK   expect=testing    got=[testing]           run pytest with coverage
 3  NCD:OK   BM25:OK   expect=testing    got=[testing,design]    mock the database connection in tests
 4  NCD:OK   BM25:OK   expect=api        got=[api]               design the REST API for user management
 5  NCD:OK   BM25:OK   expect=api        got=[api]               what status code should this endpoint return
 6  NCD:OK   BM25:OK   expect=api        got=[api]               add versioning to the API
 7  NCD:FAIL BM25:OK   expect=debugging  got=[debugging]         debug why this function returns null
 8  NCD:FAIL BM25:OK   expect=debugging  got=[debugging]         troubleshoot the failing deployment
 9  NCD:FAIL BM25:FAIL expect=debugging                          bisect to find which commit broke it
10  NCD:OK   BM25:OK   expect=security   got=[security]          fix the SQL injection vulnerability
11  NCD:FAIL BM25:OK   expect=security   got=[security]          store passwords with bcrypt
12  NCD:FAIL BM25:OK   expect=security   got=[security]          sanitize the form input
13  NCD:OK   BM25:OK   expect=design     got=[design]            design the database schema
14  NCD:OK   BM25:OK   expect=design     got=[design]            use the factory pattern here
15  NCD:FAIL BM25:OK   expect=design     got=[design]            model the component interfaces
16  NCD:FAIL BM25:OK   expect=config     got=[config]            set up the .env file for production
17  NCD:OK   BM25:OK   expect=config     got=[config]            manage environment variables
18  NCD:FAIL BM25:OK   expect=config     got=[config]            configure the yaml settings
19  NCD:OK   BM25:OK   expect=adr-context got=[adr-context]      plan how to build the notification system
20  NCD:FAIL BM25:OK   expect=adr-context got=[adr-context]      why was this feature designed this way
21  NCD:OK   BM25:OK   expect=adr-context got=[adr-context]      pick up work on the auth implementation
22  NCD:FAIL BM25:OK   expect=NONE                               what is the capital of France
23  NCD:FAIL BM25:OK   expect=NONE                               tell me about photosynthesis
24  NCD:OK   BM25:OK   expect=NONE                               how tall is Mount Everest
25  NCD:FAIL BM25:OK   expect=NONE                               write a haiku about rain
26  NCD:OK   BM25:OK   expect=testing    got=[testing]           does this code have enough test coverage
27  NCD:FAIL BM25:OK   expect=api        got=[api,debugging]     the endpoint is returning 500 errors
28  NCD:FAIL BM25:FAIL expect=debugging                          the app keeps crashing on startup
29  NCD:FAIL BM25:FAIL expect=security   got=[api]               are our API keys exposed anywhere
30  NCD:OK   BM25:OK   expect=design     got=[design]            should we use a monolith or microservices
31  NCD:OK   BM25:FAIL expect=config     got=[design]            the database connection string needs updating

=== Integration Results (31 tests) ===

NCD (gzip):  TP=14 FP=3 TN=1 FN=13  accuracy=15/31
BM25:        TP=23 FP=0 TN=4 FN=4  accuracy=27/31

BM25 wins: +12 correct
```

### Integration test interpretation

| Metric | BM25 | NCD |
|--------|------|-----|
| True positives | 23/27 (85%) | 14/27 (52%) |
| False positives | 0/4 (0%) | 3/4 (75%) |
| Overall accuracy | 27/31 (87%) | 15/31 (48%) |

The integration test reveals the real-world gap. Against live way files with their actual vocabulary and thresholds, BM25 achieves 87% accuracy with zero false positives. NCD drops to 48% — and critically, produces 3 false positives on negative-control prompts ("what is the capital of France", "tell me about photosynthesis", "write a haiku about rain").

**Why NCD struggles with real ways**: The live vocabulary fields are larger and more varied than the synthetic corpus. NCD's compression-distance metric becomes less discriminating as document size grows — more bytes mean more incidental compression overlap. BM25's term-frequency scoring scales cleanly because it weights individual term matches, not byte patterns.

**Interesting BM25 failures**:
- "bisect to find which commit broke it" — scores 1.68 against debugging (threshold 2.0). The verb "bisect" isn't in the vocabulary despite being a classic debugging technique.
- "are our API keys exposed anywhere" — matches API (2.68) instead of security (1.59). "API keys" triggers the API way's vocabulary harder than "exposed" triggers security.
- "the database connection string needs updating" — matches design (2.28) over config (1.79). "database" and "connection" appear in design's vocabulary.

These failures are addressable by tuning vocabulary and thresholds — which is the point of running these tests.

## Interpreting the Metrics

| Symbol | Meaning |
|--------|---------|
| **TP** (True Positive) | Prompt correctly matched to the expected way |
| **FP** (False Positive) | Prompt incorrectly matched when it shouldn't have been |
| **TN** (True Negative) | Unrelated prompt correctly rejected by all ways |
| **FN** (False Negative) | Prompt should have matched a way but didn't |

For way matching, **false positives are worse than false negatives**. A false negative means missing an opportunity to inject guidance — the agent still works, just without the extra context. A false positive means injecting irrelevant guidance, wasting context tokens and potentially confusing the agent.

Both scorers prioritize precision (low FP) over recall (low FN), which is the right trade-off for this system.

## Running the Tests

```bash
# Both test suites
tests/way-match/run-tests.sh

# Fixture tests only (BM25 vs NCD, synthetic corpus)
tests/way-match/run-tests.sh fixture --verbose

# Integration tests only (real way files)
tests/way-match/run-tests.sh integration

# Individual harnesses directly
bash tools/way-match/test-harness.sh --verbose
bash tools/way-match/test-integration.sh

# Via Makefile
make test              # fixture tests (verbose)
make test-integration  # integration tests
make test-bm25         # BM25 only
make test-ncd          # NCD only (no binary needed)
```

## Known Limitations

**Pair mode IDF corpus size.** In `pair` mode (used by the hook scripts), BM25 computes IDF against a built-in background corpus of 7 ways hardcoded in `way-match.c`. This is balanced for the ~20 ways that ship with the repo — the 7 entries cover the semantic domains well enough for IDF to discriminate effectively, as the test results above show. But IDF resolution depends on corpus size: if you scale to a significantly larger ways set (50+), terms that should be distinctive may appear "common" relative to an undersized background. Two options if you get there:
- **Expand the built-in corpus**: Add representative entries to the `BUILTIN_WAYS` array in `way-match.c` (one per domain is enough) and rebuild with `make local`. This keeps pair mode's simplicity — no extra files needed at runtime.
- **Switch to score mode**: Generate a JSONL corpus from your live way files and use `way-match score --corpus ways.jsonl` instead of `pair`. This gives BM25 the full document set for IDF — the integration test already demonstrates this pattern.

## When Results Change

If you update a way's `vocabulary:` or `threshold:`, re-run the integration tests. If you modify `way-match.c` or rebuild the binary, run both suites. Update this file when baselines shift significantly — the numbers here serve as a reference point for regression detection.
