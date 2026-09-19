import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_app/core/errors/api_exception.dart';
import 'package:flutter_app/core/repositories/auth_repository.dart';

/// States for the reset-password flow.
sealed class ResetPasswordState extends Equatable {
  const ResetPasswordState();

  @override
  List<Object?> get props => [];
}

/// Initial state before the user submits the form.
class ResetPasswordInitial extends ResetPasswordState {
  const ResetPasswordInitial();
}

/// The reset request is in flight.
class ResetPasswordLoading extends ResetPasswordState {
  const ResetPasswordLoading();
}

/// The password was reset successfully.
class ResetPasswordSuccess extends ResetPasswordState {
  const ResetPasswordSuccess();
}

/// The reset failed with a human-readable [message].
class ResetPasswordError extends ResetPasswordState {
  const ResetPasswordError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Handles the password reset (`POST /auth/reset-password`) flow.
class ResetPasswordCubit extends Cubit<ResetPasswordState> {
  /// Creates a [ResetPasswordCubit] with the given [repository].
  ResetPasswordCubit({required this.repository})
    : super(const ResetPasswordInitial());

  final AuthRepository repository;

  /// Reset the password using [token], [email], and the new [password].
  Future<void> resetPassword({
    required String token,
    required String email,
    required String password,
  }) async {
    emit(const ResetPasswordLoading());
    try {
      await repository.resetPassword(
        token: token.trim(),
        email: email.trim(),
        password: password,
      );
      if (!isClosed) {
        emit(const ResetPasswordSuccess());
      }
    } on ValidationException catch (error) {
      if (!isClosed) {
        emit(
          ResetPasswordError(
            message: error.firstFieldError ?? error.message,
          ),
        );
      }
    } on ApiException catch (error) {
      if (!isClosed) {
        emit(ResetPasswordError(message: error.message));
      }
    } on Object {
      if (!isClosed) {
        emit(
          const ResetPasswordError(
            message: 'Something went wrong. Please try again.',
          ),
        );
      }
    }
  }

  /// Return to the initial (form) state, e.g. after dismissing an error.
  void reset() {
    if (!isClosed) {
      emit(const ResetPasswordInitial());
    }
  }
}
