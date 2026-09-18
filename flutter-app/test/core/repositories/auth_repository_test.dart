import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_app/core/models/auth_response_model.dart';
import 'package:flutter_app/core/repositories/auth_repository.dart';
import 'package:flutter_app/core/services/secure_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory [SecureStorageService] subclass for hermetic tests.
class _FakeSecureStorage extends SecureStorageService {
  final Map<String, String> _store = {};

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _store['access_token'] = accessToken;
    _store['refresh_token'] = refreshToken;
  }

  @override
  Future<void> saveUserData({
    required int userId,
    required String name,
    required String email,
  }) async {
    _store['user_id'] = '$userId';
    _store['user_name'] = name;
    _store['user_email'] = email;
  }

  @override
  Future<String?> getAccessToken() async => _store['access_token'];

  @override
  Future<String?> getRefreshToken() async => _store['refresh_token'];

  @override
  Future<void> updateAccessToken(String token) async {
    _store['access_token'] = token;
  }

  @override
  Future<void> updateRefreshToken(String token) async {
    _store['refresh_token'] = token;
  }

  @override
  Future<int?> getUserId() async {
    final id = _store['user_id'];
    return id != null ? int.tryParse(id) : null;
  }
}

/// Minimal [HttpClientAdapter] backed by a canned response handler.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  Future<ResponseBody> Function(RequestOptions options) handler;
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, [int status = 200]) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
}

void main() {
  final loginEnvelope = {
    'success': true,
    'message': 'Login successful.',
    'data': {
      'user': {'id': 1, 'name': 'Ada Lovelace', 'email': 'ada@example.com'},
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

  late Dio dio;
  late _FakeAdapter adapter;
  late _FakeSecureStorage storage;
  late AuthRepository repository;

  setUp(() {
    adapter = _FakeAdapter((_) async => _json(loginEnvelope));
    storage = _FakeSecureStorage();
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api'))
      ..httpClientAdapter = adapter;
    repository = AuthRepository(secureStorage: storage, dio: dio);
  });

  group('AuthRepository', () {
    test('login parses the flat token envelope', () async {
      final model = await repository.login(
        email: 'ada@example.com',
        password: 'Password1!',
      );

      expect(model.user.email, 'ada@example.com');
      expect(model.tokens.accessToken, '1|access-token-value');
      expect(model.tokens.refreshToken, '2|refresh-token-value');

      final options = adapter.lastOptions!;
      expect(options.path, '/v1/auth/login');
      final body = options.data as Map<String, dynamic>;
      expect(body['device_name'], 'Flutter App');
    });

    test('persistAuthLocally stores tokens and user data', () async {
      final model = AuthResponseModel.fromJson(loginEnvelope);

      await repository.persistAuthLocally(model);

      expect(await storage.getAccessToken(), '1|access-token-value');
      expect(await storage.getRefreshToken(), '2|refresh-token-value');
      expect(await storage.getUserId(), 1);
    });

    test('register sends confirmation and device name', () async {
      await repository.register(
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        password: 'Password1!',
      );

      final options = adapter.lastOptions!;
      expect(options.path, '/v1/auth/register');
      final body = options.data as Map<String, dynamic>;
      expect(body['password_confirmation'], 'Password1!');
      expect(body['device_name'], 'Flutter App');
    });

    test('getMe parses the user directly from data', () async {
      adapter.handler = (_) async => _json({
            'success': true,
            'message': 'Authenticated user.',
            'data': {
              'id': 1,
              'name': 'Ada Lovelace',
              'email': 'ada@example.com',
              'email_verified_at': null,
              'two_factor_enabled': false,
            },
          });

      final user = await repository.getMe();

      expect(adapter.lastOptions!.path, '/v1/auth/me');
      expect(user.id, 1);
      expect(user.name, 'Ada Lovelace');
    });

    test('refreshToken sends the token in the body and rotates the pair',
        () async {
      await storage.saveTokens(
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
      );

      adapter.handler = (_) async => _json({
            'success': true,
            'message': 'Token refreshed.',
            'data': {
              'user': {
                'id': 1,
                'name': 'Ada Lovelace',
                'email': 'ada@example.com',
              },
              'access_token': 'new-access',
              'token_type': 'Bearer',
              'access_expires_at': '2026-09-01T00:15:00+00:00',
              'refresh_token': 'new-refresh',
              'refresh_expires_at': '2026-09-15T00:00:00+00:00',
            },
          });

      final newAccess = await repository.refreshToken();

      final options = adapter.lastOptions!;
      expect(options.path, '/v1/auth/refresh');
      final body = options.data as Map<String, dynamic>;
      expect(body['refresh_token'], 'old-refresh');
      expect(newAccess, 'new-access');
      expect(await storage.getAccessToken(), 'new-access');
      expect(await storage.getRefreshToken(), 'new-refresh');
    });

    test('getMe throws DioException on 401', () async {
      adapter.handler = (_) async => _json({
            'success': false,
            'message': 'Unauthenticated.',
            'code': 'UNAUTHENTICATED',
          }, 401);

      expect(
        () => repository.getMe(),
        throwsA(isA<DioException>()),
      );
    });
  });
}
