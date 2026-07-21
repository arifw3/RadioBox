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

final radioCatalogProvider = FutureProvider<RadioCatalog>((ref) {
  return ref.watch(radioRepositoryProvider).fetchCatalog();
});

final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  return ref.watch(audioHandlerProvider).playbackState;
});

final currentMediaItemProvider = StreamProvider<MediaItem?>((ref) {
  return ref.watch(audioHandlerProvider).mediaItem;
});
