import 'package:connectivity_plus/connectivity_plus.dart';

/// Service for checking device network connectivity status.
///
/// Used by the AuthBloc to determine whether to attempt online
/// authentication or fall back to offline (local) authentication.
class NetworkInfoService {
  /// Creates a [NetworkInfoService] with an optional [Connectivity]
  /// instance for testing purposes.
  NetworkInfoService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// Check if the device currently has an active internet connection.
  ///
  /// Uses [Connectivity] to check the connection type (wifi, mobile, etc.).
  /// Note: This checks for network availability, not actual internet access.
  Future<bool> isConnected() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }
}
