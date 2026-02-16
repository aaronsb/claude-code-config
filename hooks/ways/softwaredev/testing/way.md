---
description: writing unit tests, test coverage, mocking dependencies, test-driven development
vocabulary: unittest coverage mock tdd assertion jest pytest rspec testcase spec fixture describe expect verify
commands: npm\ test|yarn\ test|jest|pytest|cargo\ test|go\ test|rspec
threshold: 2.0
scope: agent, subagent
provenance:
  policy:
    - uri: docs/hooks-and-ways/softwaredev/code-lifecycle.md
      type: governance-doc
  controls:
    - id: NIST SP 800-53 SA-11 (Developer Testing and Evaluation)
      justifications:
        - Four coverage categories (happy path, empty/null, boundary, error) implement structured developer test evaluation
        - Framework auto-detection ensures tests follow project conventions rather than ad-hoc patterns
        - One logical assertion per test enforces precise, evaluable test cases
    - id: IEEE 829-2008 (Test Documentation Standard)
      justifications:
        - Arrange-Act-Assert structure standardizes test documentation format
        - Naming convention (should [behavior] when [condition]) creates self-documenting test specifications
        - Test independence requirement (no shared mutable state) ensures repeatable test execution
    - id: ISO/IEC 25010:2011 (Reliability - Maturity, Fault Tolerance)
      justifications:
        - Boundary value testing (min, max, off-by-one, empty collections) verifies fault tolerance
        - Error condition coverage (invalid input, dependency failures) validates graceful degradation
  verified: 2026-02-09
  rationale: >
    Structured coverage categories implement SA-11 developer testing evaluation. AAA format
    and naming conventions address IEEE 829 test documentation standards. Boundary and error
    condition testing directly measures ISO 25010 reliability characteristics.
---
# Testing Way

## What to Generate

For each function under test, cover:
1. **Happy path** — expected input produces expected output
2. **Empty/null input** — handles absence gracefully
3. **Boundary values** — min, max, off-by-one, empty collections
4. **Error conditions** — invalid input, dependency failures

## Structure

- Arrange-Act-Assert: setup, call, verify
- Name tests: `should [behavior] when [condition]`
- One logical assertion per test — test one behavior, not one line
- Tests must be independent — no shared mutable state between tests

## What to Assert

- Observable outputs and side effects only
- Never assert on method call counts or internal variable values
- If you need to reach into private state, the design needs rethinking

## Mocking

- Mock external dependencies (network, filesystem, databases)
- Do not mock the code under test or its internal helpers
- Prefer fakes (in-memory implementations) over mock libraries when practical

## Project Detection

Detect the test framework from project files (package.json, requirements.txt, Cargo.toml, go.mod). Follow its conventions for file placement and naming.
