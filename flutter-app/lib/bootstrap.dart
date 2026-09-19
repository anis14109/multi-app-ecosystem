import 'dart:async';
import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter_app/auth/auth.dart';
import 'package:flutter_app/core/repositories/auth_repository.dart';
import 'package:flutter_app/core/services/api_client.dart';
import 'package:flutter_app/core/services/biometric_service.dart';
import 'package:flutter_app/core/services/network_info_service.dart';
import 'package:flutter_app/core/services/pin_hash_service.dart';
import 'package:flutter_app/core/services/secure_storage_service.dart';

/// Global BLoC observer for logging state changes and errors.
///
/// Logs all BLoC transitions to the developer console for debugging.
/// In production, this could be replaced with a telemetry-based observer.
class AppBlocObserver extends BlocObserver {
  const AppBlocObserver();

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    log('onChange(${bloc.runtimeType}, $change)');
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    log('onError(${bloc.runtimeType}, $error, $stackTrace)');
    super.onError(bloc, error, stackTrace);
  }
}

/// Bootstrap function that initializes all services and runs the app.
///
/// Performs the following initialization steps:
/// 1. Sets up Flutter error handling and BLoC observer.
/// 2. Creates all service instances (secure storage, biometrics, network).
/// 3. Creates the repository with its dependencies.
/// 4. Creates the AuthBloc and triggers the initial auth check.
/// 5. Passes the AuthBloc and AuthRepository to [builder] so the App widget
///    can provide them to the widget tree.
///
/// The service dependency graph is:
/// ```text
/// SecureStorageService ──┐
/// BiometricService ──────┤
/// NetworkInfoService ────┤
/// PinHashService ────────┤
/// Dio (ApiClient) ───────┤
///                        ▼
///              AuthRepository
///                        │
///                        ▼
///                   AuthBloc ──> App
/// ```
Future<void> bootstrap(
  FutureOr<Widget> Function(
    AuthBloc authBloc,
    AuthRepository authRepository,
  )
  builder, {
  required String baseUrl,
}) async {
  FlutterError.onError = (details) {
    log(details.exceptionAsString(), stackTrace: details.stack);
  };

  Bloc.observer = const AppBlocObserver();

  // ── Initialize Core Services ──────────────────────────────────────
  final secureStorage = SecureStorageService();
  final biometricService = BiometricService();
  final networkInfo = NetworkInfoService();
  final pinHashService = PinHashService();

  // ── Initialize API Client ─────────────────────────────────────────
  final apiClient = ApiClient(
    secureStorage: secureStorage,
    baseUrl: baseUrl,
  );

  // ── Initialize Repository ─────────────────────────────────────────
  final authRepository = AuthRepository(
    secureStorage: secureStorage,
    dio: apiClient.dio,
  );

  // ── Initialize Auth BLoC ──────────────────────────────────────────
  final authBloc = AuthBloc(
    authRepository: authRepository,
    secureStorage: secureStorage,
    networkInfo: networkInfo,
    pinHashService: pinHashService,
    biometricService: biometricService,
  )..add(const AuthStarted());

  // ── Run App ───────────────────────────────────────────────────────
  runApp(await builder(authBloc, authRepository));
}
