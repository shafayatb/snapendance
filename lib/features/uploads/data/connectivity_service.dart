import 'package:connectivity_plus/connectivity_plus.dart';

abstract interface class ConnectivityService {
  Future<bool> isConnected();

  Stream<bool> get connectedChanges;
}

class PluginConnectivityService implements ConnectivityService {
  const PluginConnectivityService();

  static bool _connected(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  @override
  Future<bool> isConnected() async =>
      _connected(await Connectivity().checkConnectivity());

  @override
  Stream<bool> get connectedChanges =>
      Connectivity().onConnectivityChanged.map(_connected).distinct();
}
