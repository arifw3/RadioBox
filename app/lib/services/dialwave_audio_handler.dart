import 'package:audio_service/audio_service.dart';
import 'package:dialwave_core/dialwave_core.dart';
import 'package:just_audio/just_audio.dart';

/// Wraps [AudioPlayer] behind audio_service's [BaseAudioHandler] so
/// playback survives the app going to background and keeps working with
/// the lock screen / MediaSession (Section 4, CLAUDE.md).
class DialWaveAudioHandler extends BaseAudioHandler with SeekHandler {
  DialWaveAudioHandler() {
    _player.playbackEventStream.listen(
      _broadcastState,
      onError: (Object error, StackTrace stackTrace) {
        // A dead stream shouldn't crash the handler — surface it as an
        // error state so the UI can offer retry/next-station instead of
        // hanging on a stale "loading" spinner forever.
        playbackState.add(
          playbackState.value.copyWith(
            processingState: AudioProcessingState.error,
            playing: false,
          ),
        );
      },
    );
  }

  final AudioPlayer _player = AudioPlayer();

  RadioStation? _currentStation;
  RadioStation? get currentStation => _currentStation;

  Future<void> playStation(RadioStation station) async {
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
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
          playing: false,
        ),
      );
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
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> onTaskRemoved() async {
    // A real radio doesn't stop just because the user swiped the app
    // away — only an explicit stop() should tear the session down.
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
