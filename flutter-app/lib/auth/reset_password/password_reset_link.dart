import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Parsed pieces of a Laravel password-reset link.
///
/// Laravel's password broker formats reset links as:
/// ```text
/// https://host/password/reset/{token}?email=user@example.com
/// ```
/// The app also tolerates the token passed alone, or as a `token=` query
/// parameter, so a user can paste the token or the full URL.
@immutable
class PasswordResetLink extends Equatable {
  /// Creates a [PasswordResetLink] instance.
  const PasswordResetLink({required this.token, this.email});

  static const String _pathMarker = '/password/reset/';

  /// Extract the reset token (and optional prefilled email) from a raw
  /// pasted URL or bare token string. Returns `null` when no token is found.
  static PasswordResetLink? parse(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;

    Uri? uri;
    try {
      uri = Uri.tryParse(trimmed);
    } on FormatException {
      uri = null;
    }

    String? token;
    String? email;

    if (uri != null && uri.hasScheme) {
      if (uri.path.contains(_pathMarker)) {
        final lastSegment = uri.pathSegments.isNotEmpty
            ? uri.pathSegments.last
            : null;
        if (lastSegment != null && lastSegment.isNotEmpty) {
          token = lastSegment;
        }
      }
      if (uri.hasQuery) {
        if (token == null && uri.queryParameters['token'] != null) {
          token = uri.queryParameters['token'];
        }
        email = uri.queryParameters['email'];
      }
    } else {
      // Bare token or plain token=value string.
      final queryIndex = trimmed.indexOf('token=');
      if (queryIndex != -1) {
        token = trimmed.substring(queryIndex + 'token='.length);
        final amp = token.indexOf('&');
        if (amp != -1) token = token.substring(0, amp);
        if (token.isEmpty) token = null;
      } else {
        token = trimmed;
      }
    }

    if (token == null || token.isEmpty) return null;
    return PasswordResetLink(token: token, email: email);
  }

  /// The reset token required by `POST /auth/reset-password`.
  final String token;

  /// Email prefilled from the reset link, when present.
  final String? email;

  @override
  List<Object?> get props => [token, email];
}
