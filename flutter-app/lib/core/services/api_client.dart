import 'package:dio/dio.dart';

import 'package:flutter_app/core/services/secure_storage_service.dart';

/// Dio HTTP client configured for the Laravel v1 API with automatic
/// token attachment and 401 handling.
///
/// The interceptor performs two critical functions:
/// 1. Automatically attaches the stored `access_token` as a Bearer
///    token on every outgoing request.
/// 2. Intercepts 401 Unauthorized responses to attempt a silent token
///    refresh. If the refresh fails, only the access token is cleared
///    — local PIN, biometric settings, and user data are preserved
///    so the user can still unlock the app offline.
///
/// The Laravel refresh endpoint rotates BOTH tokens, so every successful
/// refresh persists the new access token AND the new refresh token.
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

  /// Fetch the authenticated user's profile.
  Future<Response<Map<String, dynamic>>> getMe() {
    return _dio.get<Map<String, dynamic>>('/v1/auth/me');
  }

  /// Log out by revoking the current session on the server.
  Future<Response<Map<String, dynamic>>> logout() {
    return _dio.post<Map<String, dynamic>>('/v1/auth/logout');
  }
}

/// Dio Interceptor that handles token attachment and refresh logic.
///
/// Transparently attaches Bearer tokens to every request and handles
/// 401 responses by attempting a single token refresh before retrying.
///
/// IMPORTANT: This interceptor NEVER calls `clearAll()` on storage.
/// When a refresh fails, only the access token is cleared. The PIN hash,
/// biometric settings, and user data are always preserved so the user
/// can still unlock the app offline even if their tokens have expired.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._secureStorage, this._dio);

  final SecureStorageService _secureStorage;
  final Dio _dio;

  /// Flag to prevent multiple simultaneous refresh attempts.
  bool _isRefreshing = false;

  /// Queue of requests waiting for token refresh.
  final List<_PendingRequest> _pendingRequests = [];

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip token attachment for public endpoints.
    final path = options.path;
    if (path.contains('/auth/login') ||
        path.contains('/auth/register') ||
        path.contains('/auth/refresh') ||
        path.contains('/auth/forgot-password') ||
        path.contains('/auth/reset-password') ||
        path.contains('/auth/email/verify')) {
      return handler.next(options);
    }

    // Attach the access token from secure storage.
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
    // Only handle 401 errors that aren't from the refresh endpoint itself.
    if (err.response?.statusCode == 401 &&
        !err.requestOptions.path.contains('/auth/refresh')) {
      // If already refreshing, queue this request.
      if (_isRefreshing) {
        _pendingRequests.add(_PendingRequest(err.requestOptions, handler));
        return;
      }

      _isRefreshing = true;

      try {
        // Attempt to refresh the access token.
        final refreshResponse = await _refreshAccessToken();

        if (refreshResponse != null) {
          // Retry the original request with the new token.
          err.requestOptions.headers['Authorization'] =
              'Bearer $refreshResponse';
          final retryResponse =
              await _dio.fetch<Map<String, dynamic>>(err.requestOptions);
          return handler.resolve(retryResponse);
        }

        // Refresh failed — clear ONLY the access token.
        // Preserve PIN, biometric settings, and user data for offline unlock.
        await _secureStorage.updateAccessToken('');
        return handler.next(err);
      } on DioException {
        // Refresh request itself failed — clear ONLY the access token.
        await _secureStorage.updateAccessToken('');
        return handler.next(err);
      } finally {
        _isRefreshing = false;

        // Retry all queued requests with the new token.
        final currentToken = await _secureStorage.getAccessToken();
        for (final pending in _pendingRequests) {
          if (currentToken != null && currentToken.isNotEmpty) {
            pending.requestOptions.headers['Authorization'] =
                'Bearer $currentToken';
          }
          try {
            final response =
                await _dio.fetch<Map<String, dynamic>>(pending.requestOptions);
            pending.handler.resolve(response);
          } on DioException catch (e) {
            pending.handler.next(e);
          }
        }
        _pendingRequests.clear();
      }
    }

    return handler.next(err);
  }

  /// Attempt to refresh the access token using the stored refresh token.
  ///
  /// Returns the new access token on success, or `null` on failure.
  /// Because the Laravel API rotates the refresh token too, the new
  /// refresh token is persisted so the next refresh keeps working.
  Future<String?> _refreshAccessToken() async {
    final refreshToken = await _secureStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;

    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/refresh',
      data: {'refresh_token': refreshToken},
    );

    final data = response.data?['data'] as Map<String, dynamic>?;
    final newAccessToken = data?['access_token'] as String?;
    final newRefreshToken = data?['refresh_token'] as String?;

    if (newAccessToken != null && newAccessToken.isNotEmpty) {
      await _secureStorage.updateAccessToken(newAccessToken);
    }
    if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
      await _secureStorage.updateRefreshToken(newRefreshToken);
    }

    return newAccessToken;
  }
}

/// Represents a request that was queued during a token refresh.
class _PendingRequest {
  _PendingRequest(this.requestOptions, this.handler);

  final RequestOptions requestOptions;
  final ErrorInterceptorHandler handler;
}
