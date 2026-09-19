/// Barrel export for the entire auth feature.
///
/// Re-exports the BLoC layer and view layer for convenient
/// single-file imports. Usage:
/// ```dart
/// import 'package:flutter_app/auth/auth.dart';
/// ```
library;

export 'bloc/bloc.dart';
export 'email_verification/email_verification.dart';
export 'forgot_password/forgot_password.dart';
export 'password_confirmation/password_confirmation.dart';
export 'reset_password/reset_password.dart';
export 'view/auth_view.dart';
