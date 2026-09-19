import 'package:flutter_app/auth/reset_password/password_reset_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PasswordResetLink', () {
    test('parses a valid reset URL with token in path and email query', () {
      final link = PasswordResetLink.parse(
        'http://localhost/password/reset/abc123def?email=user@example.com',
      );
      expect(link, isNotNull);
      expect(link!.token, 'abc123def');
      expect(link.email, 'user@example.com');
    });

    test('parses a bare token string', () {
      final link = PasswordResetLink.parse('abc123def');
      expect(link, isNotNull);
      expect(link!.token, 'abc123def');
      expect(link.email, isNull);
    });

    test('parses token= query parameter format', () {
      final link = PasswordResetLink.parse('token=abc123');
      expect(link, isNotNull);
      expect(link!.token, 'abc123');
    });

    test('returns null for empty string', () {
      expect(PasswordResetLink.parse(''), isNull);
    });

    test('returns null when no token found', () {
      expect(PasswordResetLink.parse('http://localhost/login'), isNull);
    });

    test('strips ampersand from token= value', () {
      final link = PasswordResetLink.parse('token=abc123&other=value');
      expect(link!.token, 'abc123');
    });

    test('prefers path token over token= query', () {
      final link = PasswordResetLink.parse(
        'http://localhost/password/reset/pathToken?token=queryToken',
      );
      expect(link!.token, 'pathToken');
    });
  });
}
