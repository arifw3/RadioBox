import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's favorite station IDs on-device — no account, no
/// server, matches the zero-cost architecture.
class FavoritesRepository {
  static const _prefsKey = 'favorite_station_ids';

  Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_prefsKey) ?? const <String>[]).toSet();
  }

  Future<void> save(Set<String> stationIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, stationIds.toList());
  }
}
