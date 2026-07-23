import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SongHistoryEntry {
  const SongHistoryEntry({
    required this.songLabel,
    required this.stationName,
    required this.playedAt,
  });

  /// The raw ICY "StreamTitle" text (e.g. "Artist - Song") — kept whole
  /// rather than split, since not every station formats it the same way
  /// (see DialWaveAudioHandler._onIcyMetadata).
  final String songLabel;
  final String stationName;
  final DateTime playedAt;

  Map<String, dynamic> toJson() => {
    'songLabel': songLabel,
    'stationName': stationName,
    'playedAt': playedAt.toIso8601String(),
  };

  factory SongHistoryEntry.fromJson(Map<String, dynamic> json) =>
      SongHistoryEntry(
        songLabel: json['songLabel'] as String,
        stationName: json['stationName'] as String,
        playedAt: DateTime.parse(json['playedAt'] as String),
      );
}

/// Timestamped log of real songs played (as opposed to playHistoryProvider,
/// which only counts how many times each *station* was played) — most
/// recent first, capped so it doesn't grow unbounded in shared_preferences.
class SongHistoryRepository {
  static const _prefsKey = 'song_history_entries';
  // Matches the rough size of "recently played" lists in Spotify/Apple
  // Music — enough history to be useful without the list feeling
  // unbounded.
  static const maxEntries = 100;

  Future<List<SongHistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => SongHistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<SongHistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }
}
