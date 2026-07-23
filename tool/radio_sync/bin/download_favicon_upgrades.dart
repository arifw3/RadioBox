// One-off maintenance script: reads the "ÖNERİLEN" (suggested) candidate
// favicons out of favicon_resolution_report.txt, downloads the ones that
// are actually a real improvement, commits them to images/, and points
// the station's favicon at the jsDelivr-served local copy instead of the
// original (often small, foreign, or unreliable) host.
//
// The report's own candidate-picking rule only requires ONE dimension to
// be bigger (a leftover from favicon_resolution_report.dart), which lets
// through bad candidates — e.g. a 212x40 banner crop "beating" a 144x144
// square icon just because it's wider. This script re-measures every
// candidate itself and applies a real filter: meaningfully larger area,
// not a wildly non-square crop.
//
// Usage: dart run bin/download_favicon_upgrades.dart [report path] [radios.json path] [images dir]

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dialwave_core/dialwave_core.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:pool/pool.dart';

const _userAgent =
    'DialWave-FaviconDownload/1.0 (+https://github.com/arifw3/RadioBox)';
const _concurrentChecks = 12;
const _requestTimeout = Duration(seconds: 10);
const _minAreaMultiplier = 1.2;
const _minDimension = 96;
const _maxAspectRatio = 2.5;

final _entryPattern = RegExp(
  r'^- \[([^\]]+)\].*?MEVCUT \d+x\d+ -> \S+\n\s+ÖNERİLEN (\d+)x(\d+) -> (\S+)$',
  multiLine: true,
);

Future<void> main(List<String> args) async {
  final reportPath = args.isNotEmpty ? args[0] : 'd:/Dev/DialWave/favicon_resolution_report.txt';
  final radiosPath = args.length > 1 ? args[1] : 'd:/Dev/DialWave/radios.json';
  final imagesDir = args.length > 2 ? args[2] : 'd:/Dev/DialWave/images';

  final reportText = await File(reportPath).readAsString();
  final candidates = _entryPattern.allMatches(reportText).map((m) {
    return (
      id: m.group(1)!,
      reportedWidth: int.parse(m.group(2)!),
      reportedHeight: int.parse(m.group(3)!),
      url: m.group(4)!,
    );
  }).toList();
  stderr.writeln('Parsed ${candidates.length} candidate entries from the report');

  final catalog = RadioCatalog.fromJson(
    jsonDecode(await File(radiosPath).readAsString()) as Map<String, dynamic>,
  );
  final stationsById = {for (final s in catalog.stations) s.id: s};

  await Directory(imagesDir).create(recursive: true);

  final client = http.Client();
  final pool = Pool(_concurrentChecks);
  final updated = <String, RadioStation>{};
  var rejectedNotBigger = 0;
  var rejectedAspect = 0;
  var rejectedFetchFailed = 0;
  var skippedNoLongerInCatalog = 0;

  try {
    await Future.wait(candidates.map((candidate) {
      return pool.withResource(() async {
        final station = stationsById[candidate.id];
        if (station == null) {
          skippedNoLongerInCatalog++;
          return;
        }

        final bytes = await _fetchBytes(client, candidate.url);
        if (bytes == null) {
          rejectedFetchFailed++;
          return;
        }
        final decoded = img.decodeImage(bytes);
        if (decoded == null) {
          rejectedFetchFailed++;
          return;
        }

        final w = decoded.width;
        final h = decoded.height;
        if (w < _minDimension || h < _minDimension) {
          rejectedAspect++;
          return;
        }
        final aspect = w > h ? w / h : h / w;
        if (aspect > _maxAspectRatio) {
          rejectedAspect++;
          return;
        }

        final currentDims = station.favicon.isEmpty
            ? null
            : await _fetchImageDimensions(client, station.favicon);
        final currentArea = currentDims == null ? 0 : currentDims.$1 * currentDims.$2;
        final candidateArea = w * h;
        if (currentArea > 0 && candidateArea < currentArea * _minAreaMultiplier) {
          rejectedNotBigger++;
          return;
        }

        // Always PNG, regardless of the source format: images/*.webp is
        // gitignored (it was added for unrelated orphaned scratch files),
        // and re-encoding here is free since decodeImage() already ran.
        final fileName = '${station.id}-favicon-upgrade.png';
        final destFile = File('$imagesDir/$fileName');
        await destFile.writeAsBytes(img.encodePng(decoded));

        updated[station.id] = RadioStation(
          id: station.id,
          name: station.name,
          streamUrl: station.streamUrl,
          countryCode: station.countryCode,
          favicon: 'https://cdn.jsdelivr.net/gh/arifw3/RadioBox@main/images/$fileName',
          tags: station.tags,
          codec: station.codec,
          bitrateKbps: station.bitrateKbps,
          votes: station.votes,
          clickCount: station.clickCount,
        );
        stderr.writeln('  UPGRADE ${station.name}: ${w}x$h -> $fileName');
      });
    }));
  } finally {
    await pool.close();
    client.close();
  }

  stderr.writeln(
    'Done. ${updated.length} downloaded+applied, '
    '$rejectedNotBigger not meaningfully bigger, '
    '$rejectedAspect too small/non-square, '
    '$rejectedFetchFailed fetch/decode failed, '
    '$skippedNoLongerInCatalog no longer in catalog.',
  );

  if (updated.isEmpty) return;

  final newStations = catalog.stations.map((s) => updated[s.id] ?? s).toList();
  final newCatalog = RadioCatalog(
    version: catalog.version,
    generatedAtUtc: catalog.generatedAtUtc,
    stations: newStations,
  );
  await File(radiosPath).writeAsString(
    const JsonEncoder.withIndent('  ').convert(newCatalog.toJson()),
  );
  stderr.writeln('Wrote $radiosPath');
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
