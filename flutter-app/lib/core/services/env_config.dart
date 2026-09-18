import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Runtime configuration loaded from `.env` at startup via `flutter_dotenv`.
///
/// Values are read lazily and fall back to safe defaults so the app still
/// boots (and tests still run) when `.env` has not been loaded.
class EnvConfig {
  EnvConfig._();

  /// Resolve the API base URL used by the Dio HTTP client.
  ///
  /// Prefers the `.env` value, then a `--dart-define` value passed as
  /// [defineValue], and finally a sensible local default. Always trims
  /// trailing slashes so path concatenation stays predictable.
  static String apiBaseUrl({String defineValue = ''}) {
    final fromEnv = _read('API_BASE_URL');
    final raw = (fromEnv.isNotEmpty ? fromEnv : defineValue)
        .trim()
        .replaceFirst(RegExp(r'/+$'), '');
    return raw.isEmpty ? 'http://localhost:8000/api' : raw;
  }

  /// Display name shown throughout the UI (loading, app bar, auth screens).
  static String get appName {
    final name = _read('APP_NAME').trim();
    return name.isEmpty ? 'MultiApp' : name;
  }

  /// Environment label used for feedback/debug output.
  static String get environment {
    final env = _read('APP_ENV').trim();
    return env.isEmpty ? 'development' : env;
  }

  static String _read(String key) {
    try {
      final value = dotenv.maybeGet(key);
      return value ?? '';
    } on Object {
      return '';
    }
  }
}
