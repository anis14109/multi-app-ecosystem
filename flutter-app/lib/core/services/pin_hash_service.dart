import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Service for hashing and verifying 6-digit PINs using SHA-256.
///
/// PINs are never stored in plaintext. Instead, a salted SHA-256 hash
/// is generated and stored locally. This prevents even root-level
/// access from recovering the original PIN.
///
/// The salt is a fixed application-specific value. For production use
/// with higher security requirements, consider using bcrypt or PBKDF2
/// with per-user random salts stored alongside the hash.
class PinHashService {
  /// Application-specific salt for PIN hashing.
  ///
  /// Adds a layer of protection against rainbow table attacks.
  static const String _salt = 'sirikotia_pin_salt_v1';

  /// Hash a 6-digit PIN string using SHA-256.
  ///
  /// The PIN is combined with the salt and converted to a
  /// hexadecimal digest string for storage.
  String hashPin(String pin) {
    final bytes = utf8.encode('$pin$_salt');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verify a PIN against a stored hash.
  ///
  /// Hashes the provided `pin` and compares it to the `storedHash`
  /// using constant-time comparison to prevent timing attacks.
  bool verifyPin(String pin, String storedHash) {
    final pinHash = hashPin(pin);
    // Constant-time comparison to prevent timing attacks.
    if (pinHash.length != storedHash.length) return false;
    var result = 0;
    for (var i = 0; i < pinHash.length; i++) {
      result |= pinHash.codeUnitAt(i) ^ storedHash.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Validate that a PIN string is exactly 6 digits.
  bool isValidPin(String pin) {
    final regex = RegExp(r'^\d{6}$');
    return regex.hasMatch(pin);
  }
}
