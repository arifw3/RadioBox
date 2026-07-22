// One-off import: merges a user-supplied scrape (tum_radyolar.json, from
// canliradyodinle.fm) into the existing radios.json. Not part of the
// nightly pipeline — this is manual data with local images, run once
// (and re-run by hand if the user provides an updated scrape).
//
// Usage:
//   dart run bin/import_custom_stations.dart <tum_radyolar.json> <source_images_dir> <radios.json> <dest_images_dir>

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dialwave_core/dialwave_core.dart';
import 'package:http/http.dart' as http;
import 'package:pool/pool.dart';

const _userAgent =
    'DialWave-RadioSync/1.0 (+https://github.com/dialwave/dialwave)';
const _concurrentChecks = 24;
const _requestTimeout = Duration(seconds: 8);

Future<void> main(List<String> args) async {
  if (args.length < 4) {
    stderr.writeln(
      'Usage: dart run bin/import_custom_stations.dart '
      '<tum_radyolar.json> <source_images_dir> <radios.json> <dest_images_dir>',
    );
    exit(64);
  }
  final sourceJsonPath = args[0];
  final imagesDir = args[1];
  final existingCatalogPath = args[2];
  final outputImagesDir = args[3];

  final raw =
      jsonDecode(await File(sourceJsonPath).readAsString()) as List<dynamic>;
  stderr.writeln('Loaded ${raw.length} candidate entries');

  final candidates = raw.map((e) => e as Map<String, dynamic>).where((e) {
    final url = e['canli_yayin_linki'] as String? ?? '';
    return url.startsWith('http://') || url.startsWith('https://');
  }).toList();
  stderr.writeln(
    '${candidates.length} have a usable stream URL '
    '(${raw.length - candidates.length} were already broken — no host in the URL)',
  );

  final client = http.Client();
  final pool = Pool(_concurrentChecks);
  final verified = <Map<String, dynamic>>[];

  await Future.wait(candidates.map((entry) {
    return pool.withResource(() async {
      final url = entry['canli_yayin_linki'] as String;
      if (await _isStreamReachable(client, url)) {
        verified.add(entry);
      }
    });
  }));
  await pool.close();
  client.close();
  stderr.writeln('${verified.length}/${candidates.length} verified reachable');

  final existingRaw =
      jsonDecode(await File(existingCatalogPath).readAsString())
          as Map<String, dynamic>;
  final existingCatalog = RadioCatalog.fromJson(existingRaw);
  final existingNames =
      existingCatalog.stations.map((s) => s.name.trim().toLowerCase()).toSet();

  await Directory(outputImagesDir).create(recursive: true);

  final newStations = <RadioStation>[];
  var skippedDuplicate = 0;
  var skippedMissingImage = 0;

  for (final entry in verified) {
    final name = (entry['radyo_adi'] as String).trim();
    if (existingNames.contains(name.toLowerCase())) {
      skippedDuplicate++;
      continue;
    }

    final localImageRel =
        (entry['yerel_gorsel_yolu'] as String? ?? '').replaceAll(r'\', '/');
    final imageFileName =
        localImageRel.isEmpty ? '' : localImageRel.split('/').last;
    final sourceImageFile = File('$imagesDir/$imageFileName');

    var favicon = '';
    if (imageFileName.isNotEmpty && await sourceImageFile.exists()) {
      final destFile = File('$outputImagesDir/$imageFileName');
      await sourceImageFile.copy(destFile.path);
      favicon =
          'https://cdn.jsdelivr.net/gh/arifw3/RadioBox@main/images/$imageFileName';
    } else {
      skippedMissingImage++;
    }

    newStations.add(
      RadioStation(
        id: 'tr-custom-${entry['id']}',
        name: name,
        streamUrl: entry['canli_yayin_linki'] as String,
        countryCode: 'TR',
        favicon: favicon,
      ),
    );
  }

  stderr.writeln(
    '${newStations.length} new stations to add '
    '($skippedDuplicate skipped as name-duplicates of existing stations, '
    '$skippedMissingImage missing their local image file)',
  );

  final merged = [...existingCatalog.stations, ...newStations];
  final catalog = RadioCatalog(
    version: _hashStations(merged),
    generatedAtUtc: DateTime.now().toUtc(),
    stations: merged,
  );

  await File(
    existingCatalogPath,
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(catalog.toJson()));
  stderr.writeln('Wrote ${merged.length} total stations -> $existingCatalogPath');
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
      ..headers['Icy-MetaData'] = '0';
    response = await client.send(request).timeout(_requestTimeout);

    final statusOk = response.statusCode >= 200 && response.statusCode < 400;
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    return statusOk && _looksLikeAudio(contentType);
  } catch (_) {
    return false;
  } finally {
    unawaited(response?.stream.listen((_) {}).cancel());
  }
}

bool _looksLikeAudio(String contentType) {
  if (contentType.isEmpty) return true;
  const audioMarkers = ['audio/', 'application/ogg', 'application/octet-stream'];
  return audioMarkers.any(contentType.contains);
}

String _hashStations(List<RadioStation> stations) {
  final sortedIds = stations.map((s) => '${s.id}:${s.streamUrl}').toList()
    ..sort();
  return sha256.convert(utf8.encode(sortedIds.join('|'))).toString();
}
