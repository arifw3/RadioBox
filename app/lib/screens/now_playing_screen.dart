import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../state/country_providers.dart';
import '../state/palette_providers.dart';
import '../state/player_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/circular_visualizer.dart';
import '../widgets/social_sync_panel.dart';

final _visualizerStyleProvider = StateProvider<int>((ref) => 0);

/// Full-screen now-playing view — dynamic background tint from the
/// station's logo, plus the circular visualizer (Section 7, CLAUDE.md).
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
                GestureDetector(
                  onTap: () => ref.read(_visualizerStyleProvider.notifier).state =
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TransportButton(
                      icon: Icons.skip_previous_rounded,
                      size: 56,
                      iconSize: 28,
                      onPressed: () => _skip(ref, forward: false),
                    ),
                    const SizedBox(width: 20),
                    _TransportButton(
                      icon: playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 84,
                      iconSize: 44,
                      filled: true,
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
                      onPressed: () => _skip(ref, forward: true),
                    ),
                  ],
                ),
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

class _TransportButton extends StatelessWidget {
  const _TransportButton({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final VoidCallback onPressed;
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
