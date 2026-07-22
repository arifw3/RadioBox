import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../services/itunes_search_repository.dart';
import '../state/artist_spotlight_providers.dart';
import '../state/country_providers.dart';
import '../state/palette_providers.dart';
import '../state/player_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/circular_visualizer.dart';
import '../widgets/social_sync_panel.dart';

final _visualizerStyleProvider = StateProvider<int>((ref) => 0);

/// Now-playing view — full-bleed artist/album art (from ICY metadata +
/// iTunes Search API) when a match is found, falling back to the
/// dynamic-tint circular visualizer (Section 7, CLAUDE.md) otherwise.
class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final mediaItem = ref.watch(currentMediaItemProvider).valueOrNull;
    final playbackState = ref.watch(playbackStateProvider).valueOrNull;
    final playing = playbackState?.playing ?? false;
    final seedColor =
        ref.watch(dynamicSeedColorProvider).valueOrNull ?? kDefaultSeedColor;
    final style = ref.watch(_visualizerStyleProvider);

    final spotlightAsync = ref.watch(artistSpotlightProvider);
    final spotlight = spotlightAsync.valueOrNull;
    // Riverpod keeps a FutureProvider's *previous* value visible by default
    // while it's re-fetching after a dependency change (so quick refreshes
    // don't flash a loading spinner) — here that dependency is the current
    // song, so without this check a new song's title would briefly pair
    // with the previous song's cover art until the new iTunes lookup
    // finishes. Gating on isLoading falls back to the plain visualizer for
    // that window instead of showing a mismatched image.
    final spotlightReady =
        !spotlightAsync.isLoading &&
        spotlight != null &&
        (spotlight.imageUrl?.isNotEmpty ?? false);

    final transportRow = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _TransportButton(
          icon: Icons.skip_previous_rounded,
          size: 56,
          iconSize: 28,
          tooltip: l10n.transportPrevious,
          onPressed: () => _skip(ref, forward: false),
        ),
        const SizedBox(width: 20),
        _TransportButton(
          icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 84,
          iconSize: 44,
          filled: true,
          tooltip: playing ? l10n.transportPause : l10n.transportPlay,
          onPressed: () {
            final handler = ref.read(audioHandlerProvider);
            playing ? handler.pause() : handler.play();
          },
        ),
        const SizedBox(width: 20),
        _TransportButton(
          icon: Icons.skip_next_rounded,
          size: 56,
          iconSize: 28,
          tooltip: l10n.transportNext,
          onPressed: () => _skip(ref, forward: true),
        ),
      ],
    );

    if (spotlightReady) {
      return _SpotlightScaffold(
        imageUrl: spotlight.imageUrl!,
        stationName: mediaItem?.title ?? l10n.stationNotSelected,
        artistName: spotlight.artistName,
        songTitle: spotlight.songTitle,
        otherTracks: spotlight.otherTracks,
        transportRow: transportRow,
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      bottomNavigationBar: const BannerAdWidget(),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [seedColor.withValues(alpha: 0.55), AppColors.background],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 24),
                Semantics(
                  button: true,
                  label: l10n.visualizerHint,
                  child: GestureDetector(
                    onTap: () => ref
                            .read(_visualizerStyleProvider.notifier)
                            .state =
                        (style + 1) % CircularVisualizer.styleCount,
                    child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularVisualizer(
                        color: seedColor,
                        isPlaying: playing,
                        style: style,
                      ),
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 3),
                        ),
                        child: ClipOval(
                          child: mediaItem?.artUri != null
                              ? CachedNetworkImage(
                                  imageUrl: mediaItem!.artUri.toString(),
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) =>
                                      const _FallbackArt(),
                                )
                              : const _FallbackArt(),
                        ),
                      ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    mediaItem?.title ?? l10n.stationNotSelected,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                if ((mediaItem?.artist ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    mediaItem!.artist!,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white60),
                  ),
                ],
                const SizedBox(height: 32),
                transportRow,
                const SizedBox(height: 12),
                Text(
                  l10n.visualizerHint,
                  style: const TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 28),
                const SocialSyncPanel(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _skip(WidgetRef ref, {required bool forward}) {
    final catalog = ref.read(radioCatalogProvider).valueOrNull;
    if (catalog == null || catalog.stations.isEmpty) return;

    final country = ref.read(selectedCountryProvider);
    final stations = country == null
        ? catalog.stations
        : catalog.stations.where((s) => s.countryCode == country).toList();
    if (stations.isEmpty) return;

    final currentId = ref.read(audioHandlerProvider).currentStation?.id;
    final currentIndex = stations.indexWhere((s) => s.id == currentId);
    final rawIndex =
        currentIndex == -1 ? 0 : currentIndex + (forward ? 1 : -1);
    final safeIndex = rawIndex % stations.length;
    final normalizedIndex = safeIndex < 0 ? safeIndex + stations.length : safeIndex;

    ref.read(audioHandlerProvider).playStation(stations[normalizedIndex]);
  }
}

/// Full-screen artist/album-art variant — image fills the entire body,
/// station/artist/song text and controls sit on top of it in a scrollable
/// overlay so nothing overflows on shorter screens.
class _SpotlightScaffold extends StatelessWidget {
  const _SpotlightScaffold({
    required this.imageUrl,
    required this.stationName,
    required this.artistName,
    required this.songTitle,
    required this.otherTracks,
    required this.transportRow,
  });

  final String imageUrl;
  final String stationName;
  final String artistName;
  final String songTitle;
  final List<ItunesTrack> otherTracks;
  final Widget transportRow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          stationName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: Colors.white),
        ),
        centerTitle: true,
      ),
      bottomNavigationBar: const BannerAdWidget(),
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // A fixed-height photo block, not a full-bleed backdrop with text
          // washed over it — the image stays clean and the station/artist/
          // song text gets its own card below, on the normal background.
          SizedBox(
            height: screenHeight * 0.5,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
                // Dark enough at the very top for the back button/title to
                // stay legible, clear through the middle so the photo
                // actually shows, then fades to the exact background color
                // at the bottom so it blends into the content below instead
                // of cutting off sharply.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black45,
                        Colors.transparent,
                        Colors.transparent,
                        AppColors.background,
                      ],
                      stops: const [0.0, 0.18, 0.7, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Text(
                          artistName,
                          style: Theme.of(context).textTheme.headlineSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.nowPlayingSong(songTitle),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white70),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  transportRow,
                  if (otherTracks.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.otherSongsHeading,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(color: Colors.white70),
                          ),
                          const SizedBox(height: 12),
                          for (final track in otherTracks)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceRaised,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(
                                          10,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.music_note_rounded,
                                        color: Colors.white70,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        track.trackName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const SocialSyncPanel(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransportButton extends StatelessWidget {
  const _TransportButton({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.onPressed,
    required this.tooltip,
    this.filled = false,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final VoidCallback onPressed;
  final String tooltip;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? AppColors.accent : AppColors.surfaceRaised,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: iconSize),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

class _FallbackArt extends StatelessWidget {
  const _FallbackArt();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: AppColors.accent),
      child: const Icon(Icons.radio, color: Colors.white, size: 56),
    );
  }
}
