import 'dart:convert';

import 'package:http/http.dart' as http;

class ItunesTrack {
  const ItunesTrack({
    required this.trackName,
    required this.artistName,
    required this.artworkUrl,
  });

  final String trackName;
  final String artistName;
  final String artworkUrl;
}

/// Apple's free, key-less iTunes Search API — not the paid Apple Music/
/// MusicKit API, which needs a developer account and JWT signing. There is
/// no dedicated "artist photo" endpoint here, only track/album artwork, so
/// callers use a matched track's cover art as the artist visual.
class ItunesSearchRepository {
  ItunesSearchRepository(this._client);

  final http.Client _client;

  Future<List<ItunesTrack>> search(String query, {int limit = 4}) async {
    final uri = Uri.https('itunes.apple.com', '/search', {
      'term': query,
      'entity': 'song',
      'limit': '$limit',
    });
    final response = await _client.get(uri);
    if (response.statusCode != 200) return const [];

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = body['results'] as List<dynamic>? ?? const [];
    return results
        .map((entry) {
          final map = entry as Map<String, dynamic>;
          return ItunesTrack(
            trackName: map['trackName'] as String? ?? '',
            artistName: map['artistName'] as String? ?? '',
            artworkUrl: _upscale(map['artworkUrl100'] as String? ?? ''),
          );
        })
        .where((track) => track.trackName.isNotEmpty)
        .toList();
  }

  /// iTunes artwork URLs embed the requested pixel size in the path
  /// (".../100x100bb.jpg") — swapping it in gets a much sharper image for
  /// the same request.
  String _upscale(String artworkUrl100) {
    if (artworkUrl100.isEmpty) return artworkUrl100;
    return artworkUrl100.replaceFirst('100x100bb', '600x600bb');
  }
}
