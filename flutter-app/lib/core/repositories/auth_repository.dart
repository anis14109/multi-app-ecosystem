import 'package:dio/dio.dart';

import 'package:flutter_app/core/errors/api_exception.dart';
import 'package:flutter_app/core/models/auth_response_model.dart';
import 'package:flutter_app/core/models/email_verification.dart';
import 'package:flutter_app/core/models/user_model.dart';
import 'package:flutter_app/core/services/secure_storage_service.dart';

/// Repository handling all authentication-related API calls and local
/// persistence.
///
/// This is the single source of truth for auth data flow:
/// - Online: Communicates with the Laravel v1 API via Dio.
/// - Offline: Reads/writes data to [SecureStorageService].
///
/// The AuthBloc delegates all data operations to this repository,
/// keeping the BLoC focused on state management and business logic.
///
/// Every request maps transport/HTTP failures to a typed [ApiException]
/// via [mapApiException], so callers never handle raw [DioException]s.
class AuthRepository {
  /// Creates an [AuthRepository] with the required service dependencies.
  AuthRepository({
    required this._secureStorage,
    required this._dio,
  });

  final SecureStorageService _secureStorage;
  final Dio _dio;

  /// Device name reported to the API when creating a session.
  static const String _deviceName = 'Flutter App';

  // ── Online API Operations ──────────────────────────────────────────

  /// Register a new user via the API.
  ///
  /// Sends registration credentials and returns the parsed auth response
  /// containing user data and the flat token pair.
  Future<AuthResponseModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/auth/register',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': password,
          'device_name': _deviceName,
        },
      );

      return AuthResponseModel.fromJson(response.data!);
    } on DioException catch (error) {
      throw mapApiException(error);
    }
  }

  /// Authenticate an existing user via the API.
  ///
  /// Throws [TwoFactorRequiredException] when the server asks for a
  /// two-factor challenge instead of issuing tokens; otherwise errors
  /// are mapped to typed [ApiException]s (e.g. [AuthenticationException]
  /// for `INVALID_CREDENTIALS`, [RateLimitException] for 429).
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/auth/login',
        data: {
          'email': email,
          'password': password,
          'device_name': _deviceName,
        },
      );

      return AuthResponseModel.fromJson(response.data!);
    } on DioException catch (error) {
      throw mapApiException(error);
    }
  }

  /// Refresh the access token using the stored refresh token.
  ///
  /// The Laravel endpoint expects the refresh token in the JSON body and
  /// rotates the token pair, so the new tokens AND the refreshed user
  /// profile are persisted locally. Returns the full refreshed response.
  Future<AuthResponseModel> refreshToken() async {
    final refreshToken = await _secureStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const AuthenticationException(
        message: 'No refresh token available',
      );
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final authResponse = AuthResponseModel.fromJson(response.data!);

      // Persist the rotated token pair and refreshed user data locally.
      await _secureStorage.updateAccessToken(authResponse.tokens.accessToken);
      await _secureStorage.updateRefreshToken(authResponse.tokens.refreshToken);
      await _secureStorage.saveUserData(
        userId: authResponse.user.id,
        name: authResponse.user.name,
        email: authResponse.user.email,
      );

      return authResponse;
    } on DioException catch (error) {
      throw mapApiException(error);
    }
  }

  /// Fetch the current user's profile from the API.
  ///
  /// The Laravel v1 `me` endpoint returns the `UserResource` directly in
  /// the `data` object (no `user` wrapper).
  Future<UserModel> getMe() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/v1/auth/me');
      final data = response.data!['data'] as Map<String, dynamic>;
      return UserModel.fromJson(data);
    } on DioException catch (error) {
      throw mapApiException(error);
    }
  }

  /// Log out by revoking the current session on the server.
  Future<void> logout() async {
    try {
      await _dio.post<Map<String, dynamic>>('/v1/auth/logout');
    } on DioException {
      // Proceed with local cleanup even if server call fails.
    }
  }

  /// Revoke ALL of the user's sessions, including the current one.
  Future<void> logoutAll() async {
    try {
      await _dio.post<Map<String, dynamic>>('/v1/auth/logout-all');
    } on DioException {
      // Proceed with local cleanup even if server call fails.
    }
  }

  /// Request a password-reset link for the given email.
  ///
  /// The server always returns 200 (same message) to prevent account
  /// enumeration, so a success here never proves the account exists.
  Future<void> forgotPassword({required String email}) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/v1/auth/forgot-password',
        data: {'email': email},
      );
    } on DioException catch (error) {
      throw mapApiException(error);
    }
  }

  /// Reset the password using the token from the reset email.
  Future<void> resetPassword({
    required String token,
    required String email,
    required String password,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/v1/auth/reset-password',
        data: {
          'token': token,
          'email': email,
          'password': password,
          'password_confirmation': password,
        },
      );
    } on DioException catch (error) {
      throw mapApiException(error);
    }
  }

  /// Verify an email address using the signed link parameters.
  Future<EmailVerificationResult> verifyEmail({
    required int id,
    required String hash,
    required String expires,
    required String signature,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/auth/email/verify/$id/$hash',
        queryParameters: {'expires': expires, 'signature': signature},
      );

      final data = response.data!['data'] as Map<String, dynamic>;
      return EmailVerificationResult.fromJson(data);
    } on DioException catch (error) {
      throw mapApiException(error);
    }
  }

  /// Resend the email verification notification for the current user.
  ///
  /// Returns `true` when the address has just been verified server-side
  /// (the endpoint reports `data.verified`).
  Future<bool> resendVerificationEmail() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/auth/email/verification-notification',
      );

      if (response.data?['data'] is Map<String, dynamic>) {
        final data = response.data!['data'] as Map<String, dynamic>;
        return data['verified'] as bool? ?? false;
      }
      return false;
    } on DioException catch (error) {
      throw mapApiException(error);
    }
  }

  /// Confirm the current password (resets the password-confirm window).
  Future<void> confirmPassword({required String password}) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/user/confirm-password',
        data: {'password': password},
      );
    } on DioException catch (error) {
      throw mapApiException(error);
    }
  }

  // ── Local Storage Operations ────────────────────────────────────────

  /// Persist authentication data locally for offline access.
  Future<void> persistAuthLocally(AuthResponseModel authResponse) async {
    await Future.wait([
      _secureStorage.saveTokens(
        accessToken: authResponse.tokens.accessToken,
        refreshToken: authResponse.tokens.refreshToken,
      ),
      _secureStorage.saveUserData(
        userId: authResponse.user.id,
        name: authResponse.user.name,
        email: authResponse.user.email,
      ),
    ]);
  }

  /// Check if the user has completed local setup (user data + PIN).
  ///
  /// This is the primary check for determining if the lock screen
  /// should be shown. Does NOT require a valid access token.
  Future<bool> hasCompletedLocalSetup() =>
      _secureStorage.hasCompletedLocalSetup();

  /// Get the stored user ID from local storage.
  Future<int?> getStoredUserId() => _secureStorage.getUserId();

  /// Clear only server tokens (preserves PIN, biometric, user data).
  Future<void> clearTokens() => _secureStorage.clearTokens();

  /// Clear ALL stored data (tokens + local auth).
  ///
  /// Called ONLY during explicit logout.
  Future<void> clearLocalAuth() => _secureStorage.clearAll();
}
