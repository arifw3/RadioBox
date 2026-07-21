import 'dart:math';

import 'package:dialwave_core/dialwave_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/social_sync_repository.dart';
import 'player_providers.dart';

final socialSyncRepositoryProvider = Provider<SocialSyncRepository>(
  (ref) => SocialSyncRepository(),
);

/// Stable per-app-session identity for room presence — no accounts.
final listenerIdProvider = Provider<String>((ref) {
  final rand = Random();
  return List.generate(12, (_) => rand.nextInt(16).toRadixString(16)).join();
});

/// The room the user is currently in, or null.
final currentRoomIdProvider = StateProvider<String?>((ref) => null);

/// True once this device created the room (host) vs joined one (guest) —
/// guests autoplay whatever station the host is on; hosts drive it.
final isRoomHostProvider = StateProvider<bool>((ref) => false);

final listenerCountProvider = StreamProvider<int>((ref) {
  final roomId = ref.watch(currentRoomIdProvider);
  if (roomId == null) return Stream.value(0);
  return ref.watch(socialSyncRepositoryProvider).watchListenerCount(roomId);
});

/// Guests only: keeps local playback following whatever station the host
/// picks in the room. Consumed (value ignored) purely for the side effect.
final roomStationSyncProvider = StreamProvider<void>((ref) async* {
  final roomId = ref.watch(currentRoomIdProvider);
  final isHost = ref.watch(isRoomHostProvider);
  if (roomId == null || isHost) return;

  final catalog = await ref.watch(radioCatalogProvider.future);
  await for (final stationId
      in ref.watch(socialSyncRepositoryProvider).watchRoomStation(roomId)) {
    if (stationId == null) continue;
    RadioStation? station;
    for (final s in catalog.stations) {
      if (s.id == stationId) {
        station = s;
        break;
      }
    }
    if (station != null) {
      await ref.read(audioHandlerProvider).playStation(station);
    }
    yield null;
  }
});
