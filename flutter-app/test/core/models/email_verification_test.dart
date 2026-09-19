import 'package:flutter_app/core/models/email_verification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmailVerificationLink', () {
    test('parses a valid signed verification URL', () {
      const url =
          'http://localhost/api/v1/auth/email/verify/42/abc123'
          '?expires=1735689600&signature=fakesignature';

      final link = EmailVerificationLink.parse(url);

      expect(link, isNotNull);
      expect(link!.id, 42);
      expect(link.hash, 'abc123');
      expect(link.expires, '1735689600');
      expect(link.signature, 'fakesignature');
    });

    test('returns null when URL lacks the verify marker', () {
      expect(
        EmailVerificationLink.parse('http://localhost/api/v1/auth/login'),
        isNull,
      );
    });

    test('returns null when expires is missing', () {
      const url =
          'http://localhost/api/v1/auth/email/verify/1/abc'
          '?signature=fakesig';
      expect(EmailVerificationLink.parse(url), isNull);
    });

    test('returns null when signature is missing', () {
      const url =
          'http://localhost/api/v1/auth/email/verify/1/abc'
          '?expires=1735689600';
      expect(EmailVerificationLink.parse(url), isNull);
    });

    test('returns null when id is not a number', () {
      const url =
          'http://localhost/api/v1/auth/email/verify/xyz/abc'
          '?expires=1&signature=2';
      expect(EmailVerificationLink.parse(url), isNull);
    });

    test('returns null for an empty string', () {
      expect(EmailVerificationLink.parse(''), isNull);
    });
  });

  group('EmailVerificationResult', () {
    test('parses from JSON', () {
      final result = EmailVerificationResult.fromJson(const {
        'verified': true,
        'email_verified_at': '2025-09-01',
      });
      expect(result.verified, true);
      expect(result.emailVerifiedAt, '2025-09-01');
    });

    test('defaults verified to false when absent', () {
      final result = EmailVerificationResult.fromJson(const {});
      expect(result.verified, false);
    });
  });
}
