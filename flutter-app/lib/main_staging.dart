import 'package:flutter_app/app/app.dart';
import 'package:flutter_app/bootstrap.dart';
import 'package:flutter_app/core/services/env_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Staging environment entry point.
///
/// Loads the API base URL from `.env` (flutter_dotenv) with a fallback
/// to `--dart-define=API_BASE_URL=...`.
/// Run with:
/// ```bash
/// flutter run -t lib/main_staging.dart
/// ```
Future<void> main() async {
  await dotenv.load();
  const defineBaseUrl = String.fromEnvironment('API_BASE_URL');
  await bootstrap(
    (authBloc) => App(authBloc: authBloc),
    // `--dart-define` resolves to '' at analyze time, hiding the fallback.
    // ignore: avoid_redundant_argument_values
    baseUrl: EnvConfig.apiBaseUrl(defineValue: defineBaseUrl),
  );
}
