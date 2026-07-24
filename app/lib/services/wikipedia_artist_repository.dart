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
      // A plain top-1 search for e.g. "Ceylan" (a raw ICY artist name) can
      // land on the Turkish word for "gazelle" — Wikipedia ranks that exact-
      // title match above the "Ceylan (şarkıcı)" singer's page. Asking for a
      // few candidates and checking each one's short description against a
      // person/musician allowlist (rather than trusting the top hit blindly)
      // is what actually avoids handing back an animal's photo.
      final searchUri = Uri.https('$lang.wikipedia.org', '/w/rest.php/v1/search/page', {
        'q': artistName,
        'limit': '5',
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

      String? key;
      for (final page in pages) {
        final map = page as Map<String, dynamic>;
        final description = map['description'] as String?;
        if (description != null && looksLikeMusicianOrPerson(description)) {
          key = map['key'] as String?;
          break;
        }
      }
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

/// Turkish + English words that show up in Wikidata-sourced short
/// descriptions for musicians/singers/bands. Deliberately an allowlist, not
/// a denylist of "known wrong categories" — the space of things a name can
/// collide with (animals, films, cities, plants, ...) is unbounded, but the
/// vocabulary Wikipedia actually uses for "this is a musician" isn't. A
/// description that matches none of these returns no photo rather than a
/// guess — same "no photo beats a wrong photo" rule as the iTunes/Deezer tier.
const _musicianDescriptionKeywords = [
  // Turkish
  'şarkıcı', 'müzisyen', 'sanatçı', 'grup', 'topluluk', 'besteci',
  'söz yazarı', 'rapçi', 'rap sanatçısı', 'orkestra', 'müzik grubu',
  // English
  'singer', 'musician', 'artist', 'band', 'rapper', 'songwriter',
  'composer', 'vocalist', 'producer', 'orchestra', 'dj ',
];

bool looksLikeMusicianOrPerson(String description) {
  final lower = description.toLowerCase();
  return _musicianDescriptionKeywords.any(lower.contains);
}
