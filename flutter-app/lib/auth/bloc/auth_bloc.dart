import 'dart:async';
import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:flutter_app/auth/bloc/auth_event.dart';
import 'package:flutter_app/auth/bloc/auth_state.dart';
import 'package:flutter_app/core/errors/api_exception.dart';
import 'package:flutter_app/core/models/auth_response_model.dart';
import 'package:flutter_app/core/models/user_model.dart';
import 'package:flutter_app/core/repositories/auth_repository.dart';
import 'package:flutter_app/core/services/biometric_service.dart';
import 'package:flutter_app/core/services/network_info_service.dart';
import 'package:flutter_app/core/services/pin_hash_service.dart';
import 'package:flutter_app/core/services/secure_storage_service.dart';

/// BLoC managing the complete authentication lifecycle.
///
/// This BLoC follows an **offline-first** paradigm:
/// - Local database (secure storage) is the primary source of truth.
/// - Once authenticated online, the app works entirely offline.
/// - Lock screen verification is ALWAYS local (PIN hash / biometric).
/// - Network connectivity is checked IN THE BACKGROUND after local
///   verification to determine online/offline state.
///
/// Startup flow:
/// ```text
/// AuthStarted
///   ├─ No user data at all ──────> AuthUnauthenticated (first install)
///   ├─ Data, no PIN/biometric ───> AuthSetupRequired (choose method)
///   └─ Data + PIN/biometric ─────> AuthLocalLocked (show lock screen)
/// ```
///
/// Lock screen flow (offline-first):
/// ```text
/// AuthLocalLocked
///   ├─ Verify PIN locally ──> AuthLoading ──> check connectivity
///   │   ├─ Online  ──> AuthenticatedOnline
///   │   └─ Offline ──> AuthenticatedOffline
///   └─ Verify biometric locally > same as above
/// ```
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required this._authRepository,
    required this._secureStorage,
    required this._networkInfo,
    required this._pinHashService,
    required this._biometricService,
  }) : super(const AuthInitial()) {
    on<AuthStarted>(_onAuthStarted);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthPinVerified>(_onPinVerified);
    on<AuthBiometricVerified>(_onBiometricVerified);
    on<AuthPinCreated>(_onPinCreated);
    on<AuthBiometricEnabled>(_onBiometricEnabled);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthLogoutAllRequested>(_onLogoutAllRequested);
    on<AuthRefreshRequested>(_onRefreshRequested);
    on<AuthTokenExpired>(_onTokenExpired);
  }

  final AuthRepository _authRepository;
  final SecureStorageService _secureStorage;
  final NetworkInfoService _networkInfo;
  final PinHashService _pinHashService;
  final BiometricService _biometricService;

  /// Handles initial app startup.
  ///
  /// This is the CRITICAL offline-first check. It determines the
  /// initial screen based ONLY on local data:
  ///
  /// 1. No user data at all → [AuthUnauthenticated] (show login).
  ///    This only happens on fresh install or after explicit logout.
  ///
  /// 2. Has user data but no unlock method (PIN or biometric) →
  ///    [AuthSetupRequired]. User logged in online but hasn't set
  ///    up a local unlock method yet.
  ///
  /// 3. Has user data + PIN and/or biometric → [AuthLocalLocked].
  ///    Show the lock screen. This works 100% offline.
  ///
  /// IMPORTANT: This method NEVER makes API calls. Network
  /// connectivity is only checked AFTER the user unlocks locally.
  Future<void> _onAuthStarted(
    AuthStarted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      // Check if the user has completed local setup
      // (user data + a PIN or biometric method). This does NOT check
      // for access tokens — those may have expired or been cleared
      // by the interceptor, but the user can still unlock locally.
      final hasLocalSetup = await _secureStorage.hasCompletedLocalSetup();

      if (!hasLocalSetup) {
        // Check if this is a truly fresh install (no user data at all)
        // or if the user just hasn't set up an unlock method yet.
        final userId = await _secureStorage.getUserId();
        if (userId == null) {
          // No user data — this is a fresh install or after logout.
          return emit(const AuthUnauthenticated());
        }

        // Has user data but no unlock method — show the setup screen.
        final hasPin = await _secureStorage.hasPinCreated();
        final biometricEnabled = await _secureStorage.isBiometricEnabled();
        final biometricAvailable = await _biometricService
            .isBiometricAvailable();

        if (hasPin || biometricEnabled) {
          return emit(
            AuthLocalLocked(
              hasPin: hasPin,
              biometricEnabled: biometricEnabled,
              biometricAvailable: biometricAvailable,
            ),
          );
        }

        return emit(
          AuthSetupRequired(
            biometricAvailable: biometricAvailable,
            name: await _secureStorage.getUserName(),
            email: await _secureStorage.getUserEmail(),
          ),
        );
      }

      // User has completed local setup — show lock screen.
      // This works entirely offline. No API calls needed.
      final hasPin = await _secureStorage.hasPinCreated();
      final biometricEnabled = await _secureStorage.isBiometricEnabled();
      final biometricAvailable = await _biometricService.isBiometricAvailable();

      emit(
        AuthLocalLocked(
          hasPin: hasPin,
          biometricEnabled: biometricEnabled,
          biometricAvailable: biometricAvailable,
        ),
      );
    } on Object catch (e) {
      log('AuthStarted error: $e');
      // On error, still try to show lock screen if possible.
      // Only go to Unauthenticated as absolute last resort.
      try {
        final userId = await _secureStorage.getUserId();
        if (userId != null) {
          // Use the ACTUAL stored unlock flags so biometric-only users
          // are never shown a PIN screen they didn't set up.
          emit(await _buildLockState());
          return;
        }
      } on Object {
        // Ignore — fall through to Unauthenticated.
      }
      emit(const AuthUnauthenticated());
    }
  }

  /// Handles online login with email/password credentials.
  ///
  /// Calls the Laravel API, persists tokens and user data locally,
  /// and determines the next state based on local unlock setup status.
  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final authResponse = await _authRepository.login(
        email: event.email,
        password: event.password,
      );

      // Persist tokens and user data for offline access.
      await _authRepository.persistAuthLocally(authResponse);

      // Check if the user has set up any local unlock method.
      final hasPin = await _secureStorage.hasPinCreated();
      final biometricEnabled = await _secureStorage.isBiometricEnabled();
      if (!hasPin && !biometricEnabled) {
        final biometricAvailable = await _biometricService
            .isBiometricAvailable();
        return emit(
          AuthSetupRequired(
            biometricAvailable: biometricAvailable,
            email: authResponse.user.email,
            name: authResponse.user.name,
          ),
        );
      }

      // User already has a PIN set up — go directly to authenticated.
      emit(AuthenticatedOnline(user: authResponse.user));
    } on TwoFactorRequiredException catch (e) {
      emit(
        AuthError(
          message: e.message,
          previousState: const AuthUnauthenticated(),
        ),
      );
    } on ApiException catch (e) {
      emit(
        AuthError(
          message: e.message,
          previousState: const AuthUnauthenticated(),
        ),
      );
    } on DioException catch (e) {
      final message = _extractErrorMessage(e);
      emit(
        AuthError(
          message: message,
          previousState: const AuthUnauthenticated(),
        ),
      );
    } on Object catch (e) {
      log('Login error: $e');
      emit(
        const AuthError(
          message: 'An unexpected error occurred. Please try again.',
          previousState: AuthUnauthenticated(),
        ),
      );
    }
  }

  /// Handles online registration with name, email, and password.
  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final authResponse = await _authRepository.register(
        name: event.name,
        email: event.email,
        password: event.password,
      );

      // Persist tokens and user data for offline access.
      await _authRepository.persistAuthLocally(authResponse);

      // New users always need to choose a local unlock method.
      final biometricAvailable = await _biometricService.isBiometricAvailable();
      emit(
        AuthSetupRequired(
          biometricAvailable: biometricAvailable,
          email: authResponse.user.email,
          name: authResponse.user.name,
        ),
      );
    } on ApiException catch (e) {
      emit(
        AuthError(
          message: e.message,
          previousState: const AuthUnauthenticated(),
        ),
      );
    } on DioException catch (e) {
      final message = _extractErrorMessage(e);
      emit(
        AuthError(
          message: message,
          previousState: const AuthUnauthenticated(),
        ),
      );
    } on Object catch (e) {
      log('Register error: $e');
      emit(
        const AuthError(
          message: 'An unexpected error occurred. Please try again.',
          previousState: AuthUnauthenticated(),
        ),
      );
    }
  }

  /// Handles PIN verification on the lock screen.
  ///
  /// This is an **offline-first** operation:
  /// 1. Verify PIN against stored hash (100% local, no network).
  /// 2. IF verification succeeds, THEN check connectivity in background.
  /// 3. Transition to AuthenticatedOnline or AuthenticatedOffline.
  Future<void> _onPinVerified(
    AuthPinVerified event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final storedHash = await _secureStorage.getHashedPin();
      if (storedHash == null) {
        return emit(
          const AuthError(
            message: 'PIN not found. Please set up a new PIN.',
            previousState: AuthSetupRequired(),
          ),
        );
      }

      // LOCAL verification — no network needed.
      final isValid = _pinHashService.verifyPin(event.pin, storedHash);
      if (!isValid) {
        final hasPin = await _secureStorage.hasPinCreated();
        final biometricEnabled = await _secureStorage.isBiometricEnabled();
        final biometricAvailable = await _biometricService
            .isBiometricAvailable();
        return emit(
          AuthError(
            message: 'Incorrect PIN. Please try again.',
            previousState: AuthLocalLocked(
              hasPin: hasPin,
              biometricEnabled: biometricEnabled,
              biometricAvailable: biometricAvailable,
            ),
          ),
        );
      }

      // PIN is valid — determine online/offline from local data.
      await _emitAuthenticatedState(emit);
    } on Object catch (e) {
      log('PIN verification error: $e');
      try {
        emit(await _buildLockState());
      } on Object {
        emit(
          const AuthError(
            message: 'Verification failed. Please try again.',
            previousState: AuthLocalLocked(),
          ),
        );
      }
    }
  }

  /// Handles successful biometric authentication.
  ///
  /// Same offline-first pattern as PIN verification:
  /// biometric is verified by the OS locally, then we check
  /// connectivity to determine online/offline state.
  Future<void> _onBiometricVerified(
    AuthBiometricVerified event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      // Biometric is verified by the OS — 100% local.
      final authenticated = await _biometricService.authenticate();
      if (!authenticated) {
        // Return to the lock screen using the ACTUAL stored flags so a
        // user who never created a PIN is never shown a PIN keypad.
        return emit(await _buildLockState());
      }

      // Biometric is valid — determine online/offline from local data.
      await _emitAuthenticatedState(emit);
    } on Object catch (e) {
      log('Biometric verification error: $e');
      // Same as above: never hardcode `hasPin: true`. Emit the real
      // lock state so biometric-only users aren't sent to a PIN screen
      // they never set up.
      try {
        emit(await _buildLockState());
      } on Object {
        var hasPin = false;
        try {
          hasPin = await _secureStorage.hasPinCreated();
        } on Object {
          // Keep false — never assume a PIN exists.
        }
        emit(
          AuthError(
            message: 'Biometric verification failed.',
            previousState: AuthLocalLocked(
              hasPin: hasPin,
              biometricEnabled: true,
            ),
          ),
        );
      }
    }
  }

  /// Handles PIN creation during the setup flow.
  Future<void> _onPinCreated(
    AuthPinCreated event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      if (!_pinHashService.isValidPin(event.pin)) {
        return emit(
          const AuthError(
            message: 'PIN must be exactly 6 digits.',
            previousState: AuthSetupRequired(),
          ),
        );
      }

      final hashedPin = _pinHashService.hashPin(event.pin);
      await _secureStorage.saveHashedPin(hashedPin);
      await _secureStorage.markPinCreated();

      // PIN created — determine online/offline.
      await _emitAuthenticatedState(emit);
    } on Object catch (e) {
      log('PIN creation error: $e');
      emit(
        const AuthError(
          message: 'Failed to save PIN. Please try again.',
          previousState: AuthSetupRequired(),
        ),
      );
    }
  }

  /// Enables biometric as the chosen local unlock method.
  ///
  /// Persists the biometric preference in secure storage, then
  /// transitions directly to the authenticated state — the user
  /// does not need to create a PIN.
  Future<void> _onBiometricEnabled(
    AuthBiometricEnabled event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      await _secureStorage.enableBiometric();
      await _emitAuthenticatedState(emit);
    } on Object catch (e) {
      log('Enable biometric error: $e');
      emit(
        const AuthError(
          message: 'Failed to enable biometric. Please try again.',
          previousState: AuthSetupRequired(),
        ),
      );
    }
  }

  /// Handles user logout.
  ///
  /// Revokes tokens on the server and clears ALL local data
  /// (tokens, user data, PIN, biometric settings).
  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      await _authRepository.logout();
    } on Object catch (e) {
      log('Logout server call failed: $e');
    }

    await _secureStorage.clearAll();
    emit(const AuthUnauthenticated());
  }

  /// Handles "log out of all devices".
  ///
  /// Revokes every session on the server and clears ALL local data
  /// (tokens, user data, PIN, biometric settings) — identical local
  /// cleanup to a regular logout.
  Future<void> _onLogoutAllRequested(
    AuthLogoutAllRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      await _authRepository.logoutAll();
    } on Object catch (e) {
      log('Logout-all server call failed: $e');
    }

    await _secureStorage.clearAll();
    emit(const AuthUnauthenticated());
  }

  /// Handles profile refresh requests.
  ///
  /// Fetches the latest user profile from the API and re-emits the
  /// authenticated state so the UI stays in sync. On failure, an
  /// [AuthError] is emitted with the current state preserved.
  Future<void> _onRefreshRequested(
    AuthRefreshRequested event,
    Emitter<AuthState> emit,
  ) async {
    final current = state;
    try {
      final freshUser = await _authRepository.getMe();
      emit(AuthenticatedOnline(user: freshUser));
    } on ApiException catch (e) {
      emit(
        AuthError(
          message: e.message,
          previousState: current,
        ),
      );
    } on DioException catch (e) {
      emit(
        AuthError(
          message: _extractErrorMessage(e),
          previousState: current,
        ),
      );
    } on Object catch (e) {
      log('Profile refresh error: $e');
      emit(
        AuthError(
          message: 'Could not refresh your profile. Please try again.',
          previousState: current,
        ),
      );
    }
  }

  /// Handles token expiry.
  ///
  /// Clears ONLY the access token. The user can still unlock
  /// the app offline with PIN/biometric and will be shown as
  /// AuthenticatedOffline.
  Future<void> _onTokenExpired(
    AuthTokenExpired event,
    Emitter<AuthState> emit,
  ) async {
    await _secureStorage.clearTokens();
    // Don't go to Unauthenticated — check if local setup still exists.
    final hasPin = await _secureStorage.hasPinCreated();
    final biometricEnabled = await _secureStorage.isBiometricEnabled();
    final biometricAvailable = await _biometricService.isBiometricAvailable();
    if (hasPin || biometricEnabled) {
      emit(
        AuthLocalLocked(
          hasPin: hasPin,
          biometricEnabled: biometricEnabled,
          biometricAvailable: biometricAvailable,
        ),
      );
    } else {
      emit(const AuthUnauthenticated());
    }
  }

  /// Builds the correct lock/setup state from the CURRENTLY STORED flags.
  ///
  /// Used by error fallback paths so the app never guesses `hasPin`.
  /// A biometric-only user (no PIN stored) always gets `hasPin: false`
  /// and is never directed to a PIN keypad they didn't create.
  Future<AuthState> _buildLockState() async {
    final hasPin = await _secureStorage.hasPinCreated();
    final biometricEnabled = await _secureStorage.isBiometricEnabled();
    final biometricAvailable = await _biometricService.isBiometricAvailable();

    if (hasPin || biometricEnabled) {
      return AuthLocalLocked(
        hasPin: hasPin,
        biometricEnabled: biometricEnabled,
        biometricAvailable: biometricAvailable,
      );
    }

    return AuthSetupRequired(
      biometricAvailable: biometricAvailable,
      name: await _secureStorage.getUserName(),
      email: await _secureStorage.getUserEmail(),
    );
  }

  /// Determine the appropriate authenticated state based on local data.
  ///
  /// This is the OFFLINE-FIRST state determination:
  /// 1. Read user data from local secure storage (no network).
  /// 2. Check connectivity in the BACKGROUND.
  /// 3. If online, try to refresh user data from server.
  /// 4. If offline, use cached local data.
  ///
  /// The user is NEVER blocked on network checks. The state is
  /// emitted immediately with local data, and if we're online,
  /// we update with fresh server data when it arrives.
  Future<void> _emitAuthenticatedState(Emitter<AuthState> emit) async {
    try {
      final userId = await _secureStorage.getUserId();
      final userName = await _secureStorage.getUserName();
      final userEmail = await _secureStorage.getUserEmail();

      // Build user from local cache — this is always available.
      final user = UserModel(
        id: userId ?? 0,
        name: userName ?? 'User',
        email: userEmail ?? '',
      );

      // Check connectivity in the background.
      var isConnected = false;
      try {
        isConnected = await _networkInfo.isConnected();
      } on Object {
        // Network check failed — default to offline.
      }

      if (isConnected) {
        // Online: emit with local data immediately, then try
        // to update with fresh server data.
        emit(AuthenticatedOnline(user: user));

        // Background refresh — doesn't block the UI.
        try {
          final freshUser = await _authRepository.getMe();
          emit(AuthenticatedOnline(user: freshUser));
        } on Object {
          // Server call failed — keep using local data.
          // The user is still authenticated; just using cached data.
        }
      } else {
        // Offline: use local data only.
        emit(AuthenticatedOffline(user: user));
      }
    } on Object catch (e) {
      log('Emit authenticated state error: $e');
      // Even on error, try to show offline state if possible.
      try {
        final userId = await _secureStorage.getUserId();
        if (userId != null) {
          final user = UserModel(
            id: userId,
            name: await _secureStorage.getUserName() ?? 'User',
            email: await _secureStorage.getUserEmail() ?? '',
          );
          emit(AuthenticatedOffline(user: user));
          return;
        }
      } on Object {
        // Ignore — fall through.
      }
      emit(const AuthUnauthenticated());
    }
  }

  /// Extract a user-friendly error message from a [DioException].
  ///
  /// Understands the Laravel v1 error envelope
  /// `{ success: false, message, code, errors? }`:
  /// - Uses the server `message` when present.
  /// - Falls back to the first field error in `errors`.
  /// - Maps well-known `code` values to clearer copy.
  /// - Handles network/timeout failures.
  String _extractErrorMessage(DioException e) {
    final responseData = e.response?.data;
    if (responseData is Map<String, dynamic>) {
      final message = responseData['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }

      final errors = responseData['errors'];
      if (errors is Map<String, dynamic>) {
        for (final entry in errors.entries) {
          final values = entry.value;
          if (values is List && values.isNotEmpty) {
            return '${values.first}';
          }
          if (values is String && values.isNotEmpty) {
            return values;
          }
        }
      }
    }

    if (e.response?.statusCode == 429) {
      return 'Too many attempts. Please try again later.';
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Check your internet connection.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Unable to connect to the server. Please try again.';
    }
    return 'An error occurred. Please try again.';
  }
}
