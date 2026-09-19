import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_app/auth/password_confirmation/cubit/password_confirmation_cubit.dart';
import 'package:flutter_app/core/errors/api_exception.dart';
import 'package:flutter_app/core/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;
  late PasswordConfirmationCubit cubit;

  setUp(() {
    repository = MockAuthRepository();
    cubit = PasswordConfirmationCubit(repository: repository);
  });

  tearDown(() {
    cubit.close();
  });

  group('PasswordConfirmationCubit', () {
    test('initial state is PasswordConfirmationInitial', () {
      expect(cubit.state, isA<PasswordConfirmationInitial>());
    });

    blocTest<PasswordConfirmationCubit, PasswordConfirmationState>(
      'emits [Submitting, Success] when confirm succeeds',
      build: () {
        when(() => repository.confirmPassword(password: 'Password1!'))
            .thenAnswer((_) async {});
        return PasswordConfirmationCubit(repository: repository);
      },
      act: (cubit) => cubit.confirmPassword('Password1!'),
      expect: () => [
        isA<PasswordConfirmationSubmitting>(),
        isA<PasswordConfirmationSuccess>(),
      ],
    );

    blocTest<PasswordConfirmationCubit, PasswordConfirmationState>(
      'emits [Submitting, Error] when password is wrong',
      build: () {
        when(() => repository.confirmPassword(password: 'wrong'))
            .thenThrow(const ValidationException(
          message: 'The provided password is incorrect.',
          errors: {'password': ['The provided password is incorrect.']},
        ));
        return PasswordConfirmationCubit(repository: repository);
      },
      act: (cubit) => cubit.confirmPassword('wrong'),
      expect: () => [
        isA<PasswordConfirmationSubmitting>(),
        predicate<PasswordConfirmationError>(
          (state) =>
              state.message ==
              'The provided password is incorrect.',
        ),
      ],
    );

    blocTest<PasswordConfirmationCubit, PasswordConfirmationState>(
      'reset() emits PasswordConfirmationInitial',
      build: () => PasswordConfirmationCubit(repository: repository),
      seed: () => const PasswordConfirmationError(message: 'err'),
      act: (cubit) => cubit.reset(),
      expect: () => [isA<PasswordConfirmationInitial>()],
    );
  });
}
