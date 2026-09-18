/// Barrel export for the entire auth feature.
///
/// Re-exports the BLoC layer and view layer for convenient
/// single-file imports. Usage:
/// ```dart
/// import 'package:flutter_app/auth/auth.dart';
/// ```
library;

export 'bloc/bloc.dart';
export 'view/auth_view.dart';
