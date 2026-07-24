import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dialwave_core/dialwave_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../services/deezer_search_repository.dart';
import '../services/icy_metadata_probe.dart';
import '../services/itunes_search_repository.dart';
import '../services/wikipedia_artist_repository.dart';
import 'network_providers.dart';
import 'player_providers.dart';

final itunesSearchRepositoryProvider = Provider<ItunesSearchRepository>(
  (ref) => ItunesSearchRepository(http.Client()),
);

final deezerSearchRepositoryProvider = Provider<DeezerSearchRepository>(
  (ref) => DeezerSearchRepository(http.Client()),
);

final wikipediaArtistRepositoryProvider = Provider<WikipediaArtistRepository>(
  (ref) => WikipediaArtistRepository(http.Client()),
);

final icyMetadataProbeProvider = Provider<IcyMetadataProbe>(
  (ref) => IcyMetadataProbe(http.Client()),
);

/// Common shape both ItunesTrack and DeezerTrack are reduced to once
/// matched, so the rest of the provider (and the UI) doesn't care which
/// source a result came from.
class SpotlightTrack {
  const SpotlightTrack({
    required this.trackName,
    required this.artistName,
    required this.artworkUrl,
  });

  final String trackName;
  final String artistName;
  final String artworkUrl;
}

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
  final List<SpotlightTrack> otherTracks;
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
  return resolveSpotlight(ref, raw);
});

/// Same live/no-song-guessing spotlight chain as [artistSpotlightProvider],
/// but for a station the user isn't actually playing — reads one ICY
/// metadata block via a short-lived probe connection (see
/// icy_metadata_probe.dart) instead of the real playback stream. Used by
/// the home screen hero so "your most-played station" can show what's
/// live on it without requiring playback first.
///
/// Respects the existing "Wi-Fi only" setting exactly like starting
/// playback does (playback_navigation.dart) — this is a real, if small,
/// network fetch the user didn't explicitly ask for by pressing play.
final heroSpotlightProvider = FutureProvider.family<ArtistSpotlightData?, RadioStation>(
  (ref, station) async {
    if (ref.watch(wifiOnlyProvider)) {
      final results = await Connectivity().checkConnectivity();
      if (!isOnWifi(results)) return null;
    }

    final probe = ref.watch(icyMetadataProbeProvider);
    final raw = await probe.fetchStreamTitle(station.streamUrl);
    if (raw == null || raw.isEmpty || raw == station.countryCode) return null;

    return resolveSpotlight(ref, raw);
  },
);

/// Three tiers, each stricter than cheap but weaker than confident:
/// 1. iTunes exact/fuzzy song match (cover art + song title).
/// 2. Deezer exact/fuzzy song match, same rule, when iTunes has nothing.
/// 3. Wikipedia artist photo — only reachable when neither source could
///    confirm the actual song, so it never claims a song match; it's just
///    a real photo of the artist ICY told us is playing.
Future<ArtistSpotlightData?> resolveSpotlight(Ref ref, String raw) async {
  // ICY "StreamTitle" formatting isn't standardized across stations: most
  // use "Artist - Song", but plenty send "ARTIST SONG" with no separator
  // at all. Try the structured split first, and fall back to a free-text
  // search on the whole raw string when there's no dash to split on.
  final dashIndex = raw.indexOf(' - ');
  final expectedSong = dashIndex > 0 ? raw.substring(dashIndex + 3).trim() : null;
  final query = dashIndex > 0 ? raw.substring(0, dashIndex).trim() : raw;

  final itunes = ref.watch(itunesSearchRepositoryProvider);
  final itunesTracks = await itunes.search(query);
  final itunesMatch = findConfidentMatch(
    itunesTracks,
    (t) => t.trackName,
    (t) => t.artistName,
    query,
    expectedSong,
  );
  if (itunesMatch != null) {
    final others = itunesTracks
        .where((t) => t.trackName != itunesMatch.trackName)
        .take(3)
        .map(
          (t) => SpotlightTrack(
            trackName: t.trackName,
            artistName: t.artistName,
            artworkUrl: t.artworkUrl,
          ),
        )
        .toList();
    return ArtistSpotlightData(
      artistName: itunesMatch.artistName,
      songTitle: itunesMatch.trackName,
      imageUrl: itunesMatch.artworkUrl,
      otherTracks: others,
    );
  }

  final deezer = ref.watch(deezerSearchRepositoryProvider);
  final deezerTracks = await deezer.search(query);
  final deezerMatch = findConfidentMatch(
    deezerTracks,
    (t) => t.trackName,
    (t) => t.artistName,
    query,
    expectedSong,
  );
  if (deezerMatch != null) {
    final others = deezerTracks
        .where((t) => t.trackName != deezerMatch.trackName)
        .take(3)
        .map(
          (t) => SpotlightTrack(
            trackName: t.trackName,
            artistName: t.artistName,
            artworkUrl: t.artworkUrl,
          ),
        )
        .toList();
    return ArtistSpotlightData(
      artistName: deezerMatch.artistName,
      songTitle: deezerMatch.trackName,
      imageUrl: deezerMatch.artworkUrl,
      otherTracks: others,
    );
  }

  // Neither music source could confirm the actual song. Wikipedia can't
  // confirm a song either, but matching just the artist name is a much
  // lower bar — a real artist photo alongside the raw (unverified) ICY
  // song text beats showing nothing.
  final wikipedia = ref.watch(wikipediaArtistRepositoryProvider);
  final artistPhoto = await wikipedia.findArtistPhoto(query);
  if (artistPhoto == null) return null;

  return ArtistSpotlightData(
    artistName: query,
    songTitle: expectedSong ?? '',
    imageUrl: artistPhoto,
    otherTracks: const [],
  );
}

/// Exact match first; a loose substring match second (catches "(Remastered)"/
/// "[Live]" suffixes a source appends but ICY metadata usually omits).
/// Returns null rather than guessing with the first result — a confidently
/// wrong song + cover art (a different track by the same artist, or worse,
/// a same-titled track by a completely different artist) is worse than
/// showing nothing.
///
/// Requires the artist name to match too — a search result can rank #1 by
/// text relevance while being some other artist's cover/same-titled track,
/// and matching only on song title would confidently show that artist's
/// (unrelated) cover art instead.
T? findConfidentMatch<T>(
  List<T> tracks,
  String Function(T) trackNameOf,
  String Function(T) artistNameOf,
  String expectedArtist,
  String? expectedSong,
) {
  if (tracks.isEmpty) return null;

  final normalizedExpectedArtist = normalizeTitle(expectedArtist);
  bool artistMatches(T t) {
    final normalizedArtist = normalizeTitle(artistNameOf(t));
    return normalizedArtist == normalizedExpectedArtist ||
        normalizedArtist.contains(normalizedExpectedArtist) ||
        normalizedExpectedArtist.contains(normalizedArtist);
  }

  final byArtist = tracks.where(artistMatches).toList();
  if (byArtist.isEmpty) return null;

  if (expectedSong == null) {
    // No dash to split on, so there was never a specific song title to
    // verify against — the best artist-matched result is the best we can
    // do, low-confidence or not.
    return byArtist.first;
  }

  final normalizedExpected = normalizeTitle(expectedSong);
  for (final t in byArtist) {
    if (normalizeTitle(trackNameOf(t)) == normalizedExpected) return t;
  }
  for (final t in byArtist) {
    final normalizedTrack = normalizeTitle(trackNameOf(t));
    if (normalizedTrack.contains(normalizedExpected) ||
        normalizedExpected.contains(normalizedTrack)) {
      return t;
    }
  }
  return null;
}

/// Case-insensitive, ignores parenthetical/bracketed qualifiers like
/// "(Remastered)" or "[Live]" that iTunes often appends but ICY metadata
/// usually omits.
String normalizeTitle(String input) {
  return input
      .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')
      .toLowerCase()
      .trim();
}
