import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/country_providers.dart';
import '../state/drive_mode_providers.dart';
import '../state/player_providers.dart';
import '../widgets/banner_ad_widget.dart';

final _volumeProvider = StateProvider<double>((ref) => 1.0);

/// Section 6, CLAUDE.md: past 20 km/h (or manual toggle) the whole
/// screen becomes one big touch surface — no small buttons a driver has
/// to aim for. Swipe right/left to change station, swipe up/down for
/// volume, double-tap to stop, single tap to play/pause.
class DriveModeScreen extends ConsumerWidget {
  const DriveModeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaItem = ref.watch(currentMediaItemProvider).valueOrNull;
    final playbackState = ref.watch(playbackStateProvider).valueOrNull;
    final playing = playbackState?.playing ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      bottomNavigationBar: const BannerAdWidget(),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final handler = ref.read(audioHandlerProvider);
          playing ? handler.pause() : handler.play();
        },
        onDoubleTap: () => ref.read(audioHandlerProvider).pause(),
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity > 200) {
            _skip(ref, forward: false); // swipe right -> came from the left
          } else if (velocity < -200) {
            _skip(ref, forward: true);
          }
        },
        onVerticalDragUpdate: (details) {
          // Dragging up (negative dy) increases volume.
          final change = -details.delta.dy / 300;
          final updated =
              (ref.read(_volumeProvider) + change).clamp(0.0, 1.0);
          ref.read(_volumeProvider.notifier).state = updated;
          ref.read(audioHandlerProvider).setVolume(updated);
        },
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close,
                      color: Colors.white70, size: 32),
                  tooltip: 'Sürüş Modundan çık',
                  onPressed: () => ref
                      .read(driveModeManualOverrideProvider.notifier)
                      .state = false,
                ),
              ),
              const Spacer(),
              Icon(
                playing
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                color: Colors.white,
                size: 180,
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  mediaItem?.title ?? 'İstasyon seçilmedi',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Sağa/sola kaydır: kanal değiştir  •  Yukarı/aşağı: ses  •  Çift dokun: durdur',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
            ],
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
