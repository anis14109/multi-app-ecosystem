import 'package:dio/dio.dart';
import 'package:flutter_app/core/errors/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapApiException', () {
    Response<dynamic> response(
      int? statusCode,
      Map<String, dynamic>? data,
    ) {
      return Response(
        requestOptions: RequestOptions(path: '/test'),
        statusCode: statusCode,
        data: data,
      );
    }

    DioException dioError({
      int? statusCode,
      Map<String, dynamic>? data,
      DioExceptionType type = DioExceptionType.badResponse,
    }) {
      return DioException(
        type: type,
        requestOptions: RequestOptions(path: '/test'),
        response: statusCode != null
            ? response(statusCode, data)
            : null,
        error: data,
      );
    }

    test('maps 401 to AuthenticationException', () {
      final error = dioError(
        statusCode: 401,
        data: {
          'success': false,
          'message': 'Unauthenticated.',
          'code': 'UNAUTHENTICATED',
        },
      );
      final result = mapApiException(error);
      expect(result, isA<AuthenticationException>());
      expect(result.message, 'Unauthenticated.');
      expect(result.code, 'UNAUTHENTICATED');
    });

    test('maps 422 to ValidationException with field errors', () {
      final error = dioError(
        statusCode: 422,
        data: {
          'success': false,
          'message': 'Validation failed.',
          'code': 'VALIDATION_ERROR',
          'errors': {
            'email': ['Email is required.'],
          },
        },
      );
      final result = mapApiException(error);
      expect(result, isA<ValidationException>());
      expect(result.errors['email'], ['Email is required.']);
      expect(result.firstFieldError, 'Email is required.');
    });

    test('maps 429 to RateLimitException', () {
      final error = dioError(statusCode: 429);
      final result = mapApiException(error);
      expect(result, isA<RateLimitException>());
    });

    test('maps 403 to AuthorizationException', () {
      final error = dioError(
        statusCode: 403,
        data: {'message': 'Email not verified.', 'code': 'EMAIL_NOT_VERIFIED'},
      );
      final result = mapApiException(error);
      expect(result, isA<AuthorizationException>());
    });

    test('maps 500 to ServerException', () {
      final error = dioError(statusCode: 500);
      final result = mapApiException(error);
      expect(result, isA<ServerException>());
    });

    test('maps connectionTimeout to NetworkException', () {
      final error = dioError(type: DioExceptionType.connectionTimeout);
      final result = mapApiException(error);
      expect(result, isA<NetworkException>());
    });

    test('maps missing response to NetworkException', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/test'),
      );
      final result = mapApiException(error);
      expect(result, isA<NetworkException>());
    });

    test('maps generic 400 to ApiException', () {
      final error = dioError(statusCode: 400);
      final result = mapApiException(error);
      expect(result.statusCode, 400);
      expect(result, isA<ApiException>());
    });

    test('prefers server message over field errors', () {
      final error = dioError(
        statusCode: 422,
        data: {
          'message': 'Invalid token.',
          'errors': {'token': ['Invalid token.']},
        },
      );
      final result = mapApiException(error);
      expect(result.message, 'Invalid token.');
    });

    test('uses first field error when message is absent', () {
      final error = dioError(
        statusCode: 422,
        data: {
          'errors': {'email': ['Required.']},
        },
      );
      final result = mapApiException(error);
      expect(result.message, 'Required.');
    });
  });

  group('ApiException', () {
    test('firstFieldError returns null when errors is empty', () {
      const error = ApiException(message: 'x', statusCode: 400);
      expect(error.firstFieldError, isNull);
    });

    test('firstFieldError returns first message', () {
      const error = ApiException(
        message: 'x',
        statusCode: 400,
        errors: {'field': ['msg1', 'msg2']},
      );
      expect(error.firstFieldError, 'msg1');
    });

    test('toString includes status code and message', () {
      const error = AuthenticationException(
        message: 'Nope',
        code: 'UNAUTHENTICATED',
      );
      expect(error.toString(), contains('401'));
      expect(error.toString(), contains('Nope'));
    });
  });
}
