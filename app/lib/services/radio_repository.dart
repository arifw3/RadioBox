import 'dart:convert';
import 'dart:io' show HttpException;

import 'package:dialwave_core/dialwave_core.dart';
import 'package:http/http.dart' as http;

/// Points at the nightly-generated radios.json, served through jsDelivr's
/// free GitHub CDN mirror — no GitHub Pages, no server, no bandwidth caps.
const kRadiosJsonUrl =
    'https://cdn.jsdelivr.net/gh/arifw3/dialwave@main/radios.json';

class RadioRepository {
  RadioRepository(this._client);

  final http.Client _client;

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
}
