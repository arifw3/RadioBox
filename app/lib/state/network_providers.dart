import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/network_settings_repository.dart';

final networkSettingsRepositoryProvider = Provider<NetworkSettingsRepository>(
  (ref) => NetworkSettingsRepository(),
);

/// Live connectivity type — drives both the "Wi-Fi only" enforcement and
/// the data-usage warning when a station keeps playing across a Wi-Fi to
/// mobile-data handoff (Section 8, CLAUDE.md).
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

bool isOnWifi(List<ConnectivityResult> results) =>
    results.contains(ConnectivityResult.wifi);

class WifiOnlyNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    state = await ref.read(networkSettingsRepositoryProvider).loadWifiOnly();
  }

  void toggle() {
    final next = !state;
    state = next;
    ref.read(networkSettingsRepositoryProvider).saveWifiOnly(next);
  }
}

final wifiOnlyProvider =
    NotifierProvider<WifiOnlyNotifier, bool>(WifiOnlyNotifier.new);
