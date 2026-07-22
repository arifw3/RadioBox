import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/song_history_repository.dart';

final songHistoryRepositoryProvider = Provider<SongHistoryRepository>(
  (ref) => SongHistoryRepository(),
);

/// Most-recent-first log of real songs played.
final songHistoryProvider =
    NotifierProvider<SongHistoryNotifier, List<SongHistoryEntry>>(
  SongHistoryNotifier.new,
);

class SongHistoryNotifier extends Notifier<List<SongHistoryEntry>> {
  @override
  List<SongHistoryEntry> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    state = await ref.read(songHistoryRepositoryProvider).load();
  }

  void record(String songLabel, String stationName) {
    final updated = [
      SongHistoryEntry(
        songLabel: songLabel,
        stationName: stationName,
        playedAt: DateTime.now(),
      ),
      ...state,
    ];
    final capped = updated.length > SongHistoryRepository.maxEntries
        ? updated.sublist(0, SongHistoryRepository.maxEntries)
        : updated;
    state = capped;
    ref.read(songHistoryRepositoryProvider).save(capped);
  }
}
