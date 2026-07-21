import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'player_providers.dart';

/// Remaining time on the sleep timer, or null when none is active.
final sleepTimerProvider = NotifierProvider<SleepTimerNotifier, Duration?>(
  SleepTimerNotifier.new,
);

class SleepTimerNotifier extends Notifier<Duration?> {
  Timer? _ticker;
  DateTime? _endTime;

  @override
  Duration? build() {
    ref.onDispose(() => _ticker?.cancel());
    return null;
  }

  void start(Duration duration) {
    _ticker?.cancel();
    _endTime = DateTime.now().add(duration);
    state = duration;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void cancel() {
    _ticker?.cancel();
    _ticker = null;
    _endTime = null;
    state = null;
  }

  void _tick() {
    final end = _endTime;
    if (end == null) return;
    final remaining = end.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      ref.read(audioHandlerProvider).pause();
      cancel();
    } else {
      state = remaining;
    }
  }
}
