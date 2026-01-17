# Domain Layer Guidelines

The **Domain Layer** is the heart of the software. It contains the Enterprise Logic and Application Business Rules. It must be completely isolated from technical details (UI, Databases, Frameworks).

## 1. Entities

*   **Definition**: Objects that have a distinct identity that runs through time and different representations.
*   **Rules**:
    *   Must have a unique identifier (ID).
    *   Comparisons are done by ID, not by attributes.
    *   Should contain methods implementing business logic related to the entity's data.
    *   Should be independent of frameworks (POJOs / Plain Objects).

## 2. Value Objects

*   **Definition**: Objects that describe some characteristic of a thing but represent no unique identity.
*   **Rules**:
    *   **Immutable**: Once created, they cannot change.
    *   **Equality by Value**: Two value objects are equal if all their properties are equal.
    *   **Self-Validating**: Constructor should validate the input (e.g., an `Email` class must ensure the string format is valid).

## 3. Use Cases (Interactors)

*   **Definition**: Encapsulate a specific business rule or operation (e.g., `CreateUser`, `ProcessPayment`).
*   **Rules**:
    *   **Single Responsibility**: One use case = One business action.
    *   **Input/Output**: Receives simple data (or DTOs) and returns results (Entities or DTOs).
    *   **Orchestration**: Calls Repositories and Entity methods; does not implement low-level data access itself.

## 4. Repository Interfaces

*   **Definition**: Abstractions of the data access layer.
*   **Rules**:
    *   Defined as Interfaces/Abstract Classes in the Domain layer.
    *   Methods should speak the "Domain Language" (e.g., `findActiveUsers` instead of `select * where status=1`).
    *   **No Implementation**: The implementation belongs to the Infrastructure layer.

## Best Practices

*   **Pure Language**: Use standard language features (classes, functions) without external library annotations where possible.
*   **Rich Domain Model**: Prefer putting logic inside Entities (Rich Model) rather than having "Anemic Models" (just getters/setters) and putting all logic in Services.
