import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../services/itunes_search_repository.dart';
import 'player_providers.dart';

final itunesSearchRepositoryProvider = Provider<ItunesSearchRepository>(
  (ref) => ItunesSearchRepository(http.Client()),
);

class ArtistSpotlightData {
  const ArtistSpotlightData({
    required this.artistName,
    required this.songTitle,
    required this.imageUrl,
    required this.otherTracks,
  });

  final String artistName;
  final String songTitle;
  final String? imageUrl;
  final List<ItunesTrack> otherTracks;
}

/// MediaItem.artist starts out as the station's plain country code (see
/// DialWaveAudioHandler._toMediaItem) and only becomes real ICY
/// "StreamTitle" text once a station actually sends it — comparing
/// against the current station's own country code (rather than a generic
/// "is this 2 letters" guess) is the reliable way to tell those apart.
final rawNowPlayingTextProvider = Provider<String?>((ref) {
  final raw = ref.watch(currentMediaItemProvider).valueOrNull?.artist;
  if (raw == null || raw.isEmpty) return null;
  final countryCode = ref.watch(audioHandlerProvider).currentStation?.countryCode;
  if (raw == countryCode) return null;
  return raw;
});

/// Refetches automatically whenever the raw ICY text changes (i.e. a new
/// song starts).
final artistSpotlightProvider = FutureProvider<ArtistSpotlightData?>((
  ref,
) async {
  final raw = ref.watch(rawNowPlayingTextProvider);
  if (raw == null) return null;

  final repo = ref.watch(itunesSearchRepositoryProvider);

  // ICY "StreamTitle" formatting isn't standardized across stations: most
  // use "Artist - Song", but plenty send "ARTIST SONG" with no separator
  // at all. Try the structured split first, and fall back to a free-text
  // search on the whole raw string when there's no dash to split on.
  final dashIndex = raw.indexOf(' - ');
  final expectedSong = dashIndex > 0 ? raw.substring(dashIndex + 3).trim() : null;
  final query = dashIndex > 0 ? raw.substring(0, dashIndex).trim() : raw;

  final tracks = await repo.search(query);
  if (tracks.isEmpty) return null;

  final matched = expectedSong == null
      ? tracks.first
      : tracks.firstWhere(
          (t) => t.trackName.toLowerCase() == expectedSong.toLowerCase(),
          orElse: () => tracks.first,
        );
  final others = tracks
      .where((t) => t.trackName != matched.trackName)
      .take(3)
      .toList();

  return ArtistSpotlightData(
    artistName: matched.artistName,
    songTitle: matched.trackName,
    imageUrl: matched.artworkUrl,
    otherTracks: others,
  );
});
