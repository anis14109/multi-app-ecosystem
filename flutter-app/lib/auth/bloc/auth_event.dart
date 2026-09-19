import 'package:equatable/equatable.dart';

/// Base class for all authentication-related events.
///
/// Events are the only way to interact with the AuthBloc.
/// Each event represents a user action or system trigger that
/// causes a state transition in the authentication flow.
sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered when the app first launches to determine initial auth state.
///
/// Checks for stored authentication data and connectivity to decide
/// whether to show the login screen, lock screen, or main app.
class AuthStarted extends AuthEvent {
  const AuthStarted();
}

/// Triggered when the user submits the login form.
///
/// Contains the email and password credentials to authenticate
/// against the Laravel API.
class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

/// Triggered when the user submits the registration form.
///
/// Contains the full name, email, and password for new account creation.
class AuthRegisterRequested extends AuthEvent {
  const AuthRegisterRequested({
    required this.name,
    required this.email,
    required this.password,
  });

  final String name;
  final String email;
  final String password;

  @override
  List<Object?> get props => [name, email, password];
}

/// Triggered when the user submits a PIN for local authentication.
///
/// The PIN is verified against the stored hash. If it matches,
/// the state transitions to `AuthenticatedOffline`.
class AuthPinVerified extends AuthEvent {
  const AuthPinVerified({required this.pin});

  final String pin;

  @override
  List<Object?> get props => [pin];
}

/// Triggered when the user completes biometric authentication.
///
/// Called after `local_auth` successfully authenticates via
/// fingerprint or face recognition.
class AuthBiometricVerified extends AuthEvent {
  const AuthBiometricVerified();
}

/// Triggered when the user creates a new 6-digit PIN during setup.
///
/// The PIN is hashed and stored locally for future offline authentication.
class AuthPinCreated extends AuthEvent {
  const AuthPinCreated({required this.pin});

  final String pin;

  @override
  List<Object?> get props => [pin];
}

/// Triggered when the user chooses to enable biometric authentication.
///
/// Stores the biometric preference in secure storage so the lock screen
/// can offer biometric as the default unlock method.
class AuthBiometricEnabled extends AuthEvent {
  const AuthBiometricEnabled();
}

/// Triggered when the user explicitly logs out.
///
/// Revokes all tokens on the server and clears local storage.
class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Triggered when the user revokes ALL of their sessions ("logout all").
///
/// Revokes every session on the server (`POST /auth/logout-all`), then
/// clears local storage exactly like an explicit logout.
class AuthLogoutAllRequested extends AuthEvent {
  const AuthLogoutAllRequested();
}

/// Triggered when the user requests a fresh copy of their profile.
///
/// Fetches the latest user data from the API and updates the
/// authenticated state so the UI (e.g. profile page) stays in sync.
class AuthRefreshRequested extends AuthEvent {
  const AuthRefreshRequested();
}

/// Internal event triggered when the refresh token is also invalid.
///
/// Forces a transition to `Unauthenticated` regardless of the
/// current connectivity state.
class AuthTokenExpired extends AuthEvent {
  const AuthTokenExpired();
}
