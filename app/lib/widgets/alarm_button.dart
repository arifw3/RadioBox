import 'package:dialwave_core/dialwave_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../services/alarm_repository.dart';
import '../state/alarm_providers.dart';
import '../state/player_providers.dart';

/// Opens the alarm setup sheet — also called directly from the AppBar
/// overflow menu, not just [AlarmButton].
Future<void> openAlarmSheet(BuildContext context, WidgetRef ref) async {
  final catalog = ref.read(radioCatalogProvider).valueOrNull;
  final existing = await ref.read(alarmRepositoryProvider).load();

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _AlarmSheet(
      stations: catalog?.stations ?? const [],
      existing: existing,
    ),
  );
}

/// AppBar action for the radio wake-up alarm (Section 7, CLAUDE.md).
class AlarmButton extends ConsumerWidget {
  const AlarmButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.alarm),
      tooltip: AppLocalizations.of(context)!.alarmLabel,
      onPressed: () => openAlarmSheet(context, ref),
    );
  }
}

class _AlarmSheet extends ConsumerStatefulWidget {
  const _AlarmSheet({required this.stations, required this.existing});

  final List<RadioStation> stations;
  final AlarmSettings? existing;

  @override
  ConsumerState<_AlarmSheet> createState() => _AlarmSheetState();
}

class _AlarmSheetState extends ConsumerState<_AlarmSheet> {
  late TimeOfDay _time = widget.existing != null
      ? TimeOfDay(hour: widget.existing!.hour, minute: widget.existing!.minute)
      : const TimeOfDay(hour: 7, minute: 0);
  RadioStation? _station;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      for (final s in widget.stations) {
        if (s.id == existing.stationId) {
          _station = s;
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Radyo Alarmı',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: Text(
                '${_time.hour.toString().padLeft(2, '0')}:'
                '${_time.minute.toString().padLeft(2, '0')}',
              ),
              onTap: () async {
                final picked =
                    await showTimePicker(context: context, initialTime: _time);
                if (picked != null) setState(() => _time = picked);
              },
            ),
            ListTile(
              leading: const Icon(Icons.radio),
              title: Text(_station?.name ?? 'İstasyon seç'),
              onTap: () async {
                final picked = await showModalBottomSheet<RadioStation>(
                  context: context,
                  builder: (context) => ListView(
                    children: widget.stations
                        .map(
                          (s) => ListTile(
                            title: Text(s.name),
                            onTap: () => Navigator.of(context).pop(s),
                          ),
                        )
                        .toList(),
                  ),
                );
                if (picked != null) setState(() => _station = picked);
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _station == null
                  ? null
                  : () async {
                      final station = _station!;
                      await ref.read(alarmRepositoryProvider).save(
                            AlarmSettings(
                              hour: _time.hour,
                              minute: _time.minute,
                              stationId: station.id,
                              stationName: station.name,
                            ),
                          );
                      await ref.read(alarmServiceProvider).scheduleDaily(
                            hour: _time.hour,
                            minute: _time.minute,
                            stationName: station.name,
                          );
                      if (context.mounted) Navigator.of(context).pop();
                    },
              child: const Text('Alarmı Kaydet'),
            ),
            if (widget.existing != null)
              TextButton(
                onPressed: () async {
                  await ref.read(alarmRepositoryProvider).clear();
                  await ref.read(alarmServiceProvider).cancel();
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Alarmı Kapat'),
              ),
          ],
        ),
      ),
    );
  }
}
