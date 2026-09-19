import 'package:flutter_app/core/models/session_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SessionModel', () {
    test('parses a complete session JSON', () {
      final json = {
        'id': '01JXXXXX',
        'name': 'Flutter App',
        'ip_address': '192.168.1.1',
        'user_agent': 'Mozilla/5.0',
        'current': true,
        'last_used_at': '2025-09-01T00:00:00Z',
        'revoked_at': null,
        'created_at': '2025-09-01T00:00:00Z',
      };

      final model = SessionModel.fromJson(json);

      expect(model.id, '01JXXXXX');
      expect(model.name, 'Flutter App');
      expect(model.ipAddress, '192.168.1.1');
      expect(model.userAgent, 'Mozilla/5.0');
      expect(model.current, true);
      expect(model.lastUsedAt, '2025-09-01T00:00:00Z');
      expect(model.revokedAt, isNull);
      expect(model.createdAt, '2025-09-01T00:00:00Z');
    });

    test('handles minimal JSON with defaults', () {
      final model = SessionModel.fromJson(const {'id': 'abc'});

      expect(model.id, 'abc');
      expect(model.name, isNull);
      expect(model.current, false);
    });

    test('converts integer id to string', () {
      final model = SessionModel.fromJson(const {'id': 123});
      expect(model.id, '123');
    });

    test('equality based on all props', () {
      const a = SessionModel(id: '1', name: 'A', current: true);
      const b = SessionModel(id: '1', name: 'A', current: true);
      expect(a, equals(b));
    });
  });
}
