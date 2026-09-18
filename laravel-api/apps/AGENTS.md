# AGENTS.md

## Project Purpose

This project is a **production-ready Laravel API-only backend** designed to serve multiple clients:

* Flutter mobile/desktop applications
* Flutter offline-first applications
* Vue.js web applications
* Python applications/services
* Future API clients

The API is the central source of truth for authentication, authorization, business logic, validation, synchronization, and data persistence.

---

## 1. API Architecture

* Keep the application API-only.
* Use clean, modular, and maintainable Laravel architecture.
* Keep controllers thin.
* Move complex business logic into Services, Actions, Jobs, or appropriate domain classes.
* Keep API functionality independent from any specific frontend/client.
* Prefer Laravel-native solutions before adding dependencies.
* All API code must remain portable and understandable in a fresh Laravel project.

---

## 2. API Versioning

All public endpoints must be versioned:

```text
/api/v1/...
```

* Never introduce breaking changes silently.
* Use a new API version for breaking changes when required.
* Keep version-specific Controllers, Requests, and Resources organized clearly.

---

## 3. API Routes

Use:

```text
routes/api.php
```

Follow RESTful conventions and appropriate HTTP methods.

Example:

```text
GET     /api/v1/students
GET     /api/v1/students/{id}
POST    /api/v1/students
PUT     /api/v1/students/{id}
DELETE  /api/v1/students/{id}
```

Use appropriate middleware, authentication, authorization, and rate limiting.

---

## 4. Authentication & Authorization

Use secure token-based authentication suitable for multi-platform clients.

Authentication must work consistently for Flutter, Vue.js, Python, and future clients.

Implement:

* secure token handling;
* token revocation/logout;
* refresh-token handling when required;
* rate limiting for sensitive authentication endpoints;
* server-side authorization using Policies, Gates, Roles, or Permissions.

Never rely on frontend authorization for security.

---

## 5. UUID & Offline-First Support

Resources that require offline creation/synchronization should use stable, collision-resistant UUID-based identifiers.

Design APIs to support offline-first clients:

```text
Local Data
   ↓
Offline Changes
   ↓
Synchronization
   ↓
Server Validation
   ↓
Authorization
   ↓
Conflict Resolution
   ↓
Database
```

Consider:

* `created_at`
* `updated_at`
* synchronization metadata
* client mutation IDs
* incremental synchronization
* retry safety
* duplicate prevention
* conflict handling

Never silently overwrite important data without a defined conflict strategy.

---

## 6. Idempotency & Synchronization

Synchronization and retryable operations must be safe.

Where appropriate:

* use client-generated mutation/idempotency IDs;
* prevent duplicate records;
* support incremental synchronization;
* make retry behavior predictable;
* explicitly define conflict resolution.

Do not assume permanent internet connectivity.

---

## 7. Validation

Never trust client input.

Use Form Request classes for meaningful validation.

Validate:

* required fields;
* data types;
* formats;
* relationships;
* uniqueness;
* allowed values;
* maximum sizes;
* business rules.

Client-side validation is for UX; server-side validation is authoritative.

---

## 8. API Resources & Responses

Use API Resources to control exposed data.

Never expose sensitive/internal fields such as:

* passwords;
* tokens;
* secrets;
* internal security data.

Keep responses consistent.

### Success

```json
{
    "success": true,
    "message": "Operation successful.",
    "data": {}
}
```

### Error

```json
{
    "success": false,
    "message": "Operation failed.",
    "errors": {}
}
```

Use correct HTTP status codes such as:

```text
200  201  204
400  401  403  404
409  422  429  500
```

Do not return HTTP 200 for every error.

---

## 9. Database Design

Prioritize:

* data integrity;
* foreign keys;
* unique constraints;
* indexes;
* correct data types;
* UUID support;
* relationships;
* scalability.

Use migrations for all schema changes.

Do not rely only on application-level validation for database integrity.

Do not add soft deletes unless the business requirement specifically needs them.

---

## 10. Security

Treat every API request as untrusted.

Always consider:

* authentication;
* authorization;
* validation;
* rate limiting;
* SQL injection;
* mass assignment;
* insecure object access;
* sensitive data exposure;
* brute-force protection;
* file-upload security;
* dependency security.

Never hard-code or commit:

```text
passwords
API keys
tokens
private keys
database credentials
secrets
```

Use `.env` and configuration files for environment-specific values.

Never expose stack traces, SQL queries, secrets, or internal paths in production responses.

---

## 11. Performance

Avoid:

* N+1 queries;
* unnecessary database queries;
* unbounded collections;
* huge API responses;
* unnecessary external requests;
* heavy synchronous processing.

Use where appropriate:

* eager loading;
* pagination;
* indexes;
* caching;
* queues;
* batch processing;
* incremental synchronization.

Do not optimize prematurely without evidence.

---

## 12. Business Logic & Transactions

Keep controllers thin.

Use database transactions when multiple operations must succeed or fail together.

Use Jobs/Queues for long-running or retryable operations such as:

* SMS;
* email;
* notifications;
* large synchronization;
* bulk processing.

Jobs should be retry-safe where possible.

---

## 13. Testing

Every meaningful API feature must have tests.

Test at minimum:

* successful requests;
* validation failures;
* authentication failures;
* authorization failures;
* not-found cases;
* duplicate data;
* important business rules;
* synchronization;
* idempotency;
* conflict handling where applicable;
* API response structure;
* HTTP status codes.

Do not test only the happy path.

Run relevant tests after changes.

---

## 14. Code Quality

Follow Laravel and modern PHP conventions.

Prefer:

* dependency injection;
* typed parameters;
* return types;
* meaningful names;
* small focused methods;
* reusable components;
* readable code.

Avoid:

* duplicated logic;
* giant controllers;
* giant methods;
* unnecessary abstractions;
* unexplained magic values;
* global state;
* unnecessary dependencies.

Use Artisan for framework-generated files where appropriate.

---

## 15. Development Workflow

Before implementing a significant feature:

1. Understand the requirement.
2. Inspect existing architecture.
3. Identify affected routes and dependencies.
4. Design database changes.
5. Design API request/response contracts.
6. Implement validation.
7. Implement business logic.
8. Implement authorization.
9. Implement controller/resource.
10. Add routes.
11. Add tests.
12. Run formatting and tests.
13. Review security and performance.
14. Review offline/synchronization implications.
15. Update documentation when required.

Never modify existing API behavior without checking its possible client impact.

---

## 16. Production Readiness

Before considering a feature complete, verify:

* [ ] Correct API version
* [ ] Authentication implemented
* [ ] Authorization implemented
* [ ] Validation implemented
* [ ] Database integrity verified
* [ ] API Resource implemented
* [ ] Consistent responses/errors
* [ ] Correct HTTP status codes
* [ ] Pagination where required
* [ ] Rate limiting where required
* [ ] Offline/sync behavior considered
* [ ] Idempotency considered where required
* [ ] Conflict handling defined where required
* [ ] Security reviewed
* [ ] Performance reviewed
* [ ] Tests written and passing
* [ ] Documentation updated where required
* [ ] No secrets exposed
* [ ] No unnecessary client-specific dependency
* [ ] Code remains portable and maintainable

---

## Final Principle

Build every feature as part of a:

**Secure, versioned, testable, scalable, portable, production-ready Laravel API designed for Flutter offline-first, Vue.js, Python, and future clients.**
