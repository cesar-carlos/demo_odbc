# Coding Standards & Best Practices

## General Philosophy

1.  **KISS (Keep It Simple, Stupid)**: Complexity should be avoided. Simple solutions are easier to maintain and test.
2.  **DRY (Don't Repeat Yourself)**: Avoid duplicating code. Extract common logic into functions or shared components.
3.  **YAGNI (You Ain't Gonna Need It)**: Do not implement features or abstractions "just in case" for the future. Implement what is needed now.

## Naming Conventions

Consistent naming is crucial for readability. Use the language's standard convention, but generally:

*   **Classes / Interfaces / Types**: `PascalCase` (e.g., `UserRepository`, `PaymentService`).
*   **Methods / Variables**: `camelCase` (e.g., `calculateTotal`, `isActive`).
*   **Constants**: `camelCase` (e.g., `maxRetries`) or `SCREAMING_SNAKE_CASE` (e.g., `MAX_RETRIES`), depending on specific language idiom (default to `lowerCamelCase` if unsure).
*   **Files**: `snake_case` (e.g., `user_repository.ext`).

## Code Style

### Self-Documenting Code
*   **Names over Comments**: A variable named `daysUntilExpiration` is better than `int d; // days until expiration`.
*   **Small Functions**: Functions should do one thing. If a function is too long, break it down.

### Magic Numbers
*   **Avoid**: `if (status == 2) ...`
*   **Prefer**: `const activeStatus = 2; if (status == activeStatus) ...`
*   Always extract literals (numbers, strings) into named constants if they have business meaning.

### Comments
*   **Explain Why, Not What**: Code explains *what* is happening. Comments should explain *why* a non-obvious decision was made.
*   **No Zombie Code**: Do not leave commented-out code blocks. Use Git history for that.

### Error Handling
*   **Explicit Handling**: Do not silently swallow exceptions. Log them or handle them meaningfully.
*   **Result Pattern**: Consider using a Result/Either pattern instead of throwing exceptions for expected failures (e.g., "User not found").

### Null Safety
*   **Avoid Nulls**: Design APIs to avoid `null` return values where possible. Return an "Empty" object or an `Option/Maybe` type.
*   **Explicit Nullability**: If a value can be missing, type it explicitly as nullable (e.g., `String?`) and handle both cases.

## Review Checklist
- [ ] Is the code simple and readable?
- [ ] Are names descriptive?
- [ ] Is logic duplicated?
- [ ] Are magic numbers replaced by constants?
- [ ] Are happy paths and edge cases handled?
