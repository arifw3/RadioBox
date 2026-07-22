import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../screens/now_playing_screen.dart';
import '../state/player_providers.dart';
import '../theme/app_theme.dart';

/// Floating now-playing pill — sits just above the ad banner (Section 9,
/// CLAUDE.md), styled to match the rounded "premium dark UI kit" look
/// instead of a flat, edge-to-edge Material bar.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final mediaItem = ref.watch(currentMediaItemProvider).valueOrNull;
    final playbackState = ref.watch(playbackStateProvider).valueOrNull;

    if (mediaItem == null) return const SizedBox.shrink();

    final playing = playbackState?.playing ?? false;
    final isBusy = playbackState?.processingState ==
            AudioProcessingState.loading ||
        playbackState?.processingState == AudioProcessingState.buffering;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Material(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        clipBehavior: Clip.antiAlias,
        elevation: 6,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const NowPlayingScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  child: mediaItem.artUri != null
                      ? CachedNetworkImage(
                          imageUrl: mediaItem.artUri.toString(),
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => const _FallbackDisc(),
                        )
                      : const _FallbackDisc(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        mediaItem.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if ((mediaItem.artist ?? '').isNotEmpty)
                        Text(
                          mediaItem.artist!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (isBusy)
                  const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                      tooltip: playing ? l10n.transportPause : l10n.transportPlay,
                      onPressed: () {
                        final handler = ref.read(audioHandlerProvider);
                        playing ? handler.pause() : handler.play();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FallbackDisc extends StatelessWidget {
  const _FallbackDisc();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(color: AppColors.accent),
      child: const Icon(Icons.radio, color: Colors.white, size: 20),
    );
  }
}
