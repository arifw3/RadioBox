import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:dialwave_core/dialwave_core.dart';
import 'package:just_audio/just_audio.dart';

/// Wraps [AudioPlayer] behind audio_service's [BaseAudioHandler] so
/// playback survives the app going to background and keeps working with
/// the lock screen / MediaSession (Section 4, CLAUDE.md). Also owns audio
/// focus (ducking, phone-call pause/resume) and reconnects automatically
/// when a live stream drops.
class DialWaveAudioHandler extends BaseAudioHandler with SeekHandler {
  DialWaveAudioHandler() {
    _player.playbackEventStream.listen(
      _broadcastState,
      onError: (Object error, StackTrace stackTrace) => _scheduleReconnect(),
    );
    unawaited(_initAudioSession());
  }

  final AudioPlayer _player = AudioPlayer();

  RadioStation? _currentStation;
  RadioStation? get currentStation => _currentStation;

  /// True if a phone call (or similar) paused us — vs. the user pausing
  /// manually — so we know whether to auto-resume when it ends.
  bool _pausedByInterruption = false;

  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            // Navigation prompts etc. — lower volume instead of stopping.
            _player.setVolume(0.3);
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            // A phone call — stop outright and remember to resume after.
            _pausedByInterruption = _player.playing;
            _player.pause();
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(1.0);
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            if (_pausedByInterruption) {
              _pausedByInterruption = false;
              _player.play();
            }
        }
      }
    });

    // Headphones/Bluetooth disconnected — don't blast through the
    // speaker unexpectedly.
    session.becomingNoisyEventStream.listen((_) => _player.pause());
  }

  Future<void> playStation(RadioStation station) async {
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    _currentStation = station;
    mediaItem.add(_toMediaItem(station));
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.loading,
        playing: false,
      ),
    );
    try {
      await _player.setUrl(station.streamUrl);
      await _player.play();
    } catch (_) {
      _scheduleReconnect();
    }
  }

  MediaItem _toMediaItem(RadioStation station) => MediaItem(
        id: station.id,
        title: station.name,
        artist: station.countryCode,
        artUri:
            station.favicon.isNotEmpty ? Uri.tryParse(station.favicon) : null,
        // Live streams have no known duration or seek range.
        duration: null,
      );

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    _reconnectTimer?.cancel();
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  /// Drive Mode's vertical-swipe volume gesture (Section 6, CLAUDE.md).
  Future<void> setVolume(double volume) => _player.setVolume(volume.clamp(0.0, 1.0));

  @override
  Future<void> onTaskRemoved() async {
    // A real radio doesn't stop just because the user swiped the app
    // away — only an explicit stop() should tear the session down.
  }

  /// Weak/dropped connections don't just stall a live stream, they kill
  /// it outright — ExoPlayer surfaces that as a playback error rather
  /// than transparent buffering. Retry with backoff instead of leaving
  /// the user stuck on a dead stream.
  void _scheduleReconnect() {
    final station = _currentStation;
    if (station == null) return;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
          playing: false,
        ),
      );
      return;
    }

    _reconnectAttempts++;
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.buffering,
        playing: false,
      ),
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(
      Duration(seconds: _reconnectAttempts * 2),
      () => _attemptReconnect(station),
    );
  }

  Future<void> _attemptReconnect(RadioStation station) async {
    if (_currentStation?.id != station.id) return; // user switched away
    try {
      await _player.setUrl(station.streamUrl);
      await _player.play();
      _reconnectAttempts = 0;
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _broadcastState(PlaybackEvent event) {
    final processingState = switch (_player.processingState) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          if (_player.playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1],
        processingState: processingState,
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ),
    );
  }
}
