import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for securely storing sensitive authentication data on the device.
///
/// Uses [FlutterSecureStorage] which leverages:
/// - Android: EncryptedSharedPreferences (AES-256-GCM)
/// - iOS: Keychain (AES-256)
/// - macOS: Keychain
/// - Linux: libsecret
/// - Windows: Windows Credential Locker
///
/// Storage is split into two categories:
/// - **Server tokens** (access_token, refresh_token): Can be cleared
///   when tokens expire or refresh fails. The user can still unlock
///   the app offline with PIN/biometric.
/// - **Local auth data** (PIN hash, biometric flag, user data): NEVER
///   cleared by the interceptor. Only cleared on explicit logout.
class SecureStorageService {
  /// Creates a [SecureStorageService] with an optional custom
  /// [FlutterSecureStorage] instance for testing purposes.
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  // ── Storage Keys ──────────────────────────────────────────────────────
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _userEmailKey = 'user_email';
  static const String _hashedPinKey = 'hashed_pin';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _pinCreatedKey = 'pin_created';

  // ── Token Operations ──────────────────────────────────────────────────

  /// Persist the access and refresh tokens received from the API.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
    ]);
  }

  /// Retrieve the stored access token.
  Future<String?> getAccessToken() =>
      _storage.read(key: _accessTokenKey);

  /// Retrieve the stored refresh token.
  Future<String?> getRefreshToken() =>
      _storage.read(key: _refreshTokenKey);

  /// Update only the access token (used during token refresh).
  Future<void> updateAccessToken(String token) =>
      _storage.write(key: _accessTokenKey, value: token);

  /// Update only the refresh token (used during token rotation).
  Future<void> updateRefreshToken(String token) =>
      _storage.write(key: _refreshTokenKey, value: token);

  /// Check if a valid (non-empty) access token exists.
  Future<bool> hasAccessToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ── User Data Operations ──────────────────────────────────────────────

  /// Persist user profile data for offline access.
  Future<void> saveUserData({
    required int userId,
    required String name,
    required String email,
  }) async {
    await Future.wait([
      _storage.write(key: _userIdKey, value: userId.toString()),
      _storage.write(key: _userNameKey, value: name),
      _storage.write(key: _userEmailKey, value: email),
    ]);
  }

  /// Retrieve the stored user ID.
  Future<int?> getUserId() async {
    final id = await _storage.read(key: _userIdKey);
    return id != null ? int.tryParse(id) : null;
  }

  /// Retrieve the stored user name.
  Future<String?> getUserName() =>
      _storage.read(key: _userNameKey);

  /// Retrieve the stored user email.
  Future<String?> getUserEmail() =>
      _storage.read(key: _userEmailKey);

  // ── PIN Operations ────────────────────────────────────────────────────

  /// Persist the hashed PIN for local authentication.
  Future<void> saveHashedPin(String hashedPin) =>
      _storage.write(key: _hashedPinKey, value: hashedPin);

  /// Retrieve the stored hashed PIN for verification.
  Future<String?> getHashedPin() =>
      _storage.read(key: _hashedPinKey);

  /// Mark that the user has completed PIN setup.
  Future<void> markPinCreated() =>
      _storage.write(key: _pinCreatedKey, value: 'true');

  /// Check if the user has created a PIN.
  Future<bool> hasPinCreated() async {
    final value = await _storage.read(key: _pinCreatedKey);
    return value == 'true';
  }

  // ── Biometric Operations ──────────────────────────────────────────────

  /// Enable biometric authentication for local unlock.
  Future<void> enableBiometric() =>
      _storage.write(key: _biometricEnabledKey, value: 'true');

  /// Disable biometric authentication.
  Future<void> disableBiometric() =>
      _storage.write(key: _biometricEnabledKey, value: 'false');

  /// Check if biometric authentication is enabled.
  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _biometricEnabledKey);
    return value == 'true';
  }

  // ── Utility Operations ────────────────────────────────────────────────

  /// Check if the user has completed local unlock setup.
  ///
  /// This is the PRIMARY check for determining if the lock screen
  /// should be shown. It checks for user data and whether the user
  /// has at least one local unlock method (PIN **or** biometric),
  /// NOT the access token (which may have expired or been cleared
  /// by the interceptor).
  ///
  /// Returns `true` if:
  /// - User data exists (userId, name, email)
  /// - A PIN has been created OR biometric authentication is enabled
  Future<bool> hasCompletedLocalSetup() async {
    final userId = await getUserId();
    if (userId == null) return false;
    final hasPin = await hasPinCreated();
    if (hasPin) return true;
    return isBiometricEnabled();
  }

  /// Check if the user has any stored authentication data.
  ///
  /// Deprecated: Use [hasCompletedLocalSetup] instead.
  /// This checks for access token which may be cleared by the
  /// interceptor while local auth data is still valid.
  Future<bool> hasStoredAuth() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Clear ONLY server tokens (access + refresh).
  ///
  /// Called when the refresh token fails or tokens expire.
  /// Preserves PIN, biometric settings, and user data so the
  /// user can still unlock the app offline.
  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }

  /// Clear all stored data (tokens + local auth).
  ///
  /// Called ONLY during explicit logout. This fully resets the app.
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
