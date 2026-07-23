// Nightly job (see .github/workflows/update_radios.yml): pulls candidate
// stations from radio-browser.info, verifies each stream actually
// responds, and writes the survivors to radios.json at the repo root.
//
// Usage: dart run bin/radio_sync.dart [output-path]

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dialwave_core/dialwave_core.dart';
import 'package:http/http.dart' as http;
import 'package:pool/pool.dart';

/// Countries whose stations we sync. Extend freely for "Dünya Turu" — no
/// other code changes needed (RadioStation already carries countryCode,
/// and the app filters/groups by it).
const _countryCodes = ['TR', 'US', 'GB', 'DE', 'FR'];

/// radio-browser.info asks integrations to identify themselves with a
/// descriptive User-Agent; generic ones get rate-limited or blocked.
const _userAgent =
    'DialWave-RadioSync/1.0 (+https://github.com/dialwave/dialwave)';

/// How many stream checks run at once. radio-browser mirrors and the
/// stations themselves are shared infrastructure we don't control — stay
/// polite rather than maximizing throughput.
const _concurrentChecks = 24;

const _requestTimeout = Duration(seconds: 8);

/// Cap per country so one nightly run can't blow past the GitHub Actions
/// job time limit if a country has thousands of listed stations. API
/// results are pre-sorted by click count, so this keeps the most-listened
/// stations first.
const _maxStationsPerCountry = 400;

Future<void> main(List<String> args) async {
  final client = http.Client();
  try {
    final apiBase = await _pickApiMirror(client);
    stderr.writeln('Using radio-browser mirror: $apiBase');

    final candidates = <_Candidate>[];
    for (final code in _countryCodes) {
      final stations = await _fetchStationsForCountry(client, apiBase, code);
      stderr.writeln('$code: ${stations.length} candidates from API');
      candidates.addAll(stations);
    }

    final bonus = await _loadBonusCandidates();
    stderr.writeln('bonus_stations.json: ${bonus.length} extra candidates');
    candidates.addAll(bonus);

    final verified = await _verifyStreams(client, candidates);
    stderr.writeln(
      '${verified.length}/${candidates.length} streams verified reachable',
    );

    // radio-browser.info is crowdsourced — the same station commonly gets
    // submitted more than once (different UUIDs, mirrored stream URLs).
    // Keep only the most-clicked entry per (name, country).
    final deduplicated = _deduplicate(verified);
    stderr.writeln(
      '${deduplicated.length}/${verified.length} after merging same-name duplicates',
    );

    deduplicated.sort((a, b) => b.clickCount.compareTo(a.clickCount));

    final catalog = RadioCatalog(
      version: _hashStations(deduplicated),
      generatedAtUtc: DateTime.now().toUtc(),
      stations: deduplicated,
    );

    final outFile = File(_resolveOutputPath(args));
    await outFile.create(recursive: true);
    await outFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(catalog.toJson()),
    );
    stderr.writeln('Wrote ${deduplicated.length} stations -> ${outFile.path}');
  } finally {
    client.close();
  }
}

String _resolveOutputPath(List<String> args) {
  if (args.isNotEmpty) return args.first;
  // Default: repo root, three levels up from tool/radio_sync/bin/.
  return '../../../radios.json';
}

Future<String> _pickApiMirror(http.Client client) async {
  // all.api.radio-browser.info round-robins DNS across every healthy
  // mirror; asking it for the concrete server list lets us pin one mirror
  // for the whole run instead of re-resolving on every request.
  final uri = Uri.parse('https://all.api.radio-browser.info/json/servers');
  try {
    final response = await client
        .get(uri, headers: {'User-Agent': _userAgent})
        .timeout(_requestTimeout);

    if (response.statusCode != 200) {
      return 'https://all.api.radio-browser.info';
    }

    final servers = jsonDecode(response.body) as List<dynamic>;
    if (servers.isEmpty) return 'https://all.api.radio-browser.info';

    final pick = servers[Random().nextInt(servers.length)] as Map<String, dynamic>;
    return 'https://${pick['name']}';
  } catch (_) {
    return 'https://all.api.radio-browser.info';
  }
}

class _Candidate {
  _Candidate({
    required this.id,
    required this.name,
    required this.streamUrl,
    required this.countryCode,
    required this.favicon,
    required this.tags,
    required this.codec,
    required this.bitrateKbps,
    required this.votes,
    required this.clickCount,
  });

  final String id;
  final String name;
  final String streamUrl;
  final String countryCode;
  final String favicon;
  final List<String> tags;
  final String codec;
  final int bitrateKbps;
  final int votes;
  final int clickCount;

  RadioStation toStation() => RadioStation(
        id: id,
        name: name,
        streamUrl: streamUrl,
        countryCode: countryCode,
        favicon: favicon,
        tags: tags,
        codec: codec,
        bitrateKbps: bitrateKbps,
        votes: votes,
        clickCount: clickCount,
      );
}

Future<List<_Candidate>> _fetchStationsForCountry(
  http.Client client,
  String apiBase,
  String countryCode,
) async {
  final uri = Uri.parse(
    '$apiBase/json/stations/bycountrycodeexact/$countryCode',
  ).replace(
    queryParameters: {
      'hidebroken': 'true',
      'order': 'clickcount',
      'reverse': 'true',
    },
  );

  final response = await client
      .get(uri, headers: {'User-Agent': _userAgent})
      .timeout(_requestTimeout);
  if (response.statusCode != 200) {
    stderr.writeln(
      'WARN: $countryCode station fetch failed (${response.statusCode})',
    );
    return const [];
  }

  final raw = jsonDecode(response.body) as List<dynamic>;
  final candidates = raw.take(_maxStationsPerCountry).map((entry) {
    final map = entry as Map<String, dynamic>;
    final resolvedUrl = (map['url_resolved'] as String?)?.trim() ?? '';
    final url = (map['url'] as String?)?.trim() ?? '';
    return _Candidate(
      id: map['stationuuid'] as String,
      name: (map['name'] as String? ?? '').trim(),
      streamUrl: resolvedUrl.isNotEmpty ? resolvedUrl : url,
      countryCode: countryCode,
      favicon: (map['favicon'] as String? ?? '').trim(),
      tags: (map['tags'] as String? ?? '')
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList(),
      codec: (map['codec'] as String? ?? '').trim(),
      bitrateKbps: (map['bitrate'] as num? ?? 0).toInt(),
      votes: (map['votes'] as num? ?? 0).toInt(),
      clickCount: (map['clickcount'] as num? ?? 0).toInt(),
    );
  }).where((c) => c.name.isNotEmpty && c.streamUrl.isNotEmpty);

  return candidates.toList();
}

/// Extra seed stations from a static radio-browser.info-shaped export
/// (bonus_stations.json, sitting next to this script) — same field
/// mapping as the live API response, just read from a local file instead
/// of fetched over HTTP. Optional: silently skipped if the file isn't
/// there.
Future<List<_Candidate>> _loadBonusCandidates() async {
  final file = File('bonus_stations.json');
  if (!await file.exists()) return const [];

  final raw = jsonDecode(await file.readAsString()) as List<dynamic>;
  return raw
      .map((entry) {
        final map = entry as Map<String, dynamic>;
        final resolvedUrl = (map['url_resolved'] as String?)?.trim() ?? '';
        final url = (map['url'] as String?)?.trim() ?? '';
        final countryCode =
            (map['countrycode'] as String? ?? '').trim().toUpperCase();
        return _Candidate(
          id: map['stationuuid'] as String,
          name: (map['name'] as String? ?? '').trim(),
          streamUrl: resolvedUrl.isNotEmpty ? resolvedUrl : url,
          countryCode: countryCode,
          favicon: (map['favicon'] as String? ?? '').trim(),
          tags: (map['tags'] as String? ?? '')
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toList(),
          codec: (map['codec'] as String? ?? '').trim(),
          bitrateKbps: (map['bitrate'] as num? ?? 0).toInt(),
          votes: (map['votes'] as num? ?? 0).toInt(),
          clickCount: (map['clickcount'] as num? ?? 0).toInt(),
        );
      })
      .where(
        (c) =>
            c.name.isNotEmpty &&
            c.streamUrl.isNotEmpty &&
            c.countryCode.isNotEmpty,
      )
      .toList();
}

Future<List<RadioStation>> _verifyStreams(
  http.Client client,
  List<_Candidate> candidates,
) async {
  final pool = Pool(_concurrentChecks);
  final results = <RadioStation>[];

  await Future.wait(candidates.map((candidate) {
    return pool.withResource(() async {
      if (await _isStreamReachable(client, candidate.streamUrl)) {
        results.add(candidate.toStation());
      }
    });
  }));

  await pool.close();
  return results;
}

Future<bool> _isStreamReachable(http.Client client, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
    return false;
  }

  http.StreamedResponse? response;
  try {
    final request = http.Request('GET', uri)
      ..headers['User-Agent'] = _userAgent
      // Ask Icecast/Shoutcast not to interleave metadata frames into the
      // body — we're only inspecting the response headers anyway.
      ..headers['Icy-MetaData'] = '0';

    response = await client.send(request).timeout(_requestTimeout);

    final statusOk = response.statusCode >= 200 && response.statusCode < 400;
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    return statusOk && _looksLikeAudio(contentType);
  } catch (_) {
    return false;
  } finally {
    // Headers are already available on StreamedResponse before the body
    // is read — cancel now instead of buffering an endless live stream.
    unawaited(response?.stream.listen((_) {}).cancel());
  }
}

bool _looksLikeAudio(String contentType) {
  if (contentType.isEmpty) {
    // Some Icecast/Shoutcast mounts omit Content-Type entirely. We already
    // filtered on hidebroken=true upstream, so treat "empty but 2xx/3xx"
    // as acceptable rather than penalizing valid streams twice.
    return true;
  }
  const audioMarkers = [
    'audio/',
    'application/ogg',
    'application/octet-stream',
  ];
  return audioMarkers.any(contentType.contains);
}

List<RadioStation> _deduplicate(List<RadioStation> stations) {
  final byKey = <String, RadioStation>{};
  for (final station in stations) {
    final key = '${station.name.trim().toLowerCase()}|${station.countryCode}';
    final current = byKey[key];
    if (current == null || _isBetterDuplicate(station, current)) {
      byKey[key] = station;
    }
  }
  return byKey.values.toList();
}

/// Which of two same-name entries to keep: the more-clicked one is more
/// likely to be the mirror people actually found and listened to, not a
/// stale/abandoned duplicate submission.
bool _isBetterDuplicate(RadioStation candidate, RadioStation current) {
  if (candidate.clickCount != current.clickCount) {
    return candidate.clickCount > current.clickCount;
  }
  return candidate.votes > current.votes;
}

String _hashStations(List<RadioStation> stations) {
  final sortedIds = stations.map((s) => '${s.id}:${s.streamUrl}').toList()
    ..sort();
  return sha256.convert(utf8.encode(sortedIds.join('|'))).toString();
}
