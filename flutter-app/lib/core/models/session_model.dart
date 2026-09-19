import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Data model for the session entry returned inside the login/register and
/// refresh payloads (matches the Laravel `SessionResource`).
///
/// A session represents one authenticated device. `current` is `true` for
/// the session that issued the token pair. Fields are nullable because the
/// resource shape varies across endpoints.
@immutable
class SessionModel extends Equatable {
  /// Creates a [SessionModel] instance.
  const SessionModel({
    required this.id,
    this.name,
    this.ipAddress,
    this.userAgent,
    this.current = false,
    this.lastUsedAt,
    this.revokedAt,
    this.createdAt,
  });

  /// Creates a [SessionModel] from a JSON map (API response).
  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: '${json['id']}',
      name: json['name'] as String?,
      ipAddress: json['ip_address'] as String?,
      userAgent: json['user_agent'] as String?,
      current: json['current'] as bool? ?? false,
      lastUsedAt: json['last_used_at'] as String?,
      revokedAt: json['revoked_at'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  /// Unique session identifier (string ULID).
  final String id;

  /// Human-readable device name (e.g. "Flutter App").
  final String? name;

  /// IP address the session last connected from.
  final String? ipAddress;

  /// User agent reported by the connected client.
  final String? userAgent;

  /// Whether this session is the one holding the current token pair.
  final bool current;

  /// ISO-8601 timestamp of the last activity on this session.
  final String? lastUsedAt;

  /// ISO-8601 timestamp when the session was revoked, if applicable.
  final String? revokedAt;

  /// ISO-8601 timestamp of session creation.
  final String? createdAt;

  @override
  List<Object?> get props => [
    id,
    name,
    ipAddress,
    userAgent,
    current,
    lastUsedAt,
    revokedAt,
    createdAt,
  ];

  @override
  String toString() => 'SessionModel(id: $id, name: $name, current: $current)';
}
