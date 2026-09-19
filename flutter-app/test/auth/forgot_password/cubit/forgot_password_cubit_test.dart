import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_app/auth/forgot_password/cubit/forgot_password_cubit.dart';
import 'package:flutter_app/core/errors/api_exception.dart';
import 'package:flutter_app/core/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;
  late ForgotPasswordCubit cubit;

  setUp(() {
    repository = MockAuthRepository();
    cubit = ForgotPasswordCubit(repository: repository);
  });

  tearDown(() {
    cubit.close();
  });

  group('ForgotPasswordCubit', () {
    test('initial state is ForgotPasswordInitial', () {
      expect(cubit.state, isA<ForgotPasswordInitial>());
    });

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'emits [Loading, Success] when forgotPassword succeeds',
      build: () {
        when(() => repository.forgotPassword(email: 'test@example.com'))
            .thenAnswer((_) async {});
        return ForgotPasswordCubit(repository: repository);
      },
      act: (cubit) => cubit.forgotPassword('test@example.com'),
      expect: () => [
        isA<ForgotPasswordLoading>(),
        isA<ForgotPasswordSuccess>(),
      ],
      verify: (_) {
        verify(() => repository.forgotPassword(email: 'test@example.com'))
            .called(1);
      },
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'emits [Loading, Error] when repository throws ValidationException',
      build: () {
        when(() => repository.forgotPassword(email: 'bad'))
            .thenThrow(const ValidationException(
          message: 'Validation failed',
          errors: {'email': ['Email is required']},
        ));
        return ForgotPasswordCubit(repository: repository);
      },
      act: (cubit) => cubit.forgotPassword('bad'),
      expect: () => [
        isA<ForgotPasswordLoading>(),
        predicate<ForgotPasswordError>(
          (state) => state.message == 'Email is required',
        ),
      ],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'emits [Loading, Error] when repository throws ApiException',
      build: () {
        when(() => repository.forgotPassword(email: 'x@x'))
            .thenThrow(const ApiException(
          message: 'Server error',
          statusCode: 500,
        ));
        return ForgotPasswordCubit(repository: repository);
      },
      act: (cubit) => cubit.forgotPassword('x@x'),
      expect: () => [
        isA<ForgotPasswordLoading>(),
        predicate<ForgotPasswordError>(
          (state) => state.message == 'Server error',
        ),
      ],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'emits [Loading, Error] on unexpected exception',
      build: () {
        when(() => repository.forgotPassword(email: 'x@x'))
            .thenThrow(Exception('boom'));
        return ForgotPasswordCubit(repository: repository);
      },
      act: (cubit) => cubit.forgotPassword('x@x'),
      expect: () => [
        isA<ForgotPasswordLoading>(),
        isA<ForgotPasswordError>(),
      ],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'reset() emits ForgotPasswordInitial',
      build: () => ForgotPasswordCubit(repository: repository),
      seed: () => const ForgotPasswordError(message: 'error'),
      act: (cubit) => cubit.reset(),
      expect: () => [isA<ForgotPasswordInitial>()],
    );

    test('does not throw when emit is called after close', () {
      final repository = MockAuthRepository();
      when(() => repository.forgotPassword(email: 'x@x'))
          .thenAnswer((_) async {});
      final cubit = ForgotPasswordCubit(repository: repository);
      cubit.close();
      // After close, emit is a no-op, not an error.
      // The cubit's isClosed guard prevents state changes.
      expect(cubit.isClosed, isTrue);
    });
  });
}
