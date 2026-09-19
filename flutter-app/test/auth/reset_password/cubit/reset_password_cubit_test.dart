import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_app/auth/reset_password/cubit/reset_password_cubit.dart';
import 'package:flutter_app/core/errors/api_exception.dart';
import 'package:flutter_app/core/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;
  late ResetPasswordCubit cubit;

  setUp(() {
    repository = MockAuthRepository();
    cubit = ResetPasswordCubit(repository: repository);
  });

  tearDown(() {
    cubit.close();
  });

  group('ResetPasswordCubit', () {
    test('initial state is ResetPasswordInitial', () {
      expect(cubit.state, isA<ResetPasswordInitial>());
    });

    blocTest<ResetPasswordCubit, ResetPasswordState>(
      'emits [Loading, Success] when resetPassword succeeds',
      build: () {
        when(() => repository.resetPassword(
              token: 'tok',
              email: 'a@b.c',
              password: 'Password1!',
            )).thenAnswer((_) async {});
        return ResetPasswordCubit(repository: repository);
      },
      act: (cubit) => cubit.resetPassword(
        token: 'tok',
        email: 'a@b.c',
        password: 'Password1!',
      ),
      expect: () => [
        isA<ResetPasswordLoading>(),
        isA<ResetPasswordSuccess>(),
      ],
    );

    blocTest<ResetPasswordCubit, ResetPasswordState>(
      'emits [Loading, Error] when token is invalid',
      build: () {
        when(() => repository.resetPassword(
              token: 'bad',
              email: 'a@b.c',
              password: 'p',
            )).thenThrow(const ValidationException(
          message: 'Invalid or expired reset token.',
          errors: {'token': ['Invalid or expired reset token.']},
        ));
        return ResetPasswordCubit(repository: repository);
      },
      act: (cubit) => cubit.resetPassword(
        token: 'bad',
        email: 'a@b.c',
        password: 'p',
      ),
      expect: () => [
        isA<ResetPasswordLoading>(),
        predicate<ResetPasswordError>(
          (state) =>
              state.message == 'Invalid or expired reset token.',
        ),
      ],
    );

    blocTest<ResetPasswordCubit, ResetPasswordState>(
      'reset() emits ResetPasswordInitial',
      build: () => ResetPasswordCubit(repository: repository),
      seed: () => const ResetPasswordError(message: 'err'),
      act: (cubit) => cubit.reset(),
      expect: () => [isA<ResetPasswordInitial>()],
    );
  });
}
