import 'package:dio/dio.dart';

import 'package:flutter_app/core/models/auth_response_model.dart';
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
  }

  /// Authenticate an existing user via the API.
  ///
  /// Throws [TwoFactorRequiredException] when the server asks for a
  /// two-factor challenge instead of issuing tokens.
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/login',
      data: {
        'email': email,
        'password': password,
        'device_name': _deviceName,
      },
    );

    return AuthResponseModel.fromJson(response.data!);
  }

  /// Refresh the access token using the stored refresh token.
  ///
  /// The Laravel endpoint expects the refresh token in the JSON body and
  /// rotates the token pair, so the new refresh token is persisted too.
  /// Returns the new access token.
  Future<String> refreshToken() async {
    final refreshToken = await _secureStorage.getRefreshToken();
    if (refreshToken == null) {
      throw Exception('No refresh token available');
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/refresh',
      data: {'refresh_token': refreshToken},
    );

    final data = response.data!['data'] as Map<String, dynamic>;
    final newAccessToken = data['access_token'] as String;
    final newRefreshToken = data['refresh_token'] as String;

    await _secureStorage.updateAccessToken(newAccessToken);
    await _secureStorage.updateRefreshToken(newRefreshToken);

    return newAccessToken;
  }

  /// Fetch the current user's profile from the API.
  ///
  /// The Laravel v1 `me` endpoint returns the `UserResource` directly in
  /// the `data` object (no `user` wrapper).
  Future<UserModel> getMe() async {
    final response = await _dio.get<Map<String, dynamic>>('/v1/auth/me');
    final data = response.data!['data'] as Map<String, dynamic>;
    return UserModel.fromJson(data);
  }

  /// Log out by revoking the current session on the server.
  Future<void> logout() async {
    try {
      await _dio.post<Map<String, dynamic>>('/v1/auth/logout');
    } on DioException {
      // Proceed with local cleanup even if server call fails.
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
