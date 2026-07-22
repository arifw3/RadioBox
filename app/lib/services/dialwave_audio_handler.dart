import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:dialwave_core/dialwave_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

import 'favorites_repository.dart';
import 'radio_repository.dart';

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
    _player.icyMetadataStream.listen(_onIcyMetadata);
    unawaited(_initAudioSession());
  }

  final AudioPlayer _player = AudioPlayer();
  final RadioRepository _radioRepository = RadioRepository(http.Client());
  final FavoritesRepository _favoritesRepository = FavoritesRepository();
  RadioCatalog? _browsingCatalogCache;

  static const _favoritesFolderId = 'favorites';
  static const _allStationsFolderId = 'all_stations';
  static const _folderTitlesByLanguage = {
    _favoritesFolderId: {
      'tr': 'Favoriler',
      'en': 'Favorites',
      'es': 'Favoritas',
      'de': 'Favoriten',
    },
    _allStationsFolderId: {
      'tr': 'Tüm İstasyonlar',
      'en': 'All Stations',
      'es': 'Todas las emisoras',
      'de': 'Alle Sender',
    },
  };

  RadioStation? _currentStation;
  RadioStation? get currentStation => _currentStation;

  /// True if a phone call (or similar) paused us — vs. the user pausing
  /// manually — so we know whether to auto-resume when it ends.
  bool _pausedByInterruption = false;

  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;

  /// See the comment in [playStation] — ICY metadata events are ignored
  /// until this time to avoid a stale event from the previous station's
  /// connection landing on the new one.
  DateTime? _ignoreIcyUntil;

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
    // ExoPlayer's ICY extractor runs on a background thread against the
    // *old* stream connection while it's being torn down — a metadata
    // event already in flight when setUrl() below replaces the source can
    // still land in _onIcyMetadata afterwards, wrongly tagging the new
    // station with the previous one's leftover "Artist - Song" text. Since
    // there's no per-event way to tell which stream a callback came from,
    // ignore ICY updates for a short grace window right after switching —
    // real stations don't announce that fast anyway.
    _ignoreIcyUntil = DateTime.now().add(const Duration(seconds: 2));
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

  /// Android Auto/Automotive binds to this service independently of the
  /// Flutter UI, so browsing needs its own catalog source rather than
  /// reading a Riverpod provider — reuses the same cache-first repository
  /// the app itself warms on cold start.
  Future<RadioCatalog> _catalogForBrowsing() async {
    final cached = _browsingCatalogCache;
    if (cached != null) return cached;
    final fromDisk = await _radioRepository.loadCached();
    if (fromDisk != null) {
      _browsingCatalogCache = fromDisk;
      return fromDisk;
    }
    final fresh = await _radioRepository.fetchAndCache();
    _browsingCatalogCache = fresh;
    return fresh;
  }

  MediaItem _folderItem(String id) {
    final lang = ui.PlatformDispatcher.instance.locale.languageCode;
    final titles = _folderTitlesByLanguage[id]!;
    return MediaItem(id: id, title: titles[lang] ?? titles['en']!, playable: false);
  }

  /// Android Auto's browse tree: two folders mirroring the app's own
  /// Home tabs (Favorites, All Stations) rather than a single flat list
  /// of ~2000 stations.
  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    switch (parentMediaId) {
      case AudioService.browsableRootId:
        return [
          _folderItem(_favoritesFolderId),
          _folderItem(_allStationsFolderId),
        ];
      case _favoritesFolderId:
        final catalog = await _catalogForBrowsing();
        final favoriteIds = await _favoritesRepository.load();
        return catalog.stations
            .where((s) => favoriteIds.contains(s.id))
            .map(_toMediaItem)
            .toList();
      case _allStationsFolderId:
        final catalog = await _catalogForBrowsing();
        return catalog.stations.map(_toMediaItem).toList();
      default:
        return [];
    }
  }

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    final catalog = await _catalogForBrowsing();
    for (final station in catalog.stations) {
      if (station.id == mediaId) {
        await playStation(station);
        return;
      }
    }
  }

  /// Most stations without ICY metadata never fire this at all — the
  /// artist field just keeps showing the country code fallback set in
  /// [_toMediaItem]. When a stream does send a "StreamTitle" (usually
  /// "Artist - Song"), swap it in as the artist line so it survives on
  /// the lock screen and Now Playing without needing a dedicated field.
  void _onIcyMetadata(IcyMetadata? icyMetadata) {
    final ignoreUntil = _ignoreIcyUntil;
    if (ignoreUntil != null && DateTime.now().isBefore(ignoreUntil)) return;
    final rawTitle = icyMetadata?.info?.title?.trim();
    if (rawTitle == null || rawTitle.isEmpty) return;
    final current = mediaItem.value;
    if (current == null) return;
    mediaItem.add(current.copyWith(artist: _fixIcyEncoding(rawTitle)));
  }

  /// ExoPlayer/AVPlayer decode ICY "StreamTitle" metadata as ISO-8859-1
  /// per the (informal) ICY spec, which mangles non-ASCII characters
  /// (Turkish, Spanish, German diacritics etc.) whenever the station's
  /// source encoder actually sent UTF-8. Re-encoding the mangled string
  /// back to bytes as Latin-1 and decoding those bytes as UTF-8 recovers
  /// the original text when that's what happened; falls back to the raw
  /// string untouched otherwise (e.g. it really was ASCII/Latin-1).
  String _fixIcyEncoding(String raw) {
    try {
      return utf8.decode(latin1.encode(raw));
    } catch (_) {
      return raw;
    }
  }

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
      // Non-fatal — this is a broken/dead stream, not an app crash, but
      // still worth knowing about: the nightly radio_sync ping only
      // catches links that are down *at 03:00*, not ones that fail
      // during actual playback later in the day.
      FirebaseCrashlytics.instance.recordError(
        Exception(
          'Radio stream failed after $_maxReconnectAttempts reconnect attempts',
        ),
        StackTrace.current,
        fatal: false,
        information: [
          'stationId: ${station.id}',
          'stationName: ${station.name}',
          'streamUrl: ${station.streamUrl}',
        ],
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
