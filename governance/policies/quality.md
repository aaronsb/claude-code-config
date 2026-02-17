# Quality Ways

Guidance for code quality, testing, debugging, error handling, and performance.

## Quality

**Triggers**: Prompt mentions "refactor", "code review", "code quality", "cleanup", "simplify", "tech debt"

**Macro**: Appends a file length scan of the current project, listing files over 500 lines as review candidates and files over 800 lines as priority candidates for decomposition.

The quality way is opinionated about code smells rather than style. It doesn't care about formatting (that's what formatters are for). It cares about structural problems that make code hard to change:

- **File length** (>500 lines suggests too many responsibilities)
- **Nesting depth** (>4 levels suggests extract-and-name opportunities)
- **Method count per class** (>15 suggests the class is doing too much)
- **Function length** (>40 lines suggests decomposition)

The macro's file scan makes this concrete: instead of abstract guidance about file length, Claude sees "here are 3 files in this project over 800 lines." This shifts the conversation from principle to action.

The way also warns against ecosystem-foreign patterns - using Java idioms in Python, or OOP patterns in Go. Following a language's conventions makes code readable to practitioners of that language.

## Testing

**Triggers**: Semantic match on testing/TDD/mocking concepts; running `pytest`, `jest`, `npm test`, `cargo test`, etc.

Prescribes what to test and how to structure tests, not which framework to use (that's detected from project files).

**What to test** for each function:
1. Happy path (expected input, expected output)
2. Empty/null input (absence handling)
3. Boundary values (min, max, off-by-one)
4. Error conditions (invalid input, dependency failures)

**How to structure tests**:
- Arrange-Act-Assert pattern
- One logical assertion per test (test one behavior, not one line)
- Independent tests with no shared mutable state
- Name tests `should [behavior] when [condition]`

**Mocking philosophy**: Mock external dependencies (network, filesystem, databases). Never mock the code under test or its internal helpers. Prefer fakes (in-memory implementations) over mock libraries - they're more realistic and don't couple tests to implementation details.

**What to assert**: Observable outputs and side effects only. If you need to reach into private state to verify behavior, the design needs rethinking - the test is telling you the public interface is incomplete.

## Debugging

**Triggers**: Semantic match on debug/troubleshoot/investigate concepts

Prescribes a systematic process rather than random exploration:

1. **Read the error message** - surprisingly often skipped
2. **Search the codebase** - grep for the error string, find where it's raised
3. **Check recent changes** - `git log` and `git diff` for the affected area
4. **Reproduce** - confirm you can trigger the bug before trying to fix it
5. **Use git bisect** - when the cause isn't obvious, binary search through history

The way deliberately avoids suggesting `console.log` debugging as a first resort. Structured investigation finds root causes; print debugging finds symptoms.

## Errors

**Triggers**: Prompt mentions "error handling", "exception", "try catch", "throw"

Takes a strong position on where to catch errors: **at system boundaries only**. API endpoints, CLI entry points, message handlers. Not inside business logic.

The rationale: catching errors deep inside the call stack leads to:
- Swallowed errors (`catch (e) {}`)
- The same error logged at multiple levels
- Catch-and-rethrow that adds no context

Instead: let errors propagate naturally. Catch at the boundary where you can translate them into user-facing responses and log them once with full context.

When crossing module boundaries, wrap errors with context (`Failed to process order ${orderId}: ${err.message}`) and preserve the original as the cause. This gives you a breadcrumb trail without catching at every level.

The distinction between **programmer errors** (bugs - fail fast, don't catch) and **operational errors** (expected failures - handle gracefully) guides which errors deserve handling at all.

## Performance

**Triggers**: Prompt mentions "slow", "optimize", "latency", "bottleneck", "benchmark", "memory leak"

Starts with a controversial position: **don't profile first**. Start with static code analysis. The most common performance problems are visible in the code:

- N+1 query patterns
- Nested loops over large collections
- Missing caching for repeated expensive operations
- Synchronous I/O in hot paths

These don't need a profiler to find. A code review catches them.

Profiling comes second, for problems that aren't structurally obvious. The way provides language-specific tool suggestions (cProfile for Python, Chrome DevTools for JS, etc.) but emphasizes: measure before and after. "It feels faster" is not evidence.

The way explicitly warns against premature optimization - touching code that isn't on the hot path, optimizing before measuring, or sacrificing readability for marginal gains.
