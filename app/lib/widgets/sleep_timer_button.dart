import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/sleep_timer_providers.dart';

const _presets = [
  Duration(minutes: 15),
  Duration(minutes: 30),
  Duration(minutes: 45),
  Duration(minutes: 60),
];

/// Opens the sleep timer picker sheet — also called directly from the
/// AppBar overflow menu, not just [SleepTimerButton]. A [Consumer] inside
/// (rather than reading state once before the sheet opens) so the live
/// countdown and the "cancel" option track the timer while the sheet is
/// open, instead of only reflecting whatever was true at the moment it
/// was opened.
Future<void> openSleepTimerSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: Consumer(
        builder: (context, ref, _) {
          final remaining = ref.watch(sleepTimerProvider);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'Uyku Zamanlayıcısı',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              if (remaining != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Text(
                    '${_endClockTime(remaining)}\'de duracak '
                    '(${remaining.inMinutes + 1} dakika kaldı)',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              for (final preset in _presets)
                ListTile(
                  title: Text('${preset.inMinutes} dakika sonra durdur'),
                  onTap: () {
                    ref.read(sleepTimerProvider.notifier).start(preset);
                    Navigator.of(context).pop();
                  },
                ),
              if (remaining != null)
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Zamanlayıcıyı kapat'),
                  onTap: () {
                    ref.read(sleepTimerProvider.notifier).cancel();
                    Navigator.of(context).pop();
                  },
                ),
            ],
          );
        },
      ),
    ),
  );
}

String _endClockTime(Duration remaining) {
  final end = DateTime.now().add(remaining);
  final hour = end.hour.toString().padLeft(2, '0');
  final minute = end.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// AppBar action for the sleep timer — shows remaining minutes once one
/// is running, otherwise a plain bedtime icon.
class SleepTimerButton extends ConsumerWidget {
  const SleepTimerButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = ref.watch(sleepTimerProvider);

    return IconButton(
      icon: remaining == null
          ? const Icon(Icons.bedtime_outlined)
          : Text('${remaining.inMinutes + 1}dk'),
      tooltip: 'Uyku Zamanlayıcısı',
      onPressed: () => openSleepTimerSheet(context, ref),
    );
  }
}
