import 'package:dialwave_core/dialwave_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/favorites_providers.dart';
import '../state/player_providers.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/mini_player.dart';
import '../widgets/sleep_timer_button.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(radioCatalogProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('DialWave'),
          actions: const [SleepTimerButton()],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Tümü'),
              Tab(text: 'Favoriler'),
            ],
          ),
        ),
        body: catalog.when(
          data: (data) => TabBarView(
            children: [
              _StationList(stations: data.stations),
              _FavoritesTab(allStations: data.stations),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Radyo listesi yüklenemedi.\n$error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        bottomNavigationBar: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [MiniPlayer(), BannerAdWidget()],
        ),
      ),
    );
  }
}

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab({required this.allStations});

  final List<RadioStation> allStations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteIds = ref.watch(favoritesProvider).valueOrNull;

    if (favoriteIds == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final favorites =
        allStations.where((s) => favoriteIds.contains(s.id)).toList();

    if (favorites.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Henüz favori eklemedin.\nBir istasyonun kalp ikonuna dokun.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return _StationList(stations: favorites);
  }
}

class _StationList extends ConsumerWidget {
  const _StationList({required this.stations});

  final List<RadioStation> stations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (stations.isEmpty) {
      return const Center(child: Text('Şu an listelenecek radyo yok.'));
    }
    final favoriteIds = ref.watch(favoritesProvider).valueOrNull ?? const {};

    return ListView.builder(
      itemCount: stations.length,
      itemBuilder: (context, index) {
        final station = stations[index];
        final isFavorite = favoriteIds.contains(station.id);
        return ListTile(
          leading: station.favicon.isNotEmpty
              ? CircleAvatar(backgroundImage: NetworkImage(station.favicon))
              : const CircleAvatar(child: Icon(Icons.radio)),
          title: Text(station.name),
          subtitle: Text(
            station.tags.isNotEmpty
                ? station.tags.join(', ')
                : station.countryCode,
          ),
          trailing: IconButton(
            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
            color: isFavorite ? Colors.redAccent : null,
            onPressed: () =>
                ref.read(favoritesProvider.notifier).toggle(station.id),
          ),
          onTap: () => ref.read(audioHandlerProvider).playStation(station),
        );
      },
    );
  }
}
