import 'package:flutter_app/core/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserModel', () {
    test('parses the Laravel UserResource JSON', () {
      final user = UserModel.fromJson(const {
        'id': 42,
        'name': 'Ada Lovelace',
        'email': 'ada@example.com',
        'email_verified_at': '2026-09-01T10:00:00+00:00',
        'two_factor_enabled': true,
        'profile_photo_url': 'https://example.com/ada.png',
        'created_at': '2026-09-01T00:00:00+00:00',
        'updated_at': '2026-09-10T00:00:00+00:00',
      });

      expect(user.id, 42);
      expect(user.name, 'Ada Lovelace');
      expect(user.email, 'ada@example.com');
      expect(user.isEmailVerified, isTrue);
      expect(user.twoFactorEnabled, isTrue);
      expect(user.profilePhotoUrl, 'https://example.com/ada.png');
      expect(user.createdAt, isNotNull);
    });

    test('defaults to unverified user when fields are absent', () {
      final user = UserModel.fromJson(const {
        'id': 1,
        'name': 'Grace',
        'email': 'grace@example.com',
      });

      expect(user.id, 1);
      expect(user.isEmailVerified, isFalse);
      expect(user.twoFactorEnabled, isFalse);
      expect(user.profilePhotoUrl, isNull);
      expect(user.createdAt, isNull);
      expect(user.updatedAt, isNull);
    });

    test('copyWith overrides only the provided fields', () {
      const user = UserModel(id: 1, name: 'A', email: 'a@b.c');

      final updated = user.copyWith(name: 'B', twoFactorEnabled: true);

      expect(updated.name, 'B');
      expect(updated.email, 'a@b.c');
      expect(updated.twoFactorEnabled, isTrue);
      expect(updated.id, 1);
    });

    test('toJson round-trips parsed values', () {
      final user = UserModel.fromJson(const {
        'id': 7,
        'name': 'Nikola',
        'email': 'nikola@example.com',
      });

      final restored = UserModel.fromJson(user.toJson());

      expect(restored.id, user.id);
      expect(restored.name, user.name);
      expect(restored.email, user.email);
    });
  });
}
