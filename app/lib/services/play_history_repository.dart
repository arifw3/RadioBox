import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// How many times the user has actually played each station — separate
/// from favorites (a station can be played a lot without ever being
/// favorited) and used to rank the station list by real listening habit
/// rather than radio-browser.info's global click count alone.
class PlayHistoryRepository {
  static const _prefsKey = 'play_history_counts';

  Future<Map<String, int>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((id, count) => MapEntry(id, count as int));
  }

  Future<void> save(Map<String, int> counts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(counts));
  }
}
