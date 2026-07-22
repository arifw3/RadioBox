import 'package:dialwave_core/dialwave_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/now_playing_screen.dart';
import '../state/player_providers.dart';

/// Starts playback and immediately opens the Now Playing (visualizer)
/// screen — used everywhere a station is picked from a browsable list
/// (Home, Search) so the user lands on the player, not back on the list
/// they just tapped from.
void playStationAndShowNowPlaying(
  BuildContext context,
  WidgetRef ref,
  RadioStation station,
) {
  ref.read(audioHandlerProvider).playStation(station);
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const NowPlayingScreen()),
  );
}
