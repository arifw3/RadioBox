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
/// AppBar overflow menu, not just [SleepTimerButton].
Future<void> openSleepTimerSheet(BuildContext context, WidgetRef ref) async {
  final active = ref.read(sleepTimerProvider) != null;
  await showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Uyku Zamanlayıcısı',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
          if (active)
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Zamanlayıcıyı kapat'),
              onTap: () {
                ref.read(sleepTimerProvider.notifier).cancel();
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    ),
  );
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
