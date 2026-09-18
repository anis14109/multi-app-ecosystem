import 'package:equatable/equatable.dart';

import 'package:flutter_app/core/models/user_model.dart';

/// Base class for all authentication states.
///
/// The AuthBloc transitions through these states to represent
/// the current authentication status of the application.
sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any authentication check has been performed.
///
/// Shown briefly during app startup while checking stored credentials
/// and network connectivity.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Loading state during authentication operations.
///
/// Displayed while:
/// - Checking stored auth on app startup.
/// - Making login/register API calls.
/// - Verifying PIN or biometric authentication.
/// - Refreshing tokens.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// State when the user is not authenticated and has no stored credentials.
///
/// This is the terminal state for first-time users or after logout.
/// The UI should display the login/register screen.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// State when the user is authenticated and connected to the internet.
///
/// The user has valid tokens and the API is reachable. The app has
/// full access to both local and remote data. Background sync is
/// active and the UI should show all features.
class AuthenticatedOnline extends AuthState {
  const AuthenticatedOnline({required this.user});

  /// The authenticated user's profile data.
  final UserModel user;

  @override
  List<Object?> get props => [user];
}

/// State when the user has stored credentials but the app is locked.
///
/// The user was previously authenticated but the app requires
/// local re-authentication (PIN or biometric) before granting access.
/// This is shown when the app is reopened after being backgrounded,
/// or when there's no internet connection.
class AuthLocalLocked extends AuthState {
  const AuthLocalLocked({
    this.hasPin = false,
    this.biometricEnabled = false,
    this.biometricAvailable = false,
  });

  /// Whether the user has already set up a PIN.
  final bool hasPin;

  /// Whether biometric authentication has been enabled by the user.
  final bool biometricEnabled;

  /// Whether the device currently supports biometric authentication.
  final bool biometricAvailable;

  @override
  List<Object?> get props => [
        hasPin,
        biometricEnabled,
        biometricAvailable,
      ];
}

/// State when the user is authenticated and unlocked locally (offline mode).
///
/// The user has been verified via PIN or biometric and has access to
/// the local Drift database. Network features may be unavailable.
class AuthenticatedOffline extends AuthState {
  const AuthenticatedOffline({required this.user});

  /// The authenticated user's profile data (from local cache).
  final UserModel user;

  @override
  List<Object?> get props => [user];
}

/// State when the user needs to choose a local unlock method.
///
/// Shown after the first successful online authentication when no
/// unlock method (PIN or biometric) has been set up yet. The user
/// chooses between creating a 6-digit PIN or enabling biometric
/// authentication before the app can function offline.
class AuthSetupRequired extends AuthState {
  const AuthSetupRequired({
    this.biometricAvailable = false,
    this.email,
    this.name,
  });

  /// Whether the device supports biometric authentication.
  final bool biometricAvailable;

  /// User's email (carried forward from registration for UX).
  final String? email;

  /// User's name (carried forward from registration for UX).
  final String? name;

  @override
  List<Object?> get props => [biometricAvailable, email, name];
}

/// State when an authentication error has occurred.
///
/// Contains the error message to display to the user. The previous
/// state is preserved to enable returning to it after dismissal.
class AuthError extends AuthState {
  const AuthError({
    required this.message,
    required this.previousState,
  });

  /// Human-readable error message.
  final String message;

  /// The state to return to after the error is dismissed.
  final AuthState previousState;

  @override
  List<Object?> get props => [message, previousState];
}
