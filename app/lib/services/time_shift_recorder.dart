import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Continuously downloads the live stream to a local rolling buffer file
/// while it's playing, so the user can "rewind" — a real local file
/// (unlike the live URL) is properly seekable, which a raw Icecast stream
/// never is. This is a *second* download of the same stream, independent
/// of just_audio's own playback connection, so it only runs on Wi-Fi to
/// avoid doubling mobile data usage — the live playback path is completely
/// unaffected either way.
class TimeShiftRecorder {
  static const bufferWindow = Duration(minutes: 15);
  static const _trimInterval = Duration(seconds: 30);

  StreamSubscription<List<int>>? _subscription;
  IOSink? _sink;
  Timer? _trimTimer;
  http.Client? _client;
  File? _bufferFile;

  int _bytesWritten = 0;
  DateTime? _recordingStartedAt;
  double _bytesPerSecond = 16000; // ~128kbps guess until enough data arrives
  bool trimSuspended = false;

  bool get isRecording => _subscription != null;

  String? get bufferFilePath => _bufferFile?.path;

  /// How much playable audio is currently sitting in the buffer.
  Duration get bufferedDuration {
    if (_bytesPerSecond <= 0) return Duration.zero;
    return Duration(seconds: (_bytesWritten / _bytesPerSecond).round());
  }

  Future<void> start(String streamUrl) async {
    await stop();

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/timeshift_buffer.dat');
    _bufferFile = file;
    _sink = file.openWrite(mode: FileMode.writeOnly);
    _bytesWritten = 0;
    _recordingStartedAt = DateTime.now();

    _client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(streamUrl));
      final response = await _client!.send(request);
      _subscription = response.stream.listen(
        (chunk) {
          _sink?.add(chunk);
          _bytesWritten += chunk.length;
          final elapsedMs = DateTime.now()
              .difference(_recordingStartedAt!)
              .inMilliseconds;
          if (elapsedMs > 2000) {
            _bytesPerSecond = _bytesWritten / (elapsedMs / 1000);
          }
        },
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (_) {
      // Recording is best-effort — a failure here shouldn't affect live
      // playback, which uses its own separate connection.
    }

    _trimTimer = Timer.periodic(_trimInterval, (_) => _trimIfNeeded());
  }

  Future<void> stop() async {
    _trimTimer?.cancel();
    _trimTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
    final file = _bufferFile;
    _bufferFile = null;
    if (file != null && await file.exists()) {
      await file.delete();
    }
    _bytesWritten = 0;
    trimSuspended = false;
  }

  Future<void> _trimIfNeeded() async {
    if (trimSuspended) return;
    final maxBytes = (_bytesPerSecond * bufferWindow.inSeconds).round();
    final file = _bufferFile;
    if (file == null || _bytesWritten <= maxBytes) return;

    // The sink is append-only, so keeping only the newest maxBytes needs a
    // read-trim-rewrite. The buffer is capped at ~15 minutes of audio
    // (a few MB), so reading it whole here is cheap.
    try {
      await _sink?.flush();
      final bytes = await file.readAsBytes();
      if (bytes.length <= maxBytes) return;
      final trimmed = bytes.sublist(bytes.length - maxBytes);
      await _sink?.close();
      await file.writeAsBytes(trimmed, flush: true);
      _bytesWritten = trimmed.length;
      _sink = file.openWrite(mode: FileMode.writeOnlyAppend);
    } catch (_) {
      // Best-effort — try again on the next trim tick.
    }
  }
}
