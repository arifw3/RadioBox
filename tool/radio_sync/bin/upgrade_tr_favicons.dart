// One-off maintenance script: for Turkish stations, tries to replace a
// low-resolution favicon with the logo turkradyodinle.com has on file for
// the same station (matched by normalized name). Only swaps in a
// candidate that is actually higher-resolution than what's there today —
// never downgrades. Modifies radios.json directly.
//
// Usage: dart run bin/upgrade_tr_favicons.dart [radios.json path]

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dialwave_core/dialwave_core.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:pool/pool.dart';

const _userAgent =
    'DialWave-FaviconUpgrade/1.0 (+https://github.com/arifw3/RadioBox)';
const _concurrentChecks = 12;
const _requestTimeout = Duration(seconds: 8);
// Below this, treat a "successfully decoded" image as too small to trust
// as a real logo (e.g. a 1x1 tracking pixel or placeholder).
const _minCandidateSize = 48;

Future<void> main(List<String> args) async {
  final radiosPath = args.isNotEmpty ? args[0] : 'd:/Dev/DialWave/radios.json';

  final catalog = RadioCatalog.fromJson(
    jsonDecode(await File(radiosPath).readAsString()) as Map<String, dynamic>,
  );

  final lookup = await _loadTurkradyodinleLookup();
  stderr.writeln('turkradyodinle_stations.json: ${lookup.length} name -> logo entries');

  final client = http.Client();
  final pool = Pool(_concurrentChecks);
  final updated = <String, RadioStation>{}; // id -> replacement
  var matched = 0;
  var noMatch = 0;
  var alreadyBest = 0;

  try {
    final trStations =
        catalog.stations.where((s) => s.countryCode == 'TR').toList();
    stderr.writeln('Checking ${trStations.length} TR stations...');

    await Future.wait(trStations.map((station) {
      return pool.withResource(() async {
        final candidateUrl = lookup[_normalize(station.name)];
        if (candidateUrl == null || candidateUrl == station.favicon) {
          if (candidateUrl == null) noMatch++;
          return;
        }
        matched++;

        final currentDims = station.favicon.isEmpty
            ? null
            : await _fetchImageDimensions(client, station.favicon);
        final candidateDims = await _fetchImageDimensions(client, candidateUrl);
        if (candidateDims == null ||
            candidateDims.$1 < _minCandidateSize ||
            candidateDims.$2 < _minCandidateSize) {
          return;
        }

        final currentArea = currentDims == null ? 0 : currentDims.$1 * currentDims.$2;
        final candidateArea = candidateDims.$1 * candidateDims.$2;
        if (candidateArea <= currentArea) {
          alreadyBest++;
          return;
        }

        updated[station.id] = RadioStation(
          id: station.id,
          name: station.name,
          streamUrl: station.streamUrl,
          countryCode: station.countryCode,
          favicon: candidateUrl,
          tags: station.tags,
          codec: station.codec,
          bitrateKbps: station.bitrateKbps,
          votes: station.votes,
          clickCount: station.clickCount,
        );
        stderr.writeln(
          '  UPGRADE ${station.name}: '
          '${currentDims == null ? "yok" : "${currentDims.$1}x${currentDims.$2}"} '
          '-> ${candidateDims.$1}x${candidateDims.$2}',
        );
      });
    }));
  } finally {
    await pool.close();
    client.close();
  }

  if (updated.isEmpty) {
    stderr.writeln(
      'Done. $matched matched, ${updated.length} upgraded, $alreadyBest already best, $noMatch no match.',
    );
    return;
  }

  final newStations = catalog.stations
      .map((s) => updated[s.id] ?? s)
      .toList();
  final newCatalog = RadioCatalog(
    version: catalog.version,
    generatedAtUtc: catalog.generatedAtUtc,
    stations: newStations,
  );

  await File(radiosPath).writeAsString(
    const JsonEncoder.withIndent('  ').convert(newCatalog.toJson()),
  );

  stderr.writeln(
    'Done. $matched matched, ${updated.length} upgraded, $alreadyBest already best, $noMatch no match.',
  );
  stderr.writeln('Wrote $radiosPath');
}

/// Name -> logo URL, sourced from the same turkradyodinle_stations.json
/// snapshot the nightly sync merges in (see turkradyodinle_scrape.dart).
Future<Map<String, String>> _loadTurkradyodinleLookup() async {
  final file = File('turkradyodinle_stations.json');
  if (!await file.exists()) return const {};

  final raw = jsonDecode(await file.readAsString()) as List<dynamic>;
  final lookup = <String, String>{};
  for (final entry in raw) {
    final map = entry as Map<String, dynamic>;
    final name = (map['name'] as String? ?? '').trim();
    final favicon = (map['favicon'] as String? ?? '').trim();
    if (name.isEmpty || favicon.isEmpty) continue;
    lookup[_normalize(name)] = favicon;
  }
  return lookup;
}

const _turkishMap = {
  'ç': 'c', 'Ç': 'c',
  'ğ': 'g', 'Ğ': 'g',
  'ı': 'i', 'I': 'i', 'İ': 'i', 'i': 'i',
  'ö': 'o', 'Ö': 'o',
  'ş': 's', 'Ş': 's',
  'ü': 'u', 'Ü': 'u',
};

String _normalize(String name) {
  final buffer = StringBuffer();
  for (final rune in name.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_turkishMap[ch] ?? ch.toLowerCase());
  }
  return buffer.toString().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

Future<(int, int)?> _fetchImageDimensions(http.Client client, String url) async {
  final bytes = await _fetchBytes(client, url);
  if (bytes == null) return null;
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    return (decoded.width, decoded.height);
  } catch (_) {
    return null;
  }
}

Future<Uint8List?> _fetchBytes(http.Client client, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
    return null;
  }
  try {
    final response = await client
        .get(uri, headers: {'User-Agent': _userAgent})
        .timeout(_requestTimeout);
    if (response.statusCode != 200) return null;
    return response.bodyBytes;
  } catch (_) {
    return null;
  }
}
