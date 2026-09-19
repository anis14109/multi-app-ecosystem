# AGENTS.md

## Flutter Offline-First Development Standards

This document defines the mandatory development rules for the Flutter application inside:

```text
flutter-app/
```

The project is part of the `multi-app-ecosystem` repository and communicates with the Laravel API backend.

The Flutter application must remain:

* Offline-first
* API-driven
* Feature-oriented
* Production-ready
* Testable
* Maintainable
* Secure
* Consistent with Very Good CLI conventions
* Compatible with Android, iOS, Web, Windows, macOS and other supported Flutter platforms where applicable

---

# 1. Core Development Principles

Always follow these principles:

1. **Offline-first is mandatory.**
2. The local database/cache is the primary runtime data source for application UI.
3. The Laravel API is the synchronization authority, not the direct UI data source.
4. Never design a feature that requires an internet connection for normal CRUD/read operations unless the feature inherently requires the server.
5. UI must remain usable when:

   * Internet is unavailable.
   * API is unavailable.
   * API request times out.
   * Authentication token is temporarily unavailable.
   * Synchronization is pending.
6. Network availability must never be treated as proof that an API request will succeed.
7. Every remote operation must have a predictable offline/error state.
8. Prefer simple, explicit architecture over unnecessary abstractions.
9. Follow existing project conventions before introducing new conventions.
10. Never rewrite working project architecture without a documented reason.

---

# 2. Repository Context

This repository contains a multi-platform ecosystem:

```text
multi-app-ecosystem/
├── flutter-app/
├── laravel-api/
└── other platform applications
```

The Flutter application communicates with:

```text
Flutter App
    ↓
Local Database / Local State
    ↓
Repository Layer
    ├── Local Data Source
    └── Remote Data Source
            ↓
       Laravel API
```

The Laravel API is versioned and should be treated as the backend contract.

Never invent API behavior.

Before implementing an API-dependent feature:

1. Inspect the Laravel API implementation.
2. Inspect the API routes.
3. Inspect request/response formats.
4. Inspect authentication requirements.
5. Inspect validation rules.
6. Inspect pagination behavior.
7. Inspect synchronization requirements.
8. Confirm the API version and endpoint.
9. Then implement the Flutter side.

---

# 3. Very Good CLI Standards

The project was created using Very Good CLI conventions.

Maintain the project's existing Very Good CLI style.

Use:

```bash
very_good analyze
very_good test
```

when the Very Good CLI is available.

Otherwise use:

```bash
flutter analyze
flutter test
```

Before completing any implementation, ensure:

```bash
dart format .
flutter analyze
flutter test
```

passes successfully.

Do not weaken linting rules merely to make code pass.

Do not disable analyzer rules unless there is a documented and justified reason.

---

# 4. Dart Style

Follow official Dart formatting and idioms.

Mandatory:

* Use `dart format`.
* Use `final` whenever a variable does not need reassignment.
* Prefer `const` constructors and values where applicable.
* Avoid unnecessary nullable values.
* Avoid unnecessary type annotations when type inference is clear.
* Use meaningful names.
* Keep functions small.
* Keep classes focused.
* Avoid deeply nested conditional logic.
* Prefer early returns when they improve readability.
* Avoid magic numbers and magic strings.
* Centralize reusable constants.

Never write:

```dart
dynamic
```

unless there is a legitimate boundary where dynamic data is unavoidable.

Prefer strongly typed models.

---

# 5. Naming Conventions

Use standard Dart naming:

### Files

```text
snake_case.dart
```

Example:

```text
student_repository.dart
sync_service.dart
login_page.dart
auth_bloc.dart
```

### Classes

```text
PascalCase
```

Example:

```dart
class StudentRepository {}
class AuthBloc {}
class SyncService {}
```

### Variables and methods

```text
camelCase
```

Example:

```dart
final studentName;
Future<void> synchronizeData();
```

### Constants

Prefer descriptive Dart-style constants:

```dart
const defaultPageSize = 20;
```

Do not use unexplained abbreviations.

---

# 6. Feature-First Architecture

New business functionality must be organized by feature.

Preferred structure:

```text
lib/
├── app/
├── core/
├── features/
│   ├── auth/
│   ├── attendance/
│   ├── students/
│   └── ...
├── l10n/
└── bootstrap.dart
```

Each feature should own its business-specific code.

Recommended structure:

```text
features/
└── feature_name/
    ├── bloc/
    │   ├── feature_bloc.dart
    │   ├── feature_event.dart
    │   ├── feature_state.dart
    │   └── bloc.dart
    ├── data/
    │   ├── datasources/
    │   ├── models/
    │   └── repositories/
    ├── view/
    │   ├── feature_page.dart
    │   └── widgets/
    └── feature.dart
```

Do not create one giant global:

```text
services/
repositories/
models/
```

directory for all future business features.

Existing `core/` code should remain for genuinely shared infrastructure.

---

# 7. Core vs Feature Responsibilities

## `core/`

Use `core/` only for cross-feature infrastructure.

Examples:

```text
core/
├── api/
├── database/
├── errors/
├── network/
├── storage/
├── synchronization/
├── security/
├── models/
└── utils/
```

Do not put feature-specific business logic into `core/`.

## `features/`

Feature-specific business logic belongs here.

Examples:

```text
features/auth/
features/students/
features/attendance/
features/settings/
```

A feature should not depend directly on another feature's internal implementation.

Use shared abstractions in `core/` when cross-feature communication is necessary.

---

# 8. Layered Architecture

Use the following dependency direction:

```text
Presentation
     ↓
Bloc / Cubit
     ↓
Repository
     ↓
Local / Remote Data Sources
     ↓
Database / API
```

Never allow:

```text
Widget → Dio
Widget → Database
Widget → SecureStorage
Widget → API endpoint
```

UI must communicate through Bloc/Cubit and repository abstractions.

---

# 9. Offline-First Architecture

Offline-first is a fundamental project requirement.

The default read flow must be:

```text
UI
 ↓
Bloc/Cubit
 ↓
Repository
 ↓
Local Database
 ↓
UI
```

When synchronization is appropriate:

```text
Local Database
      ↓
Sync Engine
      ↓
Laravel API
      ↓
Sync Result
      ↓
Local Database
```

The UI should normally observe local data.

Do not make UI loading states depend exclusively on HTTP responses.

---

# 10. Local-First CRUD

For local CRUD operations:

```text
User Action
    ↓
Validate
    ↓
Write Local Database
    ↓
Update UI Immediately
    ↓
Create Sync Operation
    ↓
Synchronize With API
```

For example:

```text
Create
    ↓
Create local record
    ↓
Mark pending synchronization
    ↓
Display immediately
    ↓
Sync to API
```

The same principle applies to:

```text
Create
Update
Delete
Status changes
Attendance operations
Other mutable data
```

If the API is unavailable, the local operation must remain available whenever the business rule permits it.

---

# 11. Synchronization Rules

Synchronization must be explicit and deterministic.

Every synchronized entity should have enough metadata to determine its synchronization state.

Depending on the entity, use concepts such as:

```text
syncStatus
lastSyncedAt
updatedAt
serverUpdatedAt
syncError
retryCount
```

Do not invent unnecessary synchronization fields if the backend already provides an equivalent mechanism.

Possible states:

```text
synced
pending
syncing
failed
conflict
```

The exact implementation should match the Laravel API contract.

---

# 12. Sync Queue

When a user changes data offline, the operation should be persisted locally.

Example conceptual queue:

```text
sync_queue
-------------------------
id
entity_type
entity_id
operation
payload
created_at
retry_count
last_attempt_at
status
error_message
```

Do not rely only on in-memory queues.

If the application is terminated, pending synchronization work must not disappear.

---

# 13. Synchronization Reliability

Synchronization must support:

* Offline mode
* Online recovery
* Retry
* Timeout
* Partial failure
* Duplicate prevention
* Idempotency where supported
* Authentication expiration
* Server validation errors
* Conflict handling
* App restart recovery

Never assume:

```text
request started = request succeeded
```

Never remove a local pending operation until the server has confirmed successful processing.

---

# 14. Network Handling

Use `connectivity_plus` only as a connectivity signal.

Do not assume:

```text
Wi-Fi connected = Internet available
```

The actual API request determines server availability.

Handle:

```text
Connection timeout
Receive timeout
Send timeout
DNS failure
Connection failure
HTTP 4xx
HTTP 401
HTTP 403
HTTP 404
HTTP 409
HTTP 422
HTTP 429
HTTP 5xx
```

Convert technical exceptions into application-level failures before they reach the UI.

---

# 15. API Client

All HTTP communication must go through the centralized API client.

Do not instantiate `Dio` directly inside widgets, Bloc/Cubit, or feature pages.

Preferred:

```text
Feature Repository
       ↓
Remote Data Source
       ↓
ApiClient
       ↓
Dio
```

The API client is responsible for common HTTP concerns such as:

* Base URL
* Headers
* Authentication
* Timeouts
* Interceptors
* Request IDs if required
* Error normalization
* Token refresh
* Logging in development
* Response handling

---

# 16. API Versioning

The Flutter application must respect Laravel API versioning.

Example:

```text
/api/v1/...
```

Never hard-code unversioned production endpoints when a versioned API exists.

Do not duplicate endpoint strings throughout the application.

Prefer centralized route definitions or typed API methods.

---

# 17. Authentication

Authentication must be secure and offline-aware.

Access tokens must not be stored in plain shared preferences.

Use the existing secure storage infrastructure.

Authentication responsibilities:

```text
Auth
├── Login
├── Logout
├── Token persistence
├── Access token handling
├── Refresh token handling
├── Session restoration
├── Session expiration
└── Unauthorized recovery
```

Never log:

```text
access_token
refresh_token
password
PIN
secret keys
authorization headers
```

---

# 18. Token Refresh

When an API request receives an authentication expiration response:

```text
API request
   ↓
401
   ↓
Refresh token
   ↓
Store new token
   ↓
Retry original request
```

Avoid multiple simultaneous refresh requests.

Use a single refresh flow/lock where appropriate.

If refresh fails:

```text
Clear invalid authentication state
 ↓
Preserve safe local data
 ↓
Require authentication again
```

Never silently delete user data because authentication expired.

---

# 19. Data Models

Separate API models from domain/business models when the complexity justifies it.

Example:

```text
StudentApiModel
Student
```

API models represent backend payloads.

Domain models represent application/business concepts.

Do not let backend JSON structures leak unnecessarily into UI code.

Use explicit serialization:

```dart
factory StudentModel.fromJson(Map<String, dynamic> json);

Map<String, dynamic> toJson();
```

Validate required fields.

Handle nullable backend fields intentionally.

---

# 20. IDs

When the backend defines UUID/string identifiers, preserve them as strings.

Do not convert UUIDs to integers.

Example:

```dart
final String id;
```

Local records must use the same stable identity model whenever possible.

Do not generate a temporary ID that later changes unnecessarily.

Stable IDs are critical for offline synchronization.

---

# 21. Database Rules

The local database must be treated as durable application state.

Database access belongs in the data layer.

Do not access database tables directly from:

```text
Widget
Page
Bloc
Cubit
```

Use repositories/data sources.

Database migrations must be backward-aware.

Never casually delete local user data during:

```text
app update
database migration
authentication changes
sync failures
```

---

# 22. Repository Pattern

Repositories coordinate local and remote data sources.

Example:

```dart
abstract class StudentRepository {
  Stream<List<Student>> watchStudents();

  Future<void> createStudent(Student student);

  Future<void> updateStudent(Student student);

  Future<void> synchronize();
}
```

The repository decides whether data should come from:

```text
Local
Remote
Local + Remote synchronization
```

The UI should not make that decision.

---

# 23. Bloc/Cubit Standards

Use Bloc/Cubit for presentation/business state.

States should be explicit.

Prefer immutable states.

Example:

```text
initial
loading
success
failure
```

For offline-first features, consider richer states such as:

```text
loadingLocal
ready
syncing
syncSuccess
syncFailure
```

Do not overload one boolean:

```dart
isLoading
```

to represent every possible application state.

Events should represent user/application intent.

Avoid events such as:

```text
DoSomething
HandleEverything
UpdateState
```

Prefer:

```text
LoadStudents
CreateStudent
UpdateStudent
SyncStudents
RetrySync
```

---

# 24. Bloc Best Practices

Keep Bloc/Cubit focused.

Do not place:

* HTTP implementation
* SQL queries
* JSON parsing
* Secure storage implementation
* large business algorithms

directly inside Bloc/Cubit.

Bloc should coordinate use cases/repositories and expose state to the UI.

---

# 25. UI Standards

Widgets must remain presentation-focused.

Avoid large `build()` methods.

Extract reusable widgets when appropriate.

Prefer:

```text
Page
 ├── Header
 ├── Content
 ├── EmptyState
 ├── LoadingState
 └── ErrorState
```

Every data-driven page should intentionally handle:

```text
Loading
Success
Empty
Offline
Syncing
Error
```

Do not show a generic spinner indefinitely.

---

# 26. Offline UX

Offline status should be visible when relevant.

Use clear states such as:

```text
Offline
Changes pending
Syncing...
Synced
Sync failed
```

Do not block the entire application merely because the network is unavailable.

If a local operation succeeds but synchronization is pending, communicate that distinction clearly.

---

# 27. Error Handling

Never expose raw exceptions directly to users.

Bad:

```dart
Text(exception.toString())
```

Prefer application-level messages.

Example:

```text
Unable to connect to the server.
Your changes are saved locally and will be synchronized later.
```

Errors should be classified into appropriate categories:

```text
NetworkFailure
AuthenticationFailure
AuthorizationFailure
ValidationFailure
ServerFailure
DatabaseFailure
SynchronizationFailure
UnknownFailure
```

Use typed failures where appropriate.

---

# 28. Validation

Validate data before writing to local storage when possible.

Server validation remains authoritative.

Client validation must not be treated as a replacement for server validation.

Validation messages should be localized.

---

# 29. Localization

All user-visible strings must use the localization system.

Do not hard-code production UI text:

```dart
Text('Login failed')
```

Prefer generated localization:

```dart
Text(context.l10n.loginFailed)
```

Maintain:

```text
l10n/
└── arb/
```

when adding translations.

Do not place user-visible strings in Bloc/business logic unless they are localization-independent error codes.

---

# 30. Environment Configuration

The project supports environment-specific configurations.

Respect:

```text
development
staging
production
```

Do not hard-code production API URLs into feature code.

Use the existing environment configuration system.

Environment-specific values belong in configuration.

Never commit secrets.

---

# 31. Security

Never commit:

```text
.env
private keys
API secrets
passwords
tokens
refresh tokens
certificates
private credentials
```

Use `.env.example` for documentation.

Secure sensitive values using secure storage or platform-specific secure mechanisms.

Do not log sensitive information.

---

# 32. Logging

Development logging is allowed when useful.

Production logging must not expose:

```text
Tokens
Passwords
PINs
Personal sensitive information
Authorization headers
Full private API payloads
```

Use structured logs where practical.

Avoid excessive logging.

---

# 33. Dependency Management

Before adding a package:

1. Confirm that the functionality is genuinely required.
2. Check whether the project already has an equivalent capability.
3. Prefer stable and actively maintained packages.
4. Prefer packages compatible with the project's Flutter/Dart versions.
5. Avoid adding dependencies for trivial functionality.
6. Run tests and analysis after adding a package.

Do not replace existing project dependencies without a clear reason.

---

# 34. Testing Requirements

Every meaningful feature must include tests.

Required test categories where applicable:

```text
Unit Tests
Bloc/Cubit Tests
Repository Tests
Data Source Tests
Widget Tests
Integration Tests
```

Use existing project tooling such as:

```text
bloc_test
mocktail
flutter_test
```

Tests must verify behavior, not implementation details.

---

# 35. Offline-First Testing

Offline behavior is mandatory to test.

Every offline-capable feature should test at least:

```text
1. Read from local database
2. Create while offline
3. Update while offline
4. Pending synchronization
5. Reconnection
6. Successful synchronization
7. Synchronization failure
8. Retry
9. App restart with pending changes
```

Where applicable also test:

```text
10. Duplicate synchronization prevention
11. Conflict handling
12. Authentication expiration during sync
```

---

# 36. API Testing

For every API-integrated feature, test:

```text
200 success
201 creation
204 success where applicable
401 unauthorized
403 forbidden
404 not found
409 conflict
422 validation error
429 rate limiting
500 server error
Timeout
Network failure
Malformed response
```

Do not only test the happy path.

---

# 37. Widget Testing

Widget tests should verify user-visible behavior.

Examples:

```text
Loading state appears
Data appears
Empty state appears
Error appears
Retry works
Offline indicator appears
Sync status appears
Form validation works
Navigation works
```

Avoid snapshot-style tests unless they provide real value.

---

# 38. Code Generation

If code generation is introduced:

1. Use the project's established generator.
2. Commit generated files only when project convention requires them.
3. Never manually edit generated files.
4. Keep generated code reproducible.

Run the appropriate generator after model/schema changes.

---

# 39. Performance

Avoid unnecessary rebuilds.

Use:

```text
const
BlocSelector
buildWhen
select
memoization
pagination
lazy loading
```

where appropriate.

Do not optimize prematurely.

Measure before introducing complicated optimization.

Large local datasets should use efficient queries and pagination rather than loading everything into memory.

---

# 40. Pagination

When Laravel API pagination is used:

```text
Local pagination
+
Remote pagination
```

must be handled intentionally.

Never assume the API returns all records.

The repository should hide pagination mechanics from the UI where practical.

---

# 41. Synchronization Scheduling

Synchronization may occur:

```text
On application startup
On connectivity recovery
After local mutations
Manual refresh
Background scheduling where supported
```

Do not start uncontrolled parallel synchronization jobs.

Synchronization must be serialized or coordinated where data consistency requires it.

---

# 42. Concurrency

Avoid race conditions such as:

```text
Sync A starts
Sync B starts
Sync A updates record
Sync B overwrites record
```

Use appropriate locks, queues, transactions, or synchronization coordination.

Do not assume asynchronous operations execute in a safe order.

---

# 43. Database Transactions

When multiple local database writes represent one logical operation, use a transaction where supported.

Example:

```text
Create local record
+
Create sync queue item
```

These should not leave the application in an inconsistent state.

---

# 44. API Contract Discipline

The Laravel API is the contract.

When API behavior changes:

1. Inspect the backend.
2. Update Flutter models.
3. Update repositories/data sources.
4. Update Bloc/Cubit behavior.
5. Update UI.
6. Update tests.
7. Verify synchronization.
8. Verify offline behavior.

Never patch the Flutter client around an incorrect assumption about the API.

---

# 45. Feature Implementation Workflow

For every new feature:

## Step 1 — Analyze

Inspect:

```text
Existing Flutter architecture
Laravel endpoint
Request
Response
Authentication
Database requirements
Offline requirements
Existing reusable components
```

## Step 2 — Design

Define:

```text
Model
Local model
Remote model
Data source
Repository
Bloc/Cubit
UI
Sync behavior
Tests
```

## Step 3 — Implement

Implement in dependency order:

```text
Models
 ↓
Data Sources
 ↓
Repository
 ↓
Bloc/Cubit
 ↓
UI
 ↓
Synchronization
```

## Step 4 — Test

Run:

```bash
dart format .
flutter analyze
flutter test
```

Then perform manual offline/online verification.

---

# 46. Existing Code

When modifying existing code:

1. Preserve working behavior.
2. Follow existing architecture.
3. Refactor only when necessary.
4. Avoid unrelated changes.
5. Avoid large rewrites unless explicitly requested.
6. Keep commits logically focused.

Do not introduce a completely new state-management or architecture pattern into one feature without a strong reason.

---

# 47. Removing Demo Code

Very Good CLI starter/demo code should not remain in production features unless intentionally used.

Examples include:

```text
counter
demo screens
placeholder pages
sample data
unused generated code
```

Remove or replace them when the real application architecture is established.

Do not delete useful infrastructure merely because it originated from the template.

---

# 48. Import Rules

Prefer package imports for application code:

```dart
import 'package:flutter_app/...';
```

Avoid unnecessary relative imports across feature boundaries.

Use relative imports only where they improve local feature organization and remain consistent with the existing project style.

Avoid import cycles.

---

# 49. Public API of Features

Each feature should expose a small public surface.

Example:

```text
features/auth/auth.dart
```

can export the public components required by other features.

Do not import deeply nested implementation files from unrelated features unless necessary.

---

# 50. Comments

Write comments only when they explain:

* Why something is necessary.
* A non-obvious synchronization decision.
* A security constraint.
* A platform-specific workaround.
* A backend compatibility requirement.

Do not write comments that merely repeat the code.

Bad:

```dart
// Increment counter
counter++;
```

Good:

```dart
// The server may resend this operation after a timeout,
// so the request must remain idempotent.
```

---

# 51. Documentation

When introducing an important architectural decision, update the relevant documentation.

Document:

```text
API contract
Offline behavior
Synchronization rules
Database migrations
Environment setup
Platform-specific requirements
Known limitations
```

Documentation should remain synchronized with the implementation.

---

# 52. Git Discipline

Keep commits focused.

Preferred commit examples:

```text
feat(auth): add token refresh handling
feat(attendance): add offline attendance sync
fix(sync): prevent duplicate queue processing
test(auth): add refresh token tests
refactor(core): simplify api error handling
docs(flutter): document offline sync architecture
```

Do not mix unrelated features in one commit.

---

# 53. Definition of Done

A Flutter feature is not complete until:

* [ ] API contract verified
* [ ] Offline behavior implemented where required
* [ ] Local persistence implemented where required
* [ ] Repository implemented
* [ ] Bloc/Cubit implemented
* [ ] UI implemented
* [ ] Loading state implemented
* [ ] Empty state implemented
* [ ] Error state implemented
* [ ] Offline state handled
* [ ] Sync state handled
* [ ] Authentication handled
* [ ] Validation implemented
* [ ] Localization implemented
* [ ] Unit tests added
* [ ] Bloc/Cubit tests added where applicable
* [ ] Repository tests added where applicable
* [ ] Widget tests added where applicable
* [ ] `dart format .` passes
* [ ] `flutter analyze` passes
* [ ] `flutter test` passes
* [ ] Manual offline test completed
* [ ] Manual online synchronization test completed
* [ ] No secrets committed
* [ ] No unnecessary dependencies added
* [ ] No unrelated files modified

---

# 54. Forbidden Practices

Never:

* Put HTTP calls inside widgets.
* Put SQL/database queries inside widgets.
* Put business logic inside `build()`.
* Store tokens in plain text storage.
* Hard-code API URLs inside features.
* Hard-code user-visible strings.
* Ignore API errors.
* Assume internet connectivity guarantees API availability.
* Delete local data because synchronization failed.
* Drop pending sync operations after a timeout.
* Disable lint rules just to make analysis pass.
* Use `dynamic` unnecessarily.
* Add unnecessary dependencies.
* Duplicate API logic across repositories.
* Duplicate synchronization logic across features.
* Create global singleton state without justification.
* Bypass the repository layer.
* Log credentials or tokens.
* Ignore failing tests.
* Modify generated files manually.
* Introduce unrelated refactors while implementing a feature.

---

# 55. Agent Behavior

When working on this project, the coding agent MUST:

1. Read this `AGENTS.md` before making changes.
2. Inspect the existing implementation before creating new architecture.
3. Inspect the Laravel API before implementing API-dependent features.
4. Reuse existing services and infrastructure when appropriate.
5. Preserve offline-first behavior.
6. Prefer local-first UI behavior.
7. Add tests with meaningful feature changes.
8. Run formatter and analyzer.
9. Run the relevant test suite.
10. Report unresolved issues honestly.
11. Never claim a feature is complete without verification.
12. Avoid speculative architecture.
13. Avoid unnecessary rewrites.
14. Keep changes minimal, focused and production-ready.

---

# 56. Priority Order

When requirements conflict, use this priority:

```text
1. Correctness
2. Data integrity
3. Security
4. Offline-first reliability
5. API contract compatibility
6. Testability
7. Maintainability
8. Performance
9. Developer convenience
10. Cosmetic improvements
```

Never sacrifice data integrity or security for convenience.

---

# 57. Final Quality Gate

Before declaring work complete, verify:

```bash
dart format .
flutter analyze
flutter test
```

If Very Good CLI is available:

```bash
very_good analyze
very_good test
```

Then verify:

```text
ONLINE
  ↓
Feature works
  ↓
OFFLINE
  ↓
Feature still works locally
  ↓
ONLINE AGAIN
  ↓
Pending changes synchronize
  ↓
LOCAL DATA
  ↓
Remains consistent with server
```

The final implementation must be predictable, testable, maintainable and safe under both online and offline conditions.

---

# 58. Golden Rule

> **The Flutter application must remain useful without the network, synchronize safely when the network becomes available, and never compromise local data integrity or security for the sake of immediate API success.**

Follow this rule for every future Flutter feature unless a specific feature is inherently server-dependent.
