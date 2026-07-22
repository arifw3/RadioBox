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

  /// How long before the timer ends the volume starts easing down —
  /// waking up to a hard cutoff mid-stream is jarring; fading out reads
  /// as the stream naturally winding down instead.
  static const _fadeOutWindow = Duration(seconds: 10);

  @override
  Duration? build() {
    ref.onDispose(() => _ticker?.cancel());
    return null;
  }

  void start(Duration duration) {
    _ticker?.cancel();
    _endTime = DateTime.now().add(duration);
    state = duration;
    ref.read(audioHandlerProvider).setVolume(1.0);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void cancel() {
    _ticker?.cancel();
    _ticker = null;
    _endTime = null;
    state = null;
    ref.read(audioHandlerProvider).setVolume(1.0);
  }

  void _tick() {
    final end = _endTime;
    if (end == null) return;
    final remaining = end.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      ref.read(audioHandlerProvider).pause();
      cancel(); // also restores volume to 1.0 for the next time playback starts
    } else {
      state = remaining;
      if (remaining <= _fadeOutWindow) {
        final fraction =
            remaining.inMilliseconds / _fadeOutWindow.inMilliseconds;
        ref.read(audioHandlerProvider).setVolume(fraction.clamp(0.0, 1.0));
      }
    }
  }
}
