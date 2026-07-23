// One-off scraper (not part of the nightly job): pulls the Turkish station
// catalog from turkradyodinle.com and writes it in the same
// radio-browser.info-shaped JSON that bonus_stations.json already uses, so
// radio_sync.dart can merge it in with zero extra parsing logic.
//
// Usage: dart run bin/turkradyodinle_scrape.dart [output-path]
//
// Site structure (confirmed by inspecting raw HTML, 2026-07-23):
// - https://turkradyodinle.com/radyolar lists every station as a plain
//   <a href="/radyo/{slug}"> link — no pagination, so one fetch finds all
//   slugs.
// - Each station page embeds a schema.org RadioStation JSON-LD block
//   (name, logo, genre) AND a separate plain-HTML "info card" with the
//   actual stream URL under a "Kaynak" label:
//     <p class="text-xs ... text-muted">Kaynak</p>
//     <p class="mt-1 ... text-foreground">{stream url}</p>
//   (same repeated pattern for "Yayın" = MIME type and "Bitrate").
//
// The dev machine's local antivirus (Avast) intercepts HTTPS with its own
// cert, which trips Dart's default certificate validation for domains it
// mishandles — badCertificateCallback below routes around that, same as
// `curl -k` did during investigation. This only affects reading public
// marketing pages, not anything sensitive.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:pool/pool.dart';

const _baseUrl = 'https://turkradyodinle.com';
const _userAgent =
    'DialWave-CatalogResearch/1.0 (+https://github.com/dialwave/dialwave)';
const _concurrentFetches = 8;
const _requestTimeout = Duration(seconds: 10);

Future<void> main(List<String> args) async {
  final httpClient = HttpClient()
    ..badCertificateCallback = (cert, host, port) => true;
  final client = IOClient(httpClient);

  try {
    final slugs = await _fetchAllSlugs(client);
    stderr.writeln('turkradyodinle.com: ${slugs.length} station slugs found');

    final pool = Pool(_concurrentFetches);
    final stations = <Map<String, dynamic>>[];
    var failed = 0;

    await Future.wait(slugs.map((slug) {
      return pool.withResource(() async {
        final station = await _scrapeStation(client, slug);
        if (station != null) {
          stations.add(station);
        } else {
          failed++;
        }
      });
    }));
    await pool.close();

    stderr.writeln(
      '${stations.length}/${slugs.length} station pages yielded a usable stream URL '
      '($failed skipped)',
    );

    final outFile = File(_resolveOutputPath(args));
    await outFile.create(recursive: true);
    await outFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(stations),
    );
    stderr.writeln('Wrote ${stations.length} stations -> ${outFile.path}');
  } finally {
    client.close();
  }
}

String _resolveOutputPath(List<String> args) {
  if (args.isNotEmpty) return args.first;
  return 'turkradyodinle_stations.json';
}

Future<List<String>> _fetchAllSlugs(http.Client client) async {
  final response = await client.get(
    Uri.parse('$_baseUrl/radyolar'),
    headers: {'User-Agent': _userAgent},
  ).timeout(_requestTimeout);

  if (response.statusCode != 200) {
    throw StateError('Failed to fetch /radyolar: HTTP ${response.statusCode}');
  }

  final slugPattern = RegExp(r'/radyo/([a-z0-9-]+)');
  final slugs = slugPattern
      .allMatches(response.body)
      .map((m) => m.group(1)!)
      .toSet() // de-dupe (each link appears twice: card + JSON-LD)
      .toList()
    ..sort();
  return slugs;
}

final _jsonLdPattern = RegExp(
  r'<script type="application/ld\+json">(.*?)</script>',
  dotAll: true,
);

final _infoFieldPattern = RegExp(
  r'<p class="text-xs font-black uppercase tracking-\[0\.12em\] text-muted">([^<]+)</p>'
  r'<p class="mt-1 break-words font-mono text-xs text-foreground">([^<]*)</p>',
);

Future<Map<String, dynamic>?> _scrapeStation(
  http.Client client,
  String slug,
) async {
  try {
    final response = await client.get(
      Uri.parse('$_baseUrl/radyo/$slug'),
      headers: {'User-Agent': _userAgent},
    ).timeout(_requestTimeout);
    if (response.statusCode != 200) return null;

    final body = utf8.decode(response.bodyBytes);

    // Structured fields (name, logo, genre) from the schema.org block.
    String name = '';
    String logo = '';
    var tags = <String>[];
    for (final match in _jsonLdPattern.allMatches(body)) {
      Map<String, dynamic>? data;
      try {
        final decoded = jsonDecode(match.group(1)!);
        data = decoded is Map<String, dynamic> ? decoded : null;
      } catch (_) {
        continue;
      }
      if (data == null || data['@type'] != 'RadioStation') continue;
      name = (data['name'] as String? ?? '').trim();
      logo = (data['logo'] as String? ?? data['image'] as String? ?? '').trim();
      final genre = data['genre'];
      if (genre is List) {
        tags = genre.map((g) => g.toString()).toList();
      } else if (genre is String && genre.isNotEmpty) {
        tags = [genre];
      }
      break;
    }
    if (name.isEmpty) return null;

    // Plain-HTML info card (stream URL, MIME type, bitrate).
    String streamUrl = '';
    String mimeType = '';
    var bitrateKbps = 0;
    for (final match in _infoFieldPattern.allMatches(body)) {
      final label = match.group(1)!.trim();
      final value = match.group(2)!.trim();
      switch (label) {
        case 'Kaynak':
          streamUrl = value;
        case 'Yayın':
          mimeType = value;
        case 'Bitrate':
          bitrateKbps = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      }
    }
    if (streamUrl.isEmpty) return null;
    final streamUri = Uri.tryParse(streamUrl);
    if (streamUri == null ||
        !(streamUri.isScheme('http') || streamUri.isScheme('https'))) {
      return null;
    }

    return {
      'stationuuid': 'trd-$slug',
      'name': name,
      'url_resolved': streamUrl,
      'countrycode': 'TR',
      'favicon': logo,
      'tags': tags.join(','),
      'codec': _codecFor(mimeType, streamUrl),
      'bitrate': bitrateKbps,
      'votes': 0,
      'clickcount': 0,
    };
  } catch (e) {
    stderr.writeln('WARN: $slug failed: $e');
    return null;
  }
}

String _codecFor(String mimeType, String streamUrl) {
  final lowerMime = mimeType.toLowerCase();
  final lowerUrl = streamUrl.toLowerCase();
  if (lowerMime.contains('mpegurl') || lowerUrl.endsWith('.m3u8')) return 'HLS';
  if (lowerMime.contains('aac')) return 'AAC';
  if (lowerMime.contains('mpeg') || lowerUrl.endsWith('.mp3')) return 'MP3';
  if (lowerMime.contains('ogg')) return 'OGG';
  return '';
}
