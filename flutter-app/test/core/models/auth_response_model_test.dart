import 'package:flutter_app/core/models/auth_response_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final loginResponse = {
    'success': true,
    'message': 'Login successful.',
    'data': {
      'user': {
        'id': 1,
        'name': 'Ada Lovelace',
        'email': 'ada@example.com',
      },
      'access_token': '1|access-token-value',
      'token_type': 'Bearer',
      'access_expires_at': '2026-09-01T00:15:00+00:00',
      'refresh_token': '2|refresh-token-value',
      'refresh_expires_at': '2026-09-15T00:00:00+00:00',
      'session': {
        'id': '01JXXXXX',
        'name': 'Flutter App',
        'current': true,
      },
    },
  };

  group('AuthResponseModel', () {
    test('parses the flat Laravel token envelope', () {
      final model = AuthResponseModel.fromJson(loginResponse);

      expect(model.user.id, 1);
      expect(model.user.name, 'Ada Lovelace');
      expect(model.tokens.accessToken, '1|access-token-value');
      expect(model.tokens.refreshToken, '2|refresh-token-value');
      expect(model.tokens.tokenType, 'Bearer');
      expect(model.tokens.accessExpiresAt, '2026-09-01T00:15:00+00:00');
      expect(model.tokens.refreshExpiresAt, '2026-09-15T00:00:00+00:00');
    });

    test('throws when two-factor authentication is required', () {
      final response = {
        'success': true,
        'message': 'Two-factor authentication is required.',
        'data': {
          'two_factor_required': true,
          'two_factor_token': '3|challenge-token',
          'user': {
            'id': 1,
            'name': 'Ada Lovelace',
            'email': 'ada@example.com',
          },
        },
      };

      expect(
        () => AuthResponseModel.fromJson(response),
        throwsA(isA<TwoFactorRequiredException>()),
      );
    });
  });
}
