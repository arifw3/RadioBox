// One-off maintenance script: stations hosted on Triton Digital's
// StreamTheWorld CDN are commonly stored (by radio-browser.info and
// similar directories) as a URL pinned to one specific edge server, e.g.
// https://25693.live.streamtheworld.com:3690/METRO_FMAAC_SC — but Triton
// rotates/retires those servers over time, which is exactly why "Süper
// FM" and others in this catalog went dead (confirmed via an
// independent curl check, since this dev machine's local network
// produces false-positive broken-link reports).
//
// StreamTheWorld's own player-services endpoint resolves a station's
// stable mount name to whichever server is current, via an HTTP redirect
// — using that instead of a pinned server makes the link self-healing
// forever instead of breaking again on the next rotation. Every mount
// this script rewrites is verified (a real 302 to a live server) before
// being written back; a mount that doesn't resolve is left untouched.
//
// Usage: dart run bin/fix_streamtheworld_urls.dart [radios.json path]

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dialwave_core/dialwave_core.dart';
import 'package:http/http.dart' as http;
import 'package:pool/pool.dart';

const _userAgent =
    'DialWave-StreamTheWorldFix/1.0 (+https://github.com/arifw3/RadioBox)';
const _concurrentChecks = 8;
const _requestTimeout = Duration(seconds: 10);

final _pinnedServerPattern = RegExp(
  r'^https?://(?:\d+\.)?live\.streamtheworld\.com(?::\d+)?/([A-Za-z0-9_.]+)',
);

Future<void> main(List<String> args) async {
  final radiosPath = args.isNotEmpty ? args[0] : 'd:/Dev/DialWave/radios.json';

  final catalog = RadioCatalog.fromJson(
    jsonDecode(await File(radiosPath).readAsString()) as Map<String, dynamic>,
  );

  final client = http.Client();
  final pool = Pool(_concurrentChecks);
  final updated = <String, RadioStation>{};
  var candidates = 0;
  var verified = 0;
  var mountDidNotResolve = 0;

  try {
    await Future.wait(catalog.stations.map((station) {
      return pool.withResource(() async {
        final match = _pinnedServerPattern.firstMatch(station.streamUrl);
        if (match == null) return;
        candidates++;

        final mount = match.group(1)!;
        final redirectUrl =
            'https://playerservices.streamtheworld.com/api/livestream-redirect/$mount';

        final resolvedServer = await _resolvesToLiveServer(client, redirectUrl);
        if (!resolvedServer) {
          mountDidNotResolve++;
          return;
        }
        verified++;

        updated[station.id] = RadioStation(
          id: station.id,
          name: station.name,
          streamUrl: redirectUrl,
          countryCode: station.countryCode,
          favicon: station.favicon,
          tags: station.tags,
          codec: station.codec,
          bitrateKbps: station.bitrateKbps,
          votes: station.votes,
          clickCount: station.clickCount,
        );
        stderr.writeln('  FIX ${station.name}: pinned server -> $redirectUrl');
      });
    }));
  } finally {
    await pool.close();
    client.close();
  }

  stderr.writeln(
    'Done. $candidates pinned-server StreamTheWorld URLs found, '
    '$verified now self-healing redirects, $mountDidNotResolve mounts did not resolve (left untouched).',
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

Future<bool> _resolvesToLiveServer(http.Client client, String url) async {
  try {
    final request = http.Request('GET', Uri.parse(url))
      ..headers['User-Agent'] = _userAgent
      ..followRedirects = false;
    final response = await client.send(request).timeout(_requestTimeout);
    unawaited(response.stream.listen((_) {}).cancel());
    // 30x means the mount is alive and Triton handed back a current
    // server; anything else (404, connection failure) means the mount
    // itself is gone, not just one pinned server.
    return response.statusCode >= 300 && response.statusCode < 400;
  } catch (_) {
    return false;
  }
}
