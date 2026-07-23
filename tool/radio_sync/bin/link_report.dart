// One-off diagnostic: checks every station currently in radios.json for a
// dead stream URL or a dead favicon URL, and writes a plain-text report.
// Unlike radio_sync.dart, this does NOT modify radios.json — it's for
// manual review, so broken entries can be fixed/replaced by hand.
//
// Usage: dart run bin/link_report.dart [radios.json path] [report output path]

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dialwave_core/dialwave_core.dart';
import 'package:http/http.dart' as http;
import 'package:pool/pool.dart';

const _userAgent =
    'DialWave-LinkReport/1.0 (+https://github.com/arifw3/RadioBox)';
const _concurrentChecks = 32;
const _requestTimeout = Duration(seconds: 8);

Future<void> main(List<String> args) async {
  final radiosPath = args.isNotEmpty ? args[0] : '../../../radios.json';
  final reportPath = args.length > 1 ? args[1] : '../../../link_report.txt';

  final catalog = RadioCatalog.fromJson(
    jsonDecode(await File(radiosPath).readAsString()) as Map<String, dynamic>,
  );

  stderr.writeln('Checking ${catalog.stations.length} stations...');

  final client = http.Client();
  final pool = Pool(_concurrentChecks);
  final brokenStreams = <_Issue>[];
  final brokenFavicons = <_Issue>[];
  var checked = 0;

  try {
    await Future.wait(
      catalog.stations.map((station) {
        return pool.withResource(() async {
          final streamIssue = await _checkUrl(
            client,
            station.streamUrl,
            isAudio: true,
          );
          if (streamIssue != null) {
            brokenStreams.add(_Issue(station: station, reason: streamIssue));
          }
          if (station.favicon.isNotEmpty) {
            final faviconIssue = await _checkUrl(
              client,
              station.favicon,
              isAudio: false,
            );
            if (faviconIssue != null) {
              brokenFavicons.add(
                _Issue(station: station, reason: faviconIssue),
              );
            }
          }
          checked++;
          if (checked % 100 == 0) {
            stderr.writeln('  $checked/${catalog.stations.length} checked...');
          }
        });
      }),
    );
  } finally {
    await pool.close();
    client.close();
  }

  final buffer = StringBuffer()
    ..writeln('# Kırık Link Raporu')
    ..writeln('Toplam istasyon: ${catalog.stations.length}')
    ..writeln('Tarih: ${DateTime.now().toIso8601String()}')
    ..writeln()
    ..writeln('## Kırık yayın linkleri (${brokenStreams.length})');
  for (final issue in brokenStreams) {
    buffer.writeln(
      '- [${issue.station.id}] ${issue.station.name} '
      '(${issue.station.countryCode}): ${issue.station.streamUrl} — ${issue.reason}',
    );
  }
  buffer
    ..writeln()
    ..writeln('## Kırık görsel (favicon) linkleri (${brokenFavicons.length})');
  for (final issue in brokenFavicons) {
    buffer.writeln(
      '- [${issue.station.id}] ${issue.station.name} '
      '(${issue.station.countryCode}): ${issue.station.favicon} — ${issue.reason}',
    );
  }

  await File(reportPath).writeAsString(buffer.toString());
  stderr.writeln(
    'Done. ${brokenStreams.length} broken streams, '
    '${brokenFavicons.length} broken favicons.',
  );
  stderr.writeln('Report: $reportPath');
}

class _Issue {
  _Issue({required this.station, required this.reason});
  final RadioStation station;
  final String reason;
}

Future<String?> _checkUrl(
  http.Client client,
  String url, {
  required bool isAudio,
}) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
    return 'invalid URL';
  }

  http.StreamedResponse? response;
  try {
    final request = http.Request('GET', uri)..headers['User-Agent'] = _userAgent;
    if (isAudio) request.headers['Icy-MetaData'] = '0';

    response = await client.send(request).timeout(_requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 400) {
      return 'HTTP ${response.statusCode}';
    }
    if (!isAudio) {
      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      if (contentType.isNotEmpty && !contentType.contains('image/')) {
        return 'not an image (content-type: $contentType)';
      }
    }
    return null;
  } on TimeoutException {
    return 'timeout';
  } catch (e) {
    return 'error: ${e.runtimeType}';
  } finally {
    unawaited(response?.stream.listen((_) {}).cancel());
  }
}
