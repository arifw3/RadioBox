// Pure logic pulled out of bin/radio_sync.dart so it's unit-testable —
// Dart privacy is file-scoped, so a `_`-prefixed function in a bin/ script
// can't be imported from a separate test file at all. Everything with
// actual I/O (HTTP fetches, verifying a stream is reachable) stays in
// bin/radio_sync.dart, where it isn't practical to unit test cheaply.

import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'package:dialwave_core/dialwave_core.dart';

/// radio-browser.info sometimes sends the literal string "null" instead of
/// an empty/absent field for stations with no favicon — treat that the
/// same as genuinely empty, or the app tries to load "null" as a URL.
String cleanFavicon(String? raw) {
  final trimmed = (raw ?? '').trim();
  return trimmed.toLowerCase() == 'null' ? '' : trimmed;
}

bool looksLikeAudio(String contentType) {
  if (contentType.isEmpty) {
    // Some Icecast/Shoutcast mounts omit Content-Type entirely. Candidates
    // are already pre-filtered upstream, so treat "empty" as acceptable
    // rather than penalizing valid streams twice.
    return true;
  }
  const audioMarkers = [
    'audio/',
    'application/ogg',
    'application/octet-stream',
    // HLS playlists (.m3u8) — a growing share of Turkish CDN-hosted streams.
    'mpegurl',
  ];
  return audioMarkers.any(contentType.contains);
}

/// radio-browser.info is crowdsourced — the same station commonly gets
/// submitted more than once (different UUIDs, mirrored stream URLs). Keeps
/// only the most-clicked entry per (name, country).
List<RadioStation> deduplicate(List<RadioStation> stations) {
  final byKey = <String, RadioStation>{};
  for (final station in stations) {
    final key = '${station.name.trim().toLowerCase()}|${station.countryCode}';
    final current = byKey[key];
    if (current == null || isBetterDuplicate(station, current)) {
      byKey[key] = station;
    }
  }
  return byKey.values.toList();
}

/// Which of two same-name entries to keep: the more-clicked one is more
/// likely to be the mirror people actually found and listened to, not a
/// stale/abandoned duplicate submission.
bool isBetterDuplicate(RadioStation candidate, RadioStation current) {
  if (candidate.clickCount != current.clickCount) {
    return candidate.clickCount > current.clickCount;
  }
  return candidate.votes > current.votes;
}

String hashStations(List<RadioStation> stations) {
  final sortedIds = stations.map((s) => '${s.id}:${s.streamUrl}').toList()
    ..sort();
  return sha256.convert(utf8.encode(sortedIds.join('|'))).toString();
}
