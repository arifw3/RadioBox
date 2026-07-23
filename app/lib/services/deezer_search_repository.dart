import 'dart:convert';

import 'package:http/http.dart' as http;

class DeezerTrack {
  const DeezerTrack({
    required this.trackName,
    required this.artistName,
    required this.artworkUrl,
  });

  final String trackName;
  final String artistName;
  final String artworkUrl;
}

/// Deezer's free, key-less public search API — second-choice source when
/// iTunes has no confident match for the current ICY "Artist - Song" text.
/// Same shape as ItunesSearchRepository on purpose, so the spotlight
/// provider can run the same exact/fuzzy matching logic against either.
class DeezerSearchRepository {
  DeezerSearchRepository(this._client);

  final http.Client _client;

  Future<List<DeezerTrack>> search(String query, {int limit = 4}) async {
    final uri = Uri.https('api.deezer.com', '/search', {
      'q': query,
      'limit': '$limit',
    });
    final response = await _client.get(uri);
    if (response.statusCode != 200) return const [];

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = body['data'] as List<dynamic>? ?? const [];
    return results
        .map((entry) {
          final map = entry as Map<String, dynamic>;
          final album = map['album'] as Map<String, dynamic>? ?? const {};
          return DeezerTrack(
            trackName: map['title'] as String? ?? '',
            artistName:
                (map['artist'] as Map<String, dynamic>?)?['name'] as String? ??
                '',
            artworkUrl: album['cover_xl'] as String? ?? '',
          );
        })
        .where((track) => track.trackName.isNotEmpty)
        .toList();
  }
}
