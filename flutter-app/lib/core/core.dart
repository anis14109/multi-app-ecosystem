/// Barrel export for core services, models, and repositories.
///
/// Re-exports all core components for convenient single-file imports.
/// Usage:
/// ```dart
/// import 'package:flutter_app/core/core.dart';
/// ```
library;

export 'errors/api_exception.dart';
export 'models/auth_response_model.dart';
export 'models/email_verification.dart';
export 'models/session_model.dart';
export 'models/user_model.dart';
export 'repositories/auth_repository.dart';
export 'services/api_client.dart';
export 'services/biometric_service.dart';
export 'services/env_config.dart';
export 'services/network_info_service.dart';
export 'services/pin_hash_service.dart';
export 'services/secure_storage_service.dart';
