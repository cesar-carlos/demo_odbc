---
trigger: always_on
---

# Testing Standards

## Testing Strategy

We follow the **Testing Pyramid**:
1.  **Unit Tests** (Base): Fast, isolated, high volume. Cover Entities, Value Objects, Use Cases.
2.  **Integration Tests** (Middle): Test interactions between layers (e.g., Repository with Database).

## Structure and Organization

*   Test files should mirror the source directory structure.
    *   `src/domain/user.ext` -> `tests/domain/user_test.ext`
*   Each test suite should focus on a single class or module.

## Unit Testing Best Practices

### AAA Pattern
Use the **Arrange-Act-Assert** pattern for clarity:
```
test('should calculate total correctly', () {
  // Arrange: Setup data and mocks
  const cart = new Cart();
  cart.add(item);

  // Act: Execute the function under test
  const total = cart.total();

  // Assert: Verify the result
  expect(total).toBe(100);
});
```

### Isolation
*   Tests must be independent. One test should not depend on the state left by another.
*   Use `setUp` and `tearDown` to reset state between tests.

### Mocking
*   **Mock Dependencies**: When testing a Service, mock the Repository it depends on.
*   **No Mocks for Values**: Do not mock Entities or Value Objects; use real instances as they are simple data holders.

### Naming Tests
*   **Format**: `[MethodName] should [ExpectedBehavior] when [Condition]`
*   **Example**: `calculateTotal should return zero when cart is empty`

## Code Coverage
*   Aim for high coverage on **Domain Logic** (Entities, Use Cases).
*   Do not obsess over 100% coverage on trivial code (getters/setters).
