import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Parsed components of a Laravel permanent/signed email verification link.
///
/// The link has the shape:
/// ```text
/// https://host/api/v1/auth/email/verify/{id}/{hash}?expires=...&signature=...
/// ```
/// On mobile the link arrives inside the verification email as plain text;
/// the user pastes it, and [EmailVerificationLink.parse] extracts the
/// path parameters plus the `expires`/`signature` query values that the
/// `signed` middleware validates.
@immutable
class EmailVerificationLink extends Equatable {
  /// Creates an [EmailVerificationLink] instance.
  const EmailVerificationLink({
    required this.id,
    required this.hash,
    required this.expires,
    required this.signature,
  });

  static const String _marker = '/auth/email/verify/';

  /// Parse a verification URL (or plain URI with query) into parts.
  ///
  /// Returns `null` when the URL does not match the expected shape or is
  /// missing the `expires`/`signature` query parameters.
  static EmailVerificationLink? parse(String rawUrl) {
    final markerIndex = rawUrl.indexOf(_marker);
    if (markerIndex == -1) return null;

    final rest = rawUrl.substring(markerIndex + _marker.length);
    final queryIndex = rest.indexOf('?');
    final pathPart = queryIndex == -1 ? rest : rest.substring(0, queryIndex);
    final segments = pathPart.split('/');
    if (segments.length < 2) return null;

    final id = int.tryParse(segments[0]);
    final hash = segments[1];
    if (id == null || hash.isEmpty) return null;

    if (queryIndex == -1) return null;

    final query = rest.substring(queryIndex + 1);
    String? expires;
    String? signature;
    for (final pair in query.split('&')) {
      final equalsIndex = pair.indexOf('=');
      if (equalsIndex == -1) continue;
      final key = Uri.decodeComponent(pair.substring(0, equalsIndex));
      final value = Uri.decodeComponent(pair.substring(equalsIndex + 1));
      if (key == 'expires') expires = value;
      if (key == 'signature') signature = value;
    }
    if (expires == null || signature == null) return null;

    return EmailVerificationLink(
      id: id,
      hash: hash,
      expires: expires,
      signature: signature,
    );
  }

  /// The user ID from the verification path.
  final int id;

  /// The SHA-1 hash of the user email used as the path segment.
  final String hash;

  /// Unix timestamp after which the link is invalid.
  final String expires;

  /// HMAC signature produced by Laravel's signed URL helpers.
  final String signature;

  @override
  List<Object?> get props => [id, hash, expires, signature];
}

/// Result returned by the email verification endpoint.
///
/// `verified` is `true` when the address was successfully verified;
/// `emailVerifiedAt` carries the verification timestamp when known.
@immutable
class EmailVerificationResult extends Equatable {
  /// Creates an [EmailVerificationResult] instance.
  const EmailVerificationResult({
    required this.verified,
    this.emailVerifiedAt,
  });

  /// Creates a result from the `data` object of the response envelope.
  factory EmailVerificationResult.fromJson(Map<String, dynamic> json) {
    return EmailVerificationResult(
      verified: json['verified'] as bool? ?? false,
      emailVerifiedAt: json['email_verified_at'] as String?,
    );
  }

  /// Whether the email address is verified.
  final bool verified;

  /// ISO-8601 timestamp of the verification, when known.
  final String? emailVerifiedAt;

  @override
  List<Object?> get props => [verified, emailVerifiedAt];
}
