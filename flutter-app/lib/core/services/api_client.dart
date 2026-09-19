import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_app/core/services/secure_storage_service.dart';

/// Dio HTTP client configured for the Laravel v1 API with automatic
/// token attachment and 401 handling.
///
/// The interceptor performs two critical functions:
/// 1. Automatically attaches the stored `access_token` as a Bearer
///    token on every outgoing request (except public endpoints).
/// 2. Intercepts 401 Unauthorized responses to attempt a silent token
///    refresh. Refresh requests are **single-flight**: simultaneous 401s
///    share one refresh future, so the rotating refresh token is used
///    only once per cycle (rotated refresh tokens must not be replayed,
///    or the whole token family is revoked server-side).
///
/// Failure policy (offline-first):
/// - The server rejected the refresh token (HTTP response) → both tokens
///   are cleared. PIN, biometric, and user data are preserved so the user
///   can still unlock the app offline.
/// - The refresh failed with a transport error (timeout / no connection)
///   → tokens are KEPT. Nothing proves they are dead; the next request
///   may succeed once the network recovers.
class ApiClient {
  /// Creates an [ApiClient] with the given [_secureStorage] and [baseUrl].
  ///
  /// The [baseUrl] is resolved from `.env` (flutter_dotenv) with a
  /// `--dart-define` fallback and passed through bootstrap.
  ApiClient({
    required this._secureStorage,
    required String baseUrl,
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
    _dio.interceptors.add(_AuthInterceptor(_secureStorage, _dio));
  }

  late final Dio _dio;
  final SecureStorageService _secureStorage;

  /// Underlying Dio instance for direct access if needed.
  Dio get dio => _dio;

  // ── Authentication ────────────────────────────────────────────────

  /// Register a new user account.
  Future<Response<Map<String, dynamic>>> register({
    required String name,
    required String email,
    required String password,
    String deviceName = 'Flutter App',
  }) {
    return _dio.post<Map<String, dynamic>>(
      '/v1/auth/register',
      data: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': password,
        'device_name': deviceName,
      },
    );
  }

  /// Authenticate an existing user.
  Future<Response<Map<String, dynamic>>> login({
    required String email,
    required String password,
    String deviceName = 'Flutter App',
  }) {
    return _dio.post<Map<String, dynamic>>(
      '/v1/auth/login',
      data: {
        'email': email,
        'password': password,
        'device_name': deviceName,
      },
    );
  }

  /// Refresh the access token using the stored refresh token.
  ///
  /// The Laravel endpoint expects the refresh token in the JSON body,
  /// NOT in an `Authorization` header, and rotates the token pair.
  Future<Response<Map<String, dynamic>>> refreshToken() async {
    final refreshToken = await _secureStorage.getRefreshToken();
    return _dio.post<Map<String, dynamic>>(
      '/v1/auth/refresh',
      data: {'refresh_token': refreshToken},
    );
  }

  // ── Profile & Sessions ────────────────────────────────────────────

  /// Fetch the authenticated user's profile.
  Future<Response<Map<String, dynamic>>> getMe() {
    return _dio.get<Map<String, dynamic>>('/v1/auth/me');
  }

  /// Log out by revoking the current session on the server.
  Future<Response<Map<String, dynamic>>> logout() {
    return _dio.post<Map<String, dynamic>>('/v1/auth/logout');
  }

  /// Revoke ALL sessions, including the current one.
  Future<Response<Map<String, dynamic>>> logoutAll() {
    return _dio.post<Map<String, dynamic>>('/v1/auth/logout-all');
  }

  // ── Password Reset ────────────────────────────────────────────────

  /// Request a password-reset link for the given email.
  ///
  /// Always returns 200 regardless of whether the account exists
  /// (prevents account enumeration).
  Future<Response<Map<String, dynamic>>> forgotPassword({
    required String email,
  }) {
    return _dio.post<Map<String, dynamic>>(
      '/v1/auth/forgot-password',
      data: {'email': email},
    );
  }

  /// Reset the password using the token from the reset email.
  ///
  /// Throws map-time errors when the token is invalid (422 `errors.token`).
  Future<Response<Map<String, dynamic>>> resetPassword({
    required String token,
    required String email,
    required String password,
  }) {
    return _dio.post<Map<String, dynamic>>(
      '/v1/auth/reset-password',
      data: {
        'token': token,
        'email': email,
        'password': password,
        'password_confirmation': password,
      },
    );
  }

  // ── Email Verification ────────────────────────────────────────────

  /// Verify an email address using the signed link parameters.
  ///
  /// The `expires` and `signature` query values are required by the
  /// `signed` middleware; `hash` is the SHA-1 of the email.
  Future<Response<Map<String, dynamic>>> verifyEmail({
    required int id,
    required String hash,
    required String expires,
    required String signature,
  }) {
    return _dio.get<Map<String, dynamic>>(
      '/v1/auth/email/verify/$id/$hash',
      queryParameters: {'expires': expires, 'signature': signature},
    );
  }

  /// Resend the email verification notification to the current user.
  ///
  /// Returns 429 when the resend throttle limit is hit.
  Future<Response<Map<String, dynamic>>> resendVerificationEmail() {
    return _dio.post<Map<String, dynamic>>(
      '/v1/auth/email/verification-notification',
    );
  }

  // ── Password Confirmation ─────────────────────────────────────────

  /// Confirm the current password (resets the password-confirm window).
  Future<Response<Map<String, dynamic>>> confirmPassword({
    required String password,
  }) {
    return _dio.post<Map<String, dynamic>>(
      '/user/confirm-password',
      data: {'password': password},
    );
  }
}

/// Dio Interceptor that handles token attachment and refresh logic.
///
/// Transparently attaches Bearer tokens to every request and handles
/// 401 responses by attempting a single token refresh before retrying.
///
/// IMPORTANT: This interceptor NEVER calls `clearAll()` on storage.
/// When a refresh is permanently rejected, only the two tokens are
/// cleared. The PIN hash, biometric settings, and user data are always
/// preserved so the user can still unlock the app offline.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._secureStorage, this._dio);

  final SecureStorageService _secureStorage;
  final Dio _dio;

  /// Extra key marking a request that was already retried once after a
  /// 401, preventing infinite refresh loops.
  static const String _retriedKey = '_auth_retried';

  /// Single-flight refresh future. All simultaneous 401 handlers await
  /// the same future; the rotating refresh token is used exactly once.
  Future<bool>? _refreshInFlight;

  /// Whether a request must not be sent with an Authorization header,
  /// because it is public or the refresh/joint-authentication loop itself.
  static bool _isPublicEndpoint(String path) {
    return path.contains('/auth/login') ||
        path.contains('/auth/register') ||
        path.contains('/auth/refresh') ||
        path.contains('/auth/forgot-password') ||
        path.contains('/auth/reset-password') ||
        path.contains('/auth/email/verify');
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isPublicEndpoint(options.path)) {
      return handler.next(options);
    }

    final token = await _secureStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final status = err.response?.statusCode;
    if (status == null || status != 401) {
      return handler.next(err);
    }

    final path = err.requestOptions.path;
    if (_isPublicEndpoint(path) ||
        err.requestOptions.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    try {
      final refreshed = await (_refreshInFlight ??= _tryRefresh());
      if (!refreshed) {
        return handler.next(err);
      }

      final token = await _secureStorage.getAccessToken();
      err.requestOptions.extra[_retriedKey] = true;
      if (token != null && token.isNotEmpty) {
        err.requestOptions.headers['Authorization'] = 'Bearer $token';
      }

      final retryResponse = await _dio.fetch<Map<String, dynamic>>(
        err.requestOptions,
      );
      return handler.resolve(retryResponse);
    } on Object {
      return handler.next(err);
    } finally {
      _refreshInFlight = null;
    }
  }

  /// Attempt to refresh the access token using the stored refresh token.
  ///
  /// Returns `true` when a new access token was persisted. Because the
  /// Laravel API rotates the refresh token too, the new refresh token is
  /// persisted and the fresh user profile is cached locally.
  ///
  /// On a permanent server rejection the tokens are cleared (offline
  /// unlock is preserved); on a transport failure they are left in place.
  Future<bool> _tryRefresh() async {
    final refreshToken = await _secureStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) return false;

      final newAccessToken = data['access_token'];
      final newRefreshToken = data['refresh_token'];
      if (newAccessToken is String && newAccessToken.isNotEmpty) {
        await _secureStorage.updateAccessToken(newAccessToken);
      }
      if (newRefreshToken is String && newRefreshToken.isNotEmpty) {
        await _secureStorage.updateRefreshToken(newRefreshToken);
      }

      final user = data['user'];
      if (user is Map<String, dynamic>) {
        final id = user['id'];
        final name = user['name'];
        final email = user['email'];
        if (id is int && name is String && email is String) {
          await _secureStorage.saveUserData(
            userId: id,
            name: name,
            email: email,
          );
        }
      }

      return newAccessToken is String && newAccessToken.isNotEmpty;
    } on DioException catch (error) {
      final isTransportFailure =
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError;

      if (error.response == null || isTransportFailure) {
        // Transient failure: the tokens may still be valid. Keep them so
        // a later request can refresh successfully.
        return false;
      }

      // The server responded and rejected our refresh token: the session
      // is permanently invalid. Clear the token pair, preserve local auth.
      await _secureStorage.clearTokens();
      return false;
    } on Object catch (error) {
      debugPrint('Auth refresh failed: $error');
      return false;
    }
  }
}
