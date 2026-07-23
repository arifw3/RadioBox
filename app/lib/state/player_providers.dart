import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:dialwave_core/dialwave_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../services/dialwave_audio_handler.dart';
import '../services/radio_repository.dart';

/// Overridden in main() once AudioService.init() resolves (see the
/// ProviderScope override there). Reading this before that override is
/// wired up is a programming error, so failing loudly here is correct.
final audioHandlerProvider = Provider<DialWaveAudioHandler>(
  (ref) => throw UnimplementedError('audioHandlerProvider not overridden'),
);

final radioRepositoryProvider = Provider<RadioRepository>(
  (ref) => RadioRepository(http.Client()),
);

/// Cache-first: a cached catalog (if one exists from a previous launch) is
/// returned immediately so the station list can paint on the very first
/// frame, then a network fetch runs in the background and silently
/// replaces it once it lands. A cold start with no cache falls back to
/// waiting on the network fetch directly, same as before.
class RadioCatalogNotifier extends AsyncNotifier<RadioCatalog> {
  @override
  Future<RadioCatalog> build() async {
    final repo = ref.watch(radioRepositoryProvider);
    final cached = await repo.loadCached();
    if (cached != null) {
      unawaited(_refreshInBackground(repo));
      return cached;
    }
    return repo.fetchAndCache();
  }

  Future<void> _refreshInBackground(RadioRepository repo) async {
    try {
      final fresh = await repo.fetchAndCache();
      state = AsyncData(fresh);
    } catch (_) {
      // Refresh failed (offline, CDN blip, etc.) — keep showing the
      // cached catalog rather than surfacing an error over stale data.
    }
  }
}

final radioCatalogProvider =
    AsyncNotifierProvider<RadioCatalogNotifier, RadioCatalog>(
  RadioCatalogNotifier.new,
);

final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  return ref.watch(audioHandlerProvider).playbackState;
});

final currentMediaItemProvider = StreamProvider<MediaItem?>((ref) {
  return ref.watch(audioHandlerProvider).mediaItem;
});

/// Zaman Yolculuğu (Section 4, CLAUDE.md) — true once playback has switched
/// from the live URL to the local rewind buffer.
final isTimeShiftedProvider = StreamProvider<bool>((ref) {
  return ref.watch(audioHandlerProvider).timeShiftStream;
});
