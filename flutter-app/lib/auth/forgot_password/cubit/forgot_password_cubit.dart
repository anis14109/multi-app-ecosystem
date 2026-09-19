import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_app/core/errors/api_exception.dart';
import 'package:flutter_app/core/repositories/auth_repository.dart';

/// States for the forgot-password flow.
sealed class ForgotPasswordState extends Equatable {
  const ForgotPasswordState();

  @override
  List<Object?> get props => [];
}

/// Initial state before the user submits the form.
class ForgotPasswordInitial extends ForgotPasswordState {
  const ForgotPasswordInitial();
}

/// A reset-link request is in flight.
class ForgotPasswordLoading extends ForgotPasswordState {
  const ForgotPasswordLoading();
}

/// The request succeeded. The server always replies the same way to avoid
/// account enumeration, so this does not imply the account exists.
class ForgotPasswordSuccess extends ForgotPasswordState {
  const ForgotPasswordSuccess();
}

/// The request failed with a human-readable [message].
class ForgotPasswordError extends ForgotPasswordState {
  const ForgotPasswordError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Handles the "forgot password" (request reset link) flow.
class ForgotPasswordCubit extends Cubit<ForgotPasswordState> {
  /// Creates a [ForgotPasswordCubit] with the given [repository].
  ForgotPasswordCubit({required this.repository})
    : super(const ForgotPasswordInitial());

  final AuthRepository repository;

  /// Request a password-reset link for [email].
  Future<void> forgotPassword(String email) async {
    emit(const ForgotPasswordLoading());
    try {
      await repository.forgotPassword(email: email.trim());
      if (!isClosed) {
        emit(const ForgotPasswordSuccess());
      }
    } on ValidationException catch (error) {
      if (!isClosed) {
        emit(
          ForgotPasswordError(
            message: error.firstFieldError ?? error.message,
          ),
        );
      }
    } on ApiException catch (error) {
      if (!isClosed) {
        emit(ForgotPasswordError(message: error.message));
      }
    } on Object {
      if (!isClosed) {
        emit(
          const ForgotPasswordError(
            message: 'Something went wrong. Please try again.',
          ),
        );
      }
    }
  }

  /// Return to the initial (form) state, e.g. after dismissing an error.
  void reset() {
    if (!isClosed) {
      emit(const ForgotPasswordInitial());
    }
  }
}
