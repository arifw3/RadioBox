// One-off maintenance script: scans images/ for files named exactly
// "{stationId}.{ext}" (the convention given to the user for manually
// sourced logos — see empty_favicon_list.txt) and points that station's
// favicon at the jsDelivr-served copy. Only touches stations whose
// favicon is currently empty, and only accepts files that actually
// decode as a reasonably-sized image — a corrupt/tiny download shouldn't
// silently become the new "favicon".
//
// Usage: dart run bin/apply_manual_favicons.dart [radios.json path] [images dir]

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dialwave_core/dialwave_core.dart';
import 'package:image/image.dart' as img;

const _minDimension = 32;

Future<void> main(List<String> args) async {
  final radiosPath = args.isNotEmpty ? args[0] : 'd:/Dev/DialWave/radios.json';
  final imagesDir = args.length > 1 ? args[1] : 'd:/Dev/DialWave/images';

  final catalog = RadioCatalog.fromJson(
    jsonDecode(await File(radiosPath).readAsString()) as Map<String, dynamic>,
  );
  final stationsById = {for (final s in catalog.stations) s.id: s};

  final files = Directory(imagesDir).listSync().whereType<File>();
  final updated = <String, RadioStation>{};
  var noMatchingStation = 0;
  var alreadyHadFavicon = 0;
  var invalidImage = 0;
  var tooSmall = 0;

  for (final file in files) {
    final fileName = file.uri.pathSegments.last;
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0) continue;
    final stationId = fileName.substring(0, dot);

    final station = stationsById[stationId];
    if (station == null) {
      noMatchingStation++;
      continue;
    }
    if (station.favicon.isNotEmpty) {
      alreadyHadFavicon++;
      continue;
    }

    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      invalidImage++;
      continue;
    }

    final decoded = fileName.toLowerCase().endsWith('.svg')
        ? null // package:image doesn't decode SVG; accept on file presence alone.
        : img.decodeImage(bytes);
    if (!fileName.toLowerCase().endsWith('.svg')) {
      if (decoded == null) {
        stderr.writeln('  SKIP (not a decodable image): $fileName');
        invalidImage++;
        continue;
      }
      if (decoded.width < _minDimension || decoded.height < _minDimension) {
        stderr.writeln(
          '  SKIP (${decoded.width}x${decoded.height}, too small): $fileName',
        );
        tooSmall++;
        continue;
      }
    }

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
    stderr.writeln('  APPLY ${station.name} ($stationId) -> $fileName');
  }

  stderr.writeln(
    'Done. ${updated.length} applied, $noMatchingStation no matching station id, '
    '$alreadyHadFavicon already had a favicon, $invalidImage invalid/undecodable, '
    '$tooSmall too small.',
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
