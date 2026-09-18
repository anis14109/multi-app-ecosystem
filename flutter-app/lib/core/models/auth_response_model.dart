import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_app/core/models/user_model.dart';

/// Thrown when the API responds that two-factor authentication is required
/// before a token pair can be issued (e.g. `data.two_factor_required`).
class TwoFactorRequiredException implements Exception {
  const TwoFactorRequiredException([
    this.message = 'Two-factor authentication is required.',
  ]);

  final String message;

  @override
  String toString() => 'TwoFactorRequiredException: $message';
}

/// Data model for the authentication API response envelope.
///
/// Wraps the user data and the flat token pair returned by the login/register
/// and refresh endpoints. The current Laravel envelope shape is:
/// ```json
/// {
///   "success": true,
///   "message": "Login successful.",
///   "data": {
///     "user": { "id": 1, "name": "A", "email": "a@b.c", ... },
///     "access_token": "1|...",
///     "token_type": "Bearer",
///     "access_expires_at": "2026-...",
///     "refresh_token": "2|...",
///     "refresh_expires_at": "2026-...",
///     "session": { "id": "...", "current": true, ... }
///   }
/// }
/// ```
@immutable
class AuthResponseModel extends Equatable {
  /// Creates an [AuthResponseModel].
  const AuthResponseModel({
    required this.user,
    required this.tokens,
  });

  /// Parse from a full API response JSON (the envelope object).
  ///
  /// Throws [TwoFactorRequiredException] when the server requires a
  /// two-factor challenge instead of issuing a token pair.
  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;

    if (data['two_factor_required'] == true) {
      throw const TwoFactorRequiredException();
    }

    return AuthResponseModel(
      user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
      tokens: AuthTokens.fromJson(data),
    );
  }

  /// The authenticated user's profile data.
  final UserModel user;

  /// The token pair for API authentication.
  final AuthTokens tokens;

  @override
  List<Object?> get props => [user, tokens];

  @override
  String toString() => 'AuthResponseModel(user: $user, tokens: $tokens)';
}

/// Token pair containing access and refresh tokens.
///
/// The access token is short-lived (`ACCESS_TOKEN_TTL`, default 15 minutes)
/// and used for API requests. The refresh token is long-lived
/// (`REFRESH_TOKEN_TTL`, default 14 days) and rotates on every use to obtain
/// new access tokens without requiring re-authentication.
@immutable
class AuthTokens extends Equatable {
  /// Creates an [AuthTokens] instance.
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'Bearer',
    this.accessExpiresAt,
    this.refreshExpiresAt,
  });

  /// Parse from the `data` object of the API response.
  ///
  /// The Laravel v1 API places `access_token`, `refresh_token`, etc. at the
  /// top level of `data` (not nested under a `tokens` key).
  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: (json['token_type'] as String?) ?? 'Bearer',
      accessExpiresAt: json['access_expires_at'] as String?,
      refreshExpiresAt: json['refresh_expires_at'] as String?,
    );
  }

  /// Short-lived token for API request authorization.
  final String accessToken;

  /// Long-lived, rotating token for obtaining new access tokens.
  final String refreshToken;

  /// Token type prefix (always 'Bearer').
  final String tokenType;

  /// ISO-8601 timestamp when the access token expires.
  final String? accessExpiresAt;

  /// ISO-8601 timestamp when the refresh token expires.
  final String? refreshExpiresAt;

  @override
  List<Object?> get props => [
        accessToken,
        refreshToken,
        tokenType,
        accessExpiresAt,
        refreshExpiresAt,
      ];

  @override
  String toString() => 'AuthTokens(tokenType: $tokenType)';
}
