# Security Best Practices

Security should be designed into the system from the start, not added as an afterthought.

## Input Validation
*   **Validate All Inputs**: Never trust data coming from outside user (API, UI, external systems).
*   **Whitelisting**: Prefer allowing known good characters over blocking known bad ones.
*   **Type Checking**: Ensure inputs match expected types (e.g., ensure age is an integer).

## Authentication & Authorization
*   **Principle of Least Privilege**: Users and services should only have the permissions necessary to perform their tasks.
*   **Secure Storage**: Never store passwords in plain text. Use strong hashing algorithms (e.g., Argon2, bcrypt).
*   **Token Management**: Use short-lived access tokens and secure refresh token flows.

## Data Protection
*   **Encryption at Rest**: Sensitive data (PII, credentials) should be encrypted in the database.
*   **Encryption in Transit**: All network communication must use TLS/SSL (HTTPS).
*   **No Sensitive Info in Logs**: Ensure logs do not contain passwords, API keys, or PII.

## Code Security
*   **Dependencies**: Regularly update libraries to patch known vulnerabilities.
*   **Hardcoding**: Never hardcode secrets (API Keys, DB Passwords) in the source code. Use Environment Variables.
