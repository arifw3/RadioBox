// One-off maintenance script: for TR stations with an empty or broken
// favicon, checks whether tum_radyolar.json (the canliradyodinle.fm scrape
// already used once by import_custom_stations.dart) has a same-named
// station with a local image — and if so, copies that image into images/
// and points the station's favicon at it, the same jsDelivr-served way
// import_custom_stations.dart already does for the 361 stations it added.
//
// Why these weren't already covered: that script only ADDS stations whose
// name isn't already in the catalog. Many of these 88 already existed
// (via radio-browser.info) with no/broken favicon, so their same-named
// scrape entry — image and all — was silently skipped as a duplicate.
//
// Usage: dart run bin/backfill_tr_favicons_local.dart <tum_radyolar.json>
//   <source_images_dir> <radios.json> <dest_images_dir>

import 'dart:convert';
import 'dart:io';

import 'package:dialwave_core/dialwave_core.dart';

Future<void> main(List<String> args) async {
  if (args.length < 4) {
    stderr.writeln(
      'Usage: dart run bin/backfill_tr_favicons_local.dart '
      '<tum_radyolar.json> <source_images_dir> <radios.json> <dest_images_dir>',
    );
    exit(64);
  }
  final sourceJsonPath = args[0];
  final sourceImagesDir = args[1];
  final radiosPath = args[2];
  final destImagesDir = args[3];

  final raw =
      jsonDecode(await File(sourceJsonPath).readAsString()) as List<dynamic>;
  final lookup = <String, String>{}; // normalized name -> image file name
  for (final entry in raw) {
    final map = entry as Map<String, dynamic>;
    final name = (map['radyo_adi'] as String? ?? '').trim();
    final localPath =
        (map['yerel_gorsel_yolu'] as String? ?? '').replaceAll(r'\', '/');
    final fileName = localPath.isEmpty ? '' : localPath.split('/').last;
    if (name.isEmpty || fileName.isEmpty) continue;
    for (final key in _normalizedVariants(name)) {
      lookup.putIfAbsent(key, () => fileName);
    }
  }
  stderr.writeln('tum_radyolar.json: ${lookup.length} name variants indexed');

  final catalog = RadioCatalog.fromJson(
    jsonDecode(await File(radiosPath).readAsString()) as Map<String, dynamic>,
  );

  await Directory(destImagesDir).create(recursive: true);

  final updated = <String, RadioStation>{};
  var matched = 0;
  var missingFile = 0;

  for (final station in catalog.stations) {
    if (station.countryCode != 'TR') continue;
    if (station.favicon.isNotEmpty && !station.favicon.contains('null')) {
      continue; // only backfill empty or the known "null"-string bug
    }

    String? fileName;
    for (final key in _normalizedVariants(station.name)) {
      final hit = lookup[key];
      if (hit != null) {
        fileName = hit;
        break;
      }
    }
    if (fileName == null) continue;
    matched++;

    final sourceFile = File('$sourceImagesDir/$fileName');
    if (!await sourceFile.exists()) {
      missingFile++;
      continue;
    }

    final destFile = File('$destImagesDir/$fileName');
    if (!await destFile.exists()) {
      await sourceFile.copy(destFile.path);
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
    stderr.writeln('  BACKFILL ${station.name} -> $fileName');
  }

  stderr.writeln(
    'Done. $matched matched by name, ${updated.length} images copied+applied, '
    '$missingFile matched but source image file missing.',
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
  return buffer.toString().replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();
}

/// Both with and without a leading/trailing "radyo" token, since the scrape
/// often prefixes it ("Radyo Türkülerle Türkiye") while our catalog entry
/// may not ("Türkülerle Türkiye"), or vice versa.
Iterable<String> _normalizedVariants(String name) sync* {
  final normalized = _normalize(name);
  final collapsed = normalized.replaceAll(' ', '');
  yield collapsed;
  final withoutRadyo = normalized
      .split(' ')
      .where((w) => w != 'radyo')
      .join('');
  if (withoutRadyo != collapsed) yield withoutRadyo;
}
