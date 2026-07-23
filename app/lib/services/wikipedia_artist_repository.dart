import 'dart:convert';

import 'package:http/http.dart' as http;

const _userAgent = 'DialWave/1.0 (radio app; +https://github.com/arifw3/RadioBox)';

/// Last-resort artist visual when neither iTunes nor Deezer has a confident
/// song match: a real artist photo from Wikipedia, keyed only on the artist
/// name (no song-title claim attached — callers should treat this tier as
/// "a real photo of this artist", not "cover art for this exact track").
class WikipediaArtistRepository {
  WikipediaArtistRepository(this._client);

  final http.Client _client;

  Future<String?> findArtistPhoto(String artistName) async {
    for (final lang in const ['tr', 'en']) {
      final photo = await _searchOneWiki(lang, artistName);
      if (photo != null) return photo;
    }
    return null;
  }

  Future<String?> _searchOneWiki(String lang, String artistName) async {
    try {
      final searchUri = Uri.https('$lang.wikipedia.org', '/w/rest.php/v1/search/page', {
        'q': artistName,
        'limit': '1',
      });
      final searchResponse = await _client.get(
        searchUri,
        headers: {'User-Agent': _userAgent},
      );
      if (searchResponse.statusCode != 200) return null;

      final pages =
          (jsonDecode(searchResponse.body) as Map<String, dynamic>)['pages']
              as List<dynamic>? ??
          const [];
      if (pages.isEmpty) return null;
      final key = (pages.first as Map<String, dynamic>)['key'] as String?;
      if (key == null || key.isEmpty) return null;

      final summaryUri = Uri.https(
        '$lang.wikipedia.org',
        '/api/rest_v1/page/summary/$key',
      );
      final summaryResponse = await _client.get(
        summaryUri,
        headers: {'User-Agent': _userAgent},
      );
      if (summaryResponse.statusCode != 200) return null;

      final summary = jsonDecode(summaryResponse.body) as Map<String, dynamic>;
      final thumbnail = summary['thumbnail'] as Map<String, dynamic>?;
      return thumbnail?['source'] as String?;
    } catch (_) {
      return null;
    }
  }
}
