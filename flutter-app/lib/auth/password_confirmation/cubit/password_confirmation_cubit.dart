import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_app/core/errors/api_exception.dart';
import 'package:flutter_app/core/repositories/auth_repository.dart';

/// States for the password-confirmation flow.
sealed class PasswordConfirmationState extends Equatable {
  const PasswordConfirmationState();

  @override
  List<Object?> get props => [];
}

/// Initial state before the user submits the password.
class PasswordConfirmationInitial extends PasswordConfirmationState {
  const PasswordConfirmationInitial();
}

/// The confirmation request is in flight.
class PasswordConfirmationSubmitting extends PasswordConfirmationState {
  const PasswordConfirmationSubmitting();
}

/// The password was confirmed successfully.
class PasswordConfirmationSuccess extends PasswordConfirmationState {
  const PasswordConfirmationSuccess();
}

/// Confirmation failed with a human-readable [message].
class PasswordConfirmationError extends PasswordConfirmationState {
  const PasswordConfirmationError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Reusable password-confirmation flow backed by
/// `POST /api/v1/user/confirm-password`.
///
/// Notifies the server that the current password is known, which resets the
/// password-confirmation window for sensitive operations.
class PasswordConfirmationCubit extends Cubit<PasswordConfirmationState> {
  /// Creates a [PasswordConfirmationCubit] with the given [repository].
  PasswordConfirmationCubit({required this.repository})
    : super(const PasswordConfirmationInitial());

  final AuthRepository repository;

  /// Confirm the current [password] with the server.
  Future<void> confirmPassword(String password) async {
    emit(const PasswordConfirmationSubmitting());
    try {
      await repository.confirmPassword(password: password);
      if (!isClosed) {
        emit(const PasswordConfirmationSuccess());
      }
    } on ValidationException catch (error) {
      if (!isClosed) {
        emit(
          PasswordConfirmationError(
            message: error.firstFieldError ?? error.message,
          ),
        );
      }
    } on ApiException catch (error) {
      if (!isClosed) {
        emit(PasswordConfirmationError(message: error.message));
      }
    } on Object {
      if (!isClosed) {
        emit(
          const PasswordConfirmationError(
            message: 'Something went wrong. Please try again.',
          ),
        );
      }
    }
  }

  /// Return to the initial (form) state, e.g. after dismissing an error.
  void reset() {
    if (!isClosed) {
      emit(const PasswordConfirmationInitial());
    }
  }
}
