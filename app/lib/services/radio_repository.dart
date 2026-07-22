import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, HttpException;

import 'package:dialwave_core/dialwave_core.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Points at the nightly-generated radios.json, served through jsDelivr's
/// free GitHub CDN mirror — no GitHub Pages, no server, no bandwidth caps.
const kRadiosJsonUrl =
    'https://cdn.jsdelivr.net/gh/arifw3/RadioBox@main/radios.json';

class RadioRepository {
  RadioRepository(this._client);

  final http.Client _client;

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/radios_cache.json');
  }

  /// The last successfully fetched catalog, read straight from disk — no
  /// network involved. Used to paint the station list instantly on cold
  /// start instead of showing a spinner while radios.json downloads.
  Future<RadioCatalog?> loadCached() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      return RadioCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupted or unreadable cache file — treat it as a cold start
      // rather than crashing the catalog load over stale local state.
      return null;
    }
  }

  Future<RadioCatalog> fetchCatalog() async {
    final response = await _client.get(Uri.parse(kRadiosJsonUrl));
    if (response.statusCode != 200) {
      throw HttpException(
        'radios.json indirilemedi (HTTP ${response.statusCode})',
      );
    }
    return RadioCatalog.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Fetches the live catalog and persists it for the next cold start.
  Future<RadioCatalog> fetchAndCache() async {
    final catalog = await fetchCatalog();
    unawaited(_writeCache(catalog));
    return catalog;
  }

  Future<void> _writeCache(RadioCatalog catalog) async {
    try {
      final file = await _cacheFile();
      await file.writeAsString(jsonEncode(catalog.toJson()));
    } catch (_) {
      // Best-effort — a failed write just means the next cold start
      // falls back to a network fetch, same as today.
    }
  }
}
