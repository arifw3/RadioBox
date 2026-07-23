// One-off diagnostic: for stations whose favicon actually loads, checks
// its real pixel dimensions and — for low-res ones — tries a handful of
// common high-resolution icon paths on the same origin plus the site's
// Open Graph image tag, reporting any better candidate found. Does NOT
// modify radios.json.
//
// Usage: dart run bin/favicon_resolution_report.dart [radios.json path] [country code] [report path]

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dialwave_core/dialwave_core.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:pool/pool.dart';

const _userAgent =
    'DialWave-FaviconCheck/1.0 (+https://github.com/arifw3/RadioBox)';
const _concurrentChecks = 16;
const _requestTimeout = Duration(seconds: 8);
const _minAcceptableSize = 150;

const _candidatePaths = [
  '/apple-touch-icon.png',
  '/apple-touch-icon-precomposed.png',
  '/android-chrome-512x512.png',
  '/android-chrome-192x192.png',
  '/favicon-512x512.png',
  '/favicon-256x256.png',
  '/logo512.png',
  '/logo.png',
];

Future<void> main(List<String> args) async {
  final radiosPath = args.isNotEmpty ? args[0] : 'd:/Dev/DialWave/radios.json';
  final countryFilter = args.length > 1 ? args[1] : null;
  final reportPath = args.length > 2
      ? args[2]
      : 'd:/Dev/DialWave/favicon_resolution_report.txt';

  final catalog = RadioCatalog.fromJson(
    jsonDecode(await File(radiosPath).readAsString()) as Map<String, dynamic>,
  );

  final stations = countryFilter == null
      ? catalog.stations
      : catalog.stations
          .where((s) => s.countryCode == countryFilter)
          .toList();

  stderr.writeln('Checking favicon resolution for ${stations.length} stations...');

  final client = http.Client();
  final pool = Pool(_concurrentChecks);
  final lowRes = <_LowResEntry>[];
  var checked = 0;

  try {
    await Future.wait(
      stations.map((station) {
        return pool.withResource(() async {
          checked++;
          if (checked % 50 == 0) {
            stderr.writeln('  $checked/${stations.length}...');
          }
          if (station.favicon.isEmpty) return;

          final dims = await _fetchImageDimensions(client, station.favicon);
          if (dims == null) return; // unreadable — link_report.dart already covers this
          if (dims.$1 >= _minAcceptableSize && dims.$2 >= _minAcceptableSize) {
            return;
          }

          final candidate = await _findBetterCandidate(
            client,
            station.favicon,
            dims,
          );
          lowRes.add(
            _LowResEntry(
              station: station,
              currentSize: dims,
              candidateUrl: candidate?.$1,
              candidateSize: candidate?.$2,
            ),
          );
        });
      }),
    );
  } finally {
    await pool.close();
    client.close();
  }

  final buffer = StringBuffer()
    ..writeln('# Düşük Çözünürlüklü Görsel Raporu')
    ..writeln('Kontrol edilen istasyon: ${stations.length}')
    ..writeln('Eşik: ${_minAcceptableSize}x$_minAcceptableSize px altı')
    ..writeln('Tarih: ${DateTime.now().toIso8601String()}')
    ..writeln()
    ..writeln('## Düşük çözünürlüklü görseller (${lowRes.length})');
  for (final entry in lowRes) {
    final current = '${entry.currentSize.$1}x${entry.currentSize.$2}';
    if (entry.candidateUrl != null) {
      final candSize = '${entry.candidateSize!.$1}x${entry.candidateSize!.$2}';
      buffer.writeln(
        '- [${entry.station.id}] ${entry.station.name} (${entry.station.countryCode}): '
        'MEVCUT $current -> ${entry.station.favicon}\n'
        '    ÖNERİLEN $candSize -> ${entry.candidateUrl}',
      );
    } else {
      buffer.writeln(
        '- [${entry.station.id}] ${entry.station.name} (${entry.station.countryCode}): '
        'MEVCUT $current -> ${entry.station.favicon}\n'
        '    (daha iyi versiyon bulunamadı)',
      );
    }
  }

  await File(reportPath).writeAsString(buffer.toString());
  final withCandidate = lowRes.where((e) => e.candidateUrl != null).length;
  stderr.writeln(
    'Done. ${lowRes.length} low-res, $withCandidate with a better candidate found.',
  );
  stderr.writeln('Report: $reportPath');
}

class _LowResEntry {
  _LowResEntry({
    required this.station,
    required this.currentSize,
    this.candidateUrl,
    this.candidateSize,
  });
  final RadioStation station;
  final (int, int) currentSize;
  final String? candidateUrl;
  final (int, int)? candidateSize;
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

/// Hosts we serve station art from ourselves — guessing icon paths on
/// these origins finds THEIR site-wide branding, not anything related to
/// the station. Bit us for real: 30 already-correctly-self-hosted TR
/// favicons under 150px got silently replaced with jsDelivr's own promo
/// graphic because "origin" of a cdn.jsdelivr.net/gh/... URL is just
/// cdn.jsdelivr.net, and /apple-touch-icon.png on THAT resolved to a real
/// (unrelated) image.
const _selfHostedOrigins = ['https://cdn.jsdelivr.net'];

Future<(String, (int, int))?> _findBetterCandidate(
  http.Client client,
  String faviconUrl,
  (int, int) currentSize,
) async {
  final origin = Uri.tryParse(faviconUrl)?.origin;
  if (origin == null || _selfHostedOrigins.contains(origin)) return null;

  (String, (int, int))? best;

  for (final path in _candidatePaths) {
    final candidateUrl = '$origin$path';
    final dims = await _fetchImageDimensions(client, candidateUrl);
    if (dims == null) continue;
    if (dims.$1 <= currentSize.$1 && dims.$2 <= currentSize.$2) continue;
    if (best == null || (dims.$1 * dims.$2) > (best.$2.$1 * best.$2.$2)) {
      best = (candidateUrl, dims);
    }
  }

  // Open Graph image tag on the homepage — often a large banner/logo,
  // worth trying even if none of the common icon paths panned out.
  final ogImage = await _findOgImage(client, origin);
  if (ogImage != null) {
    final dims = await _fetchImageDimensions(client, ogImage);
    if (dims != null &&
        (dims.$1 > currentSize.$1 || dims.$2 > currentSize.$2) &&
        (best == null || (dims.$1 * dims.$2) > (best.$2.$1 * best.$2.$2))) {
      best = (ogImage, dims);
    }
  }

  return best;
}

Future<String?> _findOgImage(http.Client client, String origin) async {
  try {
    final response = await client
        .get(Uri.parse(origin), headers: {'User-Agent': _userAgent})
        .timeout(_requestTimeout);
    if (response.statusCode != 200) return null;
    final match = RegExp(
      '''<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(response.body);
    final url = match?.group(1);
    if (url == null) return null;
    return Uri.tryParse(origin)?.resolve(url).toString();
  } catch (_) {
    return null;
  }
}
