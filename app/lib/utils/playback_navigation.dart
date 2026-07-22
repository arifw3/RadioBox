import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dialwave_core/dialwave_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../screens/now_playing_screen.dart';
import '../state/network_providers.dart';
import '../state/player_providers.dart';

/// Starts playback and immediately opens the Now Playing (visualizer)
/// screen — used everywhere a station is picked from a browsable list
/// (Home, Search) so the user lands on the player, not back on the list
/// they just tapped from. Blocked (with a SnackBar explanation) if
/// "Wi-Fi only" is enabled and the device isn't currently on Wi-Fi.
Future<void> playStationAndShowNowPlaying(
  BuildContext context,
  WidgetRef ref,
  RadioStation station, {
  bool replace = false,
}) async {
  if (ref.read(wifiOnlyProvider)) {
    final results = await Connectivity().checkConnectivity();
    if (!isOnWifi(results)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.wifiOnlyBlocked)),
      );
      return;
    }
  }

  ref.read(audioHandlerProvider).playStation(station);
  if (!context.mounted) return;
  final route = MaterialPageRoute<void>(builder: (_) => const NowPlayingScreen());
  // Search screen replaces itself: back from the player should return to
  // Home, not flash Search again.
  if (replace) {
    Navigator.of(context).pushReplacement(route);
  } else {
    Navigator.of(context).push(route);
  }
}
