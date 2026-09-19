import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_app/core/errors/api_exception.dart';
import 'package:flutter_app/core/models/email_verification.dart';
import 'package:flutter_app/core/repositories/auth_repository.dart';

/// States for the email-verification flow.
sealed class EmailVerificationState extends Equatable {
  const EmailVerificationState();

  @override
  List<Object?> get props => [];
}

/// Initial state before the user pastes a link or resends.
class EmailVerificationInitial extends EmailVerificationState {
  const EmailVerificationInitial();
}

/// A verification call is in flight.
class EmailVerificationVerifying extends EmailVerificationState {
  const EmailVerificationVerifying();
}

/// The address was verified successfully via the pasted link.
class EmailVerificationVerified extends EmailVerificationState {
  const EmailVerificationVerified({required this.result});

  final EmailVerificationResult result;

  @override
  List<Object?> get props => [result];
}

/// Verifying the pasted link failed (unparseable, expired, or rejected).
class EmailVerificationError extends EmailVerificationState {
  const EmailVerificationError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}

/// A resend request is in flight.
class EmailVerificationResending extends EmailVerificationState {
  const EmailVerificationResending();
}

/// The resend request succeeded. [verified] is `true` when the address is
/// already verified server-side.
class EmailVerificationResent extends EmailVerificationState {
  const EmailVerificationResent({
    required this.verified,
    required this.message,
  });

  final bool verified;
  final String message;

  @override
  List<Object?> get props => [verified, message];
}

/// The resend request failed with a human-readable [message].
class EmailVerificationResendError extends EmailVerificationState {
  const EmailVerificationResendError({
    required this.message,
    this.isRateLimit = false,
  });

  final String message;
  final bool isRateLimit;

  @override
  List<Object?> get props => [message, isRateLimit];
}

/// Handles email verification: verifying a pasted signed link and resending
/// the verification notification.
class EmailVerificationCubit extends Cubit<EmailVerificationState> {
  /// Creates an [EmailVerificationCubit] with the given [repository].
  EmailVerificationCubit({required this.repository})
    : super(const EmailVerificationInitial());

  final AuthRepository repository;

  /// Verify the address using a pasted signed link.
  Future<void> verifyLink(String rawLink) async {
    final parsed = EmailVerificationLink.parse(rawLink.trim());
    if (parsed == null) {
      emit(
        const EmailVerificationError(
          message:
              'That does not look like a verification link. '
              'Please paste the full link from the email.',
        ),
      );
      return;
    }

    emit(const EmailVerificationVerifying());
    try {
      final result = await repository.verifyEmail(
        id: parsed.id,
        hash: parsed.hash,
        expires: parsed.expires,
        signature: parsed.signature,
      );
      if (!isClosed) {
        emit(EmailVerificationVerified(result: result));
      }
    } on ApiException catch (error) {
      if (!isClosed) {
        emit(EmailVerificationError(message: error.message));
      }
    } on Object {
      if (!isClosed) {
        emit(
          const EmailVerificationError(
            message: 'Something went wrong. Please try again.',
          ),
        );
      }
    }
  }

  /// Resend the verification notification to the current user's email.
  Future<void> resend() async {
    emit(const EmailVerificationResending());
    try {
      final verified = await repository.resendVerificationEmail();
      if (!isClosed) {
        emit(
          EmailVerificationResent(
            verified: verified,
            message: verified
                ? 'Your email address is already verified.'
                : 'A new verification email has been sent. '
                      'Check your inbox and paste the link below.',
          ),
        );
      }
    } on RateLimitException catch (error) {
      if (!isClosed) {
        emit(
          EmailVerificationResendError(
            message: error.message,
            isRateLimit: true,
          ),
        );
      }
    } on ApiException catch (error) {
      if (!isClosed) {
        emit(EmailVerificationResendError(message: error.message));
      }
    } on Object {
      if (!isClosed) {
        emit(
          const EmailVerificationResendError(
            message: 'Something went wrong. Please try again.',
          ),
        );
      }
    }
  }

  /// Return to the initial (form) state, e.g. after dismissing an error.
  void reset() {
    if (!isClosed) {
      emit(const EmailVerificationInitial());
    }
  }
}
