import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/play_history_repository.dart';

final playHistoryRepositoryProvider = Provider<PlayHistoryRepository>(
  (ref) => PlayHistoryRepository(),
);

/// stationId -> number of times actually played, independent of whether
/// it's favorited. Drives "sık dinlenen önce" ordering on the station
/// list.
final playHistoryProvider =
    NotifierProvider<PlayHistoryNotifier, Map<String, int>>(
  PlayHistoryNotifier.new,
);

class PlayHistoryNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() {
    _load();
    return const {};
  }

  Future<void> _load() async {
    state = await ref.read(playHistoryRepositoryProvider).load();
  }

  void recordPlay(String stationId) {
    final updated = Map<String, int>.from(state);
    updated[stationId] = (updated[stationId] ?? 0) + 1;
    state = updated;
    ref.read(playHistoryRepositoryProvider).save(updated);
  }
}
