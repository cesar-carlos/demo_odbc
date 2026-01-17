# Architecture & Design Principles

This project follows **Clean Architecture** combined with **Domain-Driven Design (DDD)** principles to ensure scalability, maintainability, and testability.

## Fundamental Principles

1.  **Separation of Concerns**: Each layer has a distinct responsibility.
2.  **Dependency Rule**: Source code dependencies must point only inward, toward higher-level policies. The inner layers should not know anything about the outer layers.
3.  **Testability**: Business logic (Domain) can be tested without UI, Database, or any external element.
4.  **Independence**: The core business logic is independent of frameworks, databases, UIs, or any external agency.

## Layer Structure

The application is divided into concentric layers:

### 1. Domain Layer (Core)
*   **Role**: Encapsulates the core business logic and rules.
*   **Dependencies**: None (Pure, Independent).
*   **Components**:
    *   **Entities**: Business objects with identity.
    *   **Value Objects**: Immutable objects defined by their attributes.
    *   **Repository Interfaces**: Contracts for data access.
    *   **Use Cases**: Application-specific business rules.

### 2. Application Layer
*   **Role**: Orchestrates the flow of data to and from the Domain entities, and directs those entities to use their Critical Business Rules to achieve the goals of the use case.
*   **Dependencies**: Domain Layer.
*   **Components**:
    *   **Services**: Coordinators of multiple use cases / workflows.
    *   **DTOs (Data Transfer Objects)**: Simple objects to transfer data between layers.
    *   **Mappers**: Converters between Entities and DTOs.

### 3. Infrastructure Layer
*   **Role**: Adapters that convert data from the format most convenient for the use cases and entities, to the format most convenient for some external agency such as Database or Web.
*   **Dependencies**: Application and Domain Layers.
*   **Components**:
    *   **Repository Implementations**: Concrete implementations of Domain interfaces.
    *   **Data Sources**: Low-level data access (API clients, DB drivers).
    *   **External Services**: Implementations of external integrations.

### 4. Presentation Layer
*   **Role**: The UI/View layer. Responsible for presenting information to the user and interpreting user commands.
*   **Dependencies**: Application and Domain Layers.
*   **Components**:
    *   **UI Components**: Widgets, Views, Pages.
    *   **State Managers**: Controllers, ViewModels, Presenters.

### 5. Shared / Core
*   **Role**: Contains common utilities, constants, and extensions used across multiple layers (e.g., Date formatters, String extensions).
*   **Dependencies**: None (should not depend on Business layers to avoid cycles).

## Folder Structure

A typical folder structure complying with this architecture:

```
src/
├── domain/              # The Circle's Center
│   ├── entities/
│   ├── value_objects/
│   ├── repositories/    # Interfaces
│   └── use_cases/
│
├── application/         # Orchestration
│   ├── services/
│   ├── dtos/
│   └── mappers/
│
├── infrastructure/      # Outer Ring
│   ├── repositories/    # Implementations
│   ├── datasources/
│   └── external/
│
├── presentation/        # UI
│   ├── pages/
│   ├── components/
│   └── controllers/
│
└── shared/              # Common
    ├── utils/
    └── constants/
```

## Domain Layer Guidelines

The **Domain Layer** is the heart of the software. It contains the Enterprise Logic and Application Business Rules. It must be completely isolated from technical details (UI, Databases, Frameworks).

### 1. Entities

*   **Definition**: Objects that have a distinct identity that runs through time and different representations.
*   **Rules**:
    *   Must have a unique identifier (ID).
    *   Comparisons are done by ID, not by attributes.
    *   Should contain methods implementing business logic related to the entity's data.
    *   Should be independent of frameworks (POJOs / Plain Objects).

### 2. Value Objects

*   **Definition**: Objects that describe some characteristic of a thing but represent no unique identity.
*   **Rules**:
    *   **Immutable**: Once created, they cannot change.
    *   **Equality by Value**: Two value objects are equal if all their properties are equal.
    *   **Self-Validating**: Constructor should validate the input (e.g., an `Email` class must ensure the string format is valid).

### 3. Use Cases (Interactors)

*   **Definition**: Encapsulate a specific business rule or operation (e.g., `CreateUser`, `ProcessPayment`).
*   **Rules**:
    *   **Single Responsibility**: One use case = One business action.
    *   **Input/Output**: Receives simple data (or DTOs) and returns results (Entities or DTOs).
    *   **Orchestration**: Calls Repositories and Entity methods; does not implement low-level data access itself.

### 4. Repository Interfaces

*   **Definition**: Abstractions of the data access layer.
*   **Rules**:
    *   Defined as Interfaces/Abstract Classes in the Domain layer.
    *   Methods should speak the "Domain Language" (e.g., `findActiveUsers` instead of `select * where status=1`).
    *   **No Implementation**: The implementation belongs to the Infrastructure layer.

## Dependency Rules Checklist

- [ ] **Domain** imports NOTHING from outer layers.
- [ ] **Application** imports only **Domain**.
- [ ] **Infrastructure** imports **Application** and **Domain**.
- [ ] **Presentation** imports **Application** and **Domain**.
- [ ] **Shared** is available to all, but imports NONE of the above (to prevent circular deps).
