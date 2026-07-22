import 'package:shared_preferences/shared_preferences.dart';

/// Persists the "Wi-Fi only" playback toggle (Section 8, CLAUDE.md's data-
/// saving intent) across launches.
class NetworkSettingsRepository {
  static const _wifiOnlyKey = 'wifi_only_enabled';

  Future<bool> loadWifiOnly() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_wifiOnlyKey) ?? false;
  }

  Future<void> saveWifiOnly(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wifiOnlyKey, value);
  }
}
