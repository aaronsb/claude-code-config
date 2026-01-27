---
match: regex
pattern: solid.?principle|refactor|code.?review|code.?quality
macro: append
scan_exclude: \.md$|\.lock$|\.min\.(js|css)$|\.generated\.|\.bundle\.|vendor/|node_modules/|dist/|build/|__pycache__/
---
# Code Quality Way

## SOLID Principles
- **S**ingle Responsibility: One reason to change
- **O**pen/Closed: Open for extension, closed for modification
- **L**iskov Substitution: Subtypes substitutable for base types
- **I**nterface Segregation: Many specific > one general interface
- **D**ependency Inversion: Depend on abstractions, not concretions

## Quality Flags
- Files > 500 lines → consider splitting
- Functions > 3 nesting levels → extract methods
- Classes > 7 public methods → consider decomposition
- Functions > 30-50 lines → refactor for clarity

## Ecosystem Conventions
- Don't introduce patterns foreign to the language/ecosystem
- Examples to avoid:
  - Rust-style Result/Option in TypeScript
  - Monadic error handling where exceptions are standard
  - Custom implementations of what libraries already provide
