import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Data model representing a user as exposed by the Laravel API
/// (`GET /api/v1/auth/me` → `UserResource`).
///
/// Used for offline caching of user profile data in secure storage
/// and for displaying user information throughout the app.
@immutable
class UserModel extends Equatable {
  /// Creates a [UserModel] instance.
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.emailVerifiedAt,
    this.twoFactorEnabled = false,
    this.profilePhotoUrl,
    this.createdAt,
    this.updatedAt,
  });

  /// Create a [UserModel] from a JSON map (API response).
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      emailVerifiedAt: json['email_verified_at'] as String?,
      twoFactorEnabled: json['two_factor_enabled'] as bool? ?? false,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  /// Unique user identifier from the server.
  final int id;

  /// User's display name.
  final String name;

  /// User's email address (unique).
  final String email;

  /// ISO-8601 timestamp of when the email was verified, if applicable.
  final String? emailVerifiedAt;

  /// Whether the user has two-factor authentication enabled.
  final bool twoFactorEnabled;

  /// URL of the user's profile photo, if one is set.
  final String? profilePhotoUrl;

  /// ISO-8601 timestamp of account creation.
  final String? createdAt;

  /// ISO-8601 timestamp of the last profile update.
  final String? updatedAt;

  /// Whether the account has a verified email address.
  bool get isEmailVerified => emailVerifiedAt != null;

  /// Convert to a JSON map for serialization.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'email_verified_at': emailVerifiedAt,
      'two_factor_enabled': twoFactorEnabled,
      'profile_photo_url': profilePhotoUrl,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  /// Create a copy with optional field overrides.
  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? emailVerifiedAt,
    bool? twoFactorEnabled,
    String? profilePhotoUrl,
    String? createdAt,
    String? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    email,
    emailVerifiedAt,
    twoFactorEnabled,
    profilePhotoUrl,
    createdAt,
    updatedAt,
  ];

  @override
  String toString() => 'UserModel(id: $id, name: $name, email: $email)';
}
