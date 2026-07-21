import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/player_providers.dart';

/// Bottom now-playing bar — sits above where the ad banner will go
/// (Section 9, CLAUDE.md).
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaItem = ref.watch(currentMediaItemProvider).valueOrNull;
    final playbackState = ref.watch(playbackStateProvider).valueOrNull;

    if (mediaItem == null) return const SizedBox.shrink();

    final playing = playbackState?.playing ?? false;
    final isBusy = playbackState?.processingState ==
            AudioProcessingState.loading ||
        playbackState?.processingState == AudioProcessingState.buffering;

    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: ListTile(
          leading: mediaItem.artUri != null
              ? CircleAvatar(
                  backgroundImage: NetworkImage(mediaItem.artUri.toString()),
                )
              : const CircleAvatar(child: Icon(Icons.radio)),
          title: Text(
            mediaItem.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(mediaItem.artist ?? ''),
          trailing: isBusy
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: Icon(
                    playing
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                  ),
                  iconSize: 36,
                  onPressed: () {
                    final handler = ref.read(audioHandlerProvider);
                    playing ? handler.pause() : handler.play();
                  },
                ),
        ),
      ),
    );
  }
}
