import 'dart:developer';

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Service wrapping the `local_auth` plugin for biometric authentication.
///
/// Provides a simplified interface for checking biometric availability
/// and authenticating the user via fingerprint or face recognition.
/// This is used as an alternative to PIN entry on the lock screen.
class BiometricService {
  /// Creates a [BiometricService] with an optional [LocalAuthentication]
  /// instance for testing purposes.
  BiometricService({LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  /// Check if the device supports biometric authentication.
  ///
  /// Returns `true` if the device has fingerprint, face, or iris
  /// recognition hardware available.
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  /// Check if any biometric authentication methods are enrolled.
  ///
  /// Returns `true` if the user has set up at least one biometric
  /// (fingerprint, face, etc.) on the device.
  Future<bool> isBiometricAvailable() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      if (!isSupported) return false;

      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  /// Get the list of enrolled biometric types on the device.
  ///
  /// Returns a list of [BiometricType] values indicating which
  /// biometric methods are available (fingerprint, face, iris).
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Prompt the user for biometric authentication.
  ///
  /// Shows the system biometric dialog (fingerprint/face) and returns
  /// `true` if authentication succeeds, `false` if the user cancels
  /// or authentication fails.
  ///
  /// The [reason] parameter is displayed in the system dialog to
  /// explain why authentication is needed.
  Future<bool> authenticate({
    String reason = 'Authenticate to unlock the app',
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
        ),
      );
    } on PlatformException catch (e) {
      // Log the real failure (e.g. lockout, not enrolled, permission
      // missing) so silent "no popup" issues are diagnosable.
      log(
        'Biometric authenticate failed: '
        '${e.code} — ${e.message}',
      );
      return false;
    }
  }
}
