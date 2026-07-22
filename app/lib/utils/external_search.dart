import 'package:url_launcher/url_launcher.dart';

/// Opens Spotify's plain web search — no API key/OAuth needed, opens the
/// Spotify app itself if installed via the universal link.
Future<void> openSpotifySearch(String query) async {
  final uri = Uri.https('open.spotify.com', '/search/${Uri.encodeComponent(query)}');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> openYoutubeSearch(String query) async {
  final uri = Uri.https('www.youtube.com', '/results', {'search_query': query});
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
