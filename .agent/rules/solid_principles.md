# SOLID Principles

Adhering to SOLID principles ensures the software remains easy to maintain, extend, and understand.

## S - Single Responsibility Principle (SRP)
*   **Principle**: A class should have one, and only one, reason to change.
*   **Application**:
    *   Break large "God Classes" into smaller, focused classes.
    *   Separate logic for identifying a user from the logic of saving a user to a database.

## O - Open/Closed Principle (OCP)
*   **Principle**: Software entities (classes, modules, functions) should be open for extension, but closed for modification.
*   **Application**:
    *   Use polymorphism and interfaces.
    *   To add a new feature (e.g., a new Payment Method), create a new class implementing the `Payment` interface instead of adding `if/else` checks in an existing class.

## L - Liskov Substitution Principle (LSP)
*   **Principle**: Subtypes must be substitutable for their base types without altering the correctness of the program.
*   **Application**:
    *   If `S` is a subtype of `T`, then objects of type `T` may be replaced with objects of type `S` without breaking the application.
    *   Derived classes should not change the expected behavior of the parent class methods (e.g., throwing unexpected exceptions).

## I - Interface Segregation Principle (ISP)
*   **Principle**: Clients should not be forced to depend upon interfaces that they do not use.
*   **Application**:
    *   Prefer many small, specific interfaces (Role Interfaces) over one large, general-purpose interface.
    *   Break a massive `UserRepository` into smaller interfaces like `UserReader` and `UserWriter` if a consumer only needs reading.

## D - Dependency Inversion Principle (DIP)
*   **Principle**: High-level modules should not depend on low-level modules. Both should depend on abstractions. Abstractions should not depend on details. Details should depend on abstractions.
*   **Application**:
    *   Domain layer (High-level) depends on Repository Interfaces (Abstractions).
    *   Infrastructure layer (Low-level) implements those Interfaces.
    *   Use Dependency Injection to provide implementations at runtime.
