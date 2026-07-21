import 'package:dialwave_core/dialwave_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/alarm_repository.dart';
import '../services/alarm_service.dart';
import 'player_providers.dart';

/// Overridden in main() once AlarmService.init() resolves — see the
/// ProviderScope override there.
final alarmServiceProvider = Provider<AlarmService>(
  (ref) => throw UnimplementedError('alarmServiceProvider not overridden'),
);

final alarmRepositoryProvider = Provider<AlarmRepository>(
  (ref) => AlarmRepository(),
);

final alarmSettingsProvider = FutureProvider<AlarmSettings?>((ref) {
  return ref.watch(alarmRepositoryProvider).load();
});

/// Runs once at startup: if the app was launched by tapping the alarm
/// notification, waits for the catalog and starts playing the stored
/// alarm station. Consumed (its value ignored) from the root widget just
/// to trigger this side effect.
final alarmAutoplayProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(alarmServiceProvider);
  if (!await service.launchedFromAlarm()) return;

  final settings = await ref.watch(alarmRepositoryProvider).load();
  if (settings == null) return;

  final catalog = await ref.watch(radioCatalogProvider.future);
  RadioStation? station;
  for (final s in catalog.stations) {
    if (s.id == settings.stationId) {
      station = s;
      break;
    }
  }
  if (station == null) return;

  await ref.read(audioHandlerProvider).playStation(station);
});
