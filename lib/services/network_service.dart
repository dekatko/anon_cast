import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';

/// Wrapper around connectivity_plus for checking and observing network state.
/// Use [isConnected] for one-off checks and [onConnectivityChanged] to react when connection returns.
class NetworkService {
  NetworkService({Logger? logger}) : _log = logger ?? Logger();

  final Logger _log;

  /// One-off check: true if any interface is not [ConnectivityResult.none].
  Future<bool> isConnected() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final connected = results.any((r) => r != ConnectivityResult.none);
      _log.d('NetworkService: isConnected=$connected');
      return connected;
    } catch (e, st) {
      _log.w('NetworkService: checkConnectivity failed', error: e, stackTrace: st);
      return false;
    }
  }

  /// Stream that emits when connectivity state changes. Use to trigger sync when online.
  Stream<bool> get onConnectivityChanged {
    return Connectivity().onConnectivityChanged.map((results) {
      final connected = results.any((r) => r != ConnectivityResult.none);
      _log.d('NetworkService: connectivity changed, connected=$connected');
      return connected;
    });
  }
}
