---
keywords: test|coverage|mock|tdd|unit.?test|spec
commands: npm\ test|yarn\ test|jest|pytest|cargo\ test|go\ test|rspec
---
# Testing Way

## What to Test
- Behavior, not implementation
- Edge cases and boundaries
- Error paths, not just happy paths

## Approach
1. Write the test first (or at least think about it)
2. One assertion per test when possible
3. Tests should be independent - no shared state
4. Name tests to describe the scenario

## Mocking
- Mock external dependencies, not internal logic
- If mocking is painful, the design might need work
- Prefer fakes over mocks when practical
