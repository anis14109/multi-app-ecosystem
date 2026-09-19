import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_app/auth/email_verification/cubit/email_verification_cubit.dart';
import 'package:flutter_app/core/errors/api_exception.dart';
import 'package:flutter_app/core/models/email_verification.dart';
import 'package:flutter_app/core/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;
  late EmailVerificationCubit cubit;

  setUp(() {
    repository = MockAuthRepository();
    cubit = EmailVerificationCubit(repository: repository);
  });

  tearDown(() {
    cubit.close();
  });

  const validLink =
      'http://localhost/api/v1/auth/email/verify/1/abc123'
      '?expires=1735689600&signature=fakesig';

  group('EmailVerificationCubit', () {
    test('initial state is EmailVerificationInitial', () {
      expect(cubit.state, isA<EmailVerificationInitial>());
    });

    blocTest<EmailVerificationCubit, EmailVerificationState>(
      'emits [Verifying, Verified] when link is valid',
      build: () {
        when(() => repository.verifyEmail(
              id: 1,
              hash: 'abc123',
              expires: '1735689600',
              signature: 'fakesig',
            )).thenAnswer((_) async => const EmailVerificationResult(
              verified: true,
              emailVerifiedAt: '2025-01-01',
            ));
        return EmailVerificationCubit(repository: repository);
      },
      act: (cubit) => cubit.verifyLink(validLink),
      expect: () => [
        isA<EmailVerificationVerifying>(),
        predicate<EmailVerificationVerified>(
          (state) => state.result.verified,
        ),
      ],
    );

    blocTest<EmailVerificationCubit, EmailVerificationState>(
      'emits [Verifying, Error] when link is unparseable',
      build: () => EmailVerificationCubit(repository: repository),
      act: (cubit) => cubit.verifyLink('not-a-link'),
      expect: () => [
        isA<EmailVerificationError>(),
      ],
    );

    blocTest<EmailVerificationCubit, EmailVerificationState>(
      'emits [Verifying, Error] when API rejects the link',
      build: () {
        when(() => repository.verifyEmail(
              id: 1,
              hash: 'abc123',
              expires: '1735689600',
              signature: 'fakesig',
            )).thenThrow(const ApiException(
          message: 'Invalid verification link.',
          statusCode: 403,
        ));
        return EmailVerificationCubit(repository: repository);
      },
      act: (cubit) => cubit.verifyLink(validLink),
      expect: () => [
        isA<EmailVerificationVerifying>(),
        predicate<EmailVerificationError>(
          (state) => state.message == 'Invalid verification link.',
        ),
      ],
    );

    blocTest<EmailVerificationCubit, EmailVerificationState>(
      'emits [Resending, Resent] when resend succeeds',
      build: () {
        when(() => repository.resendVerificationEmail())
            .thenAnswer((_) async => false);
        return EmailVerificationCubit(repository: repository);
      },
      act: (cubit) => cubit.resend(),
      expect: () => [
        isA<EmailVerificationResending>(),
        predicate<EmailVerificationResent>(
          (state) =>
              !state.verified &&
              state.message.contains('verification email has been sent'),
        ),
      ],
    );

    blocTest<EmailVerificationCubit, EmailVerificationState>(
      'emits [Resending, ResendError] on rate limit',
      build: () {
        when(() => repository.resendVerificationEmail()).thenThrow(
          const RateLimitException(
            message: 'Too many requests.',
          ),
        );
        return EmailVerificationCubit(repository: repository);
      },
      act: (cubit) => cubit.resend(),
      expect: () => [
        isA<EmailVerificationResending>(),
        predicate<EmailVerificationResendError>(
          (state) => state.isRateLimit,
        ),
      ],
    );

    blocTest<EmailVerificationCubit, EmailVerificationState>(
      'reset() emits EmailVerificationInitial',
      build: () => EmailVerificationCubit(repository: repository),
      seed: () => const EmailVerificationError(message: 'err'),
      act: (cubit) => cubit.reset(),
      expect: () => [isA<EmailVerificationInitial>()],
    );
  });
}