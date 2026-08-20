import 'package:connectivity_plus/connectivity_plus.dart';

/// Reports whether the device currently has network connectivity, so the
/// sync layer knows when it's safe to attempt a cloud push.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  Stream<bool> get onStatusChange => _connectivity.onConnectivityChanged
      .map((results) => !results.contains(ConnectivityResult.none));
}
