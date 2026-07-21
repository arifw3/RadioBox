import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/favorites_repository.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepository(),
);

final favoritesProvider =
    AsyncNotifierProvider<FavoritesNotifier, Set<String>>(
  FavoritesNotifier.new,
);

class FavoritesNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() {
    return ref.read(favoritesRepositoryProvider).load();
  }

  Future<void> toggle(String stationId) async {
    final current = state.valueOrNull ?? const <String>{};
    final updated = Set<String>.from(current);
    if (!updated.remove(stationId)) {
      updated.add(stationId);
    }
    // Update optimistically, then persist — the UI shouldn't wait on disk
    // I/O for a heart icon to flip.
    state = AsyncData(updated);
    await ref.read(favoritesRepositoryProvider).save(updated);
  }
}
