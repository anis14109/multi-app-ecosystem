import 'package:dio/dio.dart';

/// Typed exception hierarchy for errors raised by the Laravel v1 API.
///
/// Every exception carries:
/// - [message]: human-readable copy (server message or a local fallback).
/// - [statusCode]: HTTP status (0 for transport/network failures).
/// - [code]: Laravel `ApiErrorCode` value when the server sent one, e.g.
///   `INVALID_CREDENTIALS`, `TOKEN_EXPIRED`, `VALIDATION_ERROR`.
/// - [errors]: validation field → messages map for 422 responses.
///
/// Cubits and BLoCs catch these typed exceptions instead of raw
/// [DioException]s, which keeps the UI layer free of transport details.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    required this.statusCode,
    this.code,
    this.errors = const <String, List<String>>{},
  });

  /// Human-readable error message.
  final String message;

  /// HTTP status code; `0` for network/transport failures.
  final int statusCode;

  /// Optional Laravel error code (e.g. `INVALID_CREDENTIALS`).
  final String? code;

  /// Field → error messages map for validation failures.
  final Map<String, List<String>> errors;

  /// The first field error message, when any exists.
  String? get firstFieldError {
    for (final messages in errors.values) {
      if (messages.isNotEmpty) return messages.first;
    }
    return null;
  }

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, code: $code): $message';
}

/// HTTP 422 validation failure with field-level [ApiException.errors].
class ValidationException extends ApiException {
  const ValidationException({
    required super.message,
    super.statusCode = 422,
    super.code,
    super.errors,
  });
}

/// HTTP 401 — unauthenticated or invalid/expired credentials.
///
/// Encountered for login failures (`INVALID_CREDENTIALS`), revoked/expired
/// tokens, and reuse of a rotated refresh token (`TOKEN_REUSED`).
class AuthenticationException extends ApiException {
  const AuthenticationException({
    required super.message,
    super.statusCode = 401,
    super.code,
    super.errors,
  });
}

/// HTTP 403 — authenticated but not permitted.
///
/// Examples: `EMAIL_NOT_VERIFIED`, `PASSWORD_CONFIRMATION_REQUIRED`,
/// `FORBIDDEN`.
class AuthorizationException extends ApiException {
  const AuthorizationException({
    required super.message,
    super.statusCode = 403,
    super.code,
    super.errors,
  });
}

/// HTTP 429 — rate limited by the relevant Laravel throttle limiter.
class RateLimitException extends ApiException {
  const RateLimitException({
    required super.message,
    super.statusCode = 429,
    super.code,
    super.errors,
  });
}

/// Transport-level failure: no connection, DNS, send/receive timeout.
class NetworkException extends ApiException {
  const NetworkException({
    required super.message,
    super.statusCode = 0,
  });

  @override
  String toString() => 'NetworkException: $message';
}

/// HTTP 5xx — the server failed while processing the request.
class ServerException extends ApiException {
  const ServerException({
    required super.message,
    super.statusCode = 500,
    super.code,
  });
}

/// Maps a [DioException] to a typed [ApiException].
///
/// Understands the Laravel v1 error envelope:
/// `{ "success": false, "message": "...", "code": "...", "errors": {...} }`.
/// Transport failures (no response, timeouts) become [NetworkException] even
/// when they are not mapped to an HTTP status.
ApiException mapApiException(DioException error) {
  final response = error.response;
  final whetherTransportFailure =
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.connectionError;

  final data = response?.data;
  final message = _resolveMessage(error, data);
  final fieldErrors = _parseFieldErrors(data);
  final code = data is Map<String, dynamic> && data['code'] is String
      ? data['code'] as String
      : null;

  if (response == null || whetherTransportFailure) {
    return NetworkException(message: message);
  }

  final statusCode = response.statusCode ?? 0;
  switch (statusCode) {
    case 401:
      return AuthenticationException(
        message: message,
        code: code,
        errors: fieldErrors,
      );
    case 403:
      return AuthorizationException(
        message: message,
        code: code,
        errors: fieldErrors,
      );
    case 422:
      return ValidationException(
        message: message,
        code: code,
        errors: fieldErrors,
      );
    case 429:
      return RateLimitException(message: message, code: code);
    default:
      if (statusCode >= 500) {
        return ServerException(message: message, code: code);
      }
      return ApiException(
        message: message,
        statusCode: statusCode,
        code: code,
        errors: fieldErrors,
      );
  }
}

/// Pick the most useful message: server `message`, first field error,
/// then a type-specific fallback.
String _resolveMessage(DioException error, Object? data) {
  if (data is Map<String, dynamic>) {
    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message;
    }

    final errors = data['errors'];
    if (errors is Map<String, dynamic>) {
      for (final entry in errors.entries) {
        final value = entry.value;
        if (value is List && value.isNotEmpty) return '${value.first}';
        if (value is String && value.trim().isNotEmpty) return value;
      }
    }
  }

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'Connection timed out. Please try again.';
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
      return 'Unable to connect to the server. Please check your connection.';
    case DioExceptionType.cancel:
      return 'The request was cancelled.';
    case DioExceptionType.badResponse:
      return 'The server returned an unexpected response.';
    case DioExceptionType.transformTimeout:
    case DioExceptionType.unknown:
      return 'Something went wrong. Please try again.';
  }
}

/// Parse the Laravel `errors` map `{ field: [messages...] }` into a typed
/// map, tolerating single-string values and unexpected shapes.
Map<String, List<String>> _parseFieldErrors(Object? data) {
  if (data is! Map<String, dynamic>) return const {};
  final errors = data['errors'];
  if (errors is! Map<String, dynamic>) return const {};

  final parsed = <String, List<String>>{};
  for (final entry in errors.entries) {
    final value = entry.value;
    if (value is List) {
      parsed[entry.key] = value.map((item) => '$item').toList();
    } else if (value is String) {
      parsed[entry.key] = [value];
    }
  }
  return parsed;
}
