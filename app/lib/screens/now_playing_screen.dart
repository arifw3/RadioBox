import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/palette_providers.dart';
import '../state/player_providers.dart';
import '../widgets/circular_visualizer.dart';

final _visualizerStyleProvider = StateProvider<int>((ref) => 0);

/// Full-screen now-playing view — dynamic background tint from the
/// station's logo, plus the circular visualizer (Section 7, CLAUDE.md).
class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaItem = ref.watch(currentMediaItemProvider).valueOrNull;
    final playbackState = ref.watch(playbackStateProvider).valueOrNull;
    final playing = playbackState?.playing ?? false;
    final seedColor =
        ref.watch(dynamicSeedColorProvider).valueOrNull ?? kDefaultSeedColor;
    final style = ref.watch(_visualizerStyleProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [seedColor.withValues(alpha: 0.55), Colors.black],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
                    CircleAvatar(
                      radius: 70,
                      backgroundImage: mediaItem?.artUri != null
                          ? NetworkImage(mediaItem!.artUri.toString())
                          : null,
                      child: mediaItem?.artUri == null
                          ? const Icon(Icons.radio, size: 48)
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  mediaItem?.title ?? 'İstasyon seçilmedi',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              IconButton(
                iconSize: 72,
                icon: Icon(
                  playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                ),
                onPressed: () {
                  final handler = ref.read(audioHandlerProvider);
                  playing ? handler.pause() : handler.play();
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Görselleştiriciye dokun: dalga formunu değiştir',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
