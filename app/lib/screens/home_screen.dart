import 'package:dialwave_core/dialwave_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/country_providers.dart';
import '../state/drive_mode_providers.dart';
import '../state/favorites_providers.dart';
import '../state/player_providers.dart';
import '../utils/time_of_day_suggestion.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/country_picker_button.dart';
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
          actions: [
            IconButton(
              icon: const Icon(Icons.directions_car_filled_outlined),
              tooltip: 'Sürüş Modu',
              onPressed: () => ref
                  .read(driveModeManualOverrideProvider.notifier)
                  .state = true,
            ),
            const CountryPickerButton(),
            const SleepTimerButton(),
          ],
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
              _AllStationsTab(allStations: data.stations),
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

/// The onboarding-detected (or manually picked) country's station list,
/// with an optional time-of-day suggestion strip on top (Section 5 & 7,
/// CLAUDE.md) — all computed on-device, no cloud calls.
class _AllStationsTab extends ConsumerWidget {
  const _AllStationsTab({required this.allStations});

  final List<RadioStation> allStations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCountry = ref.watch(selectedCountryProvider);
    final stations = selectedCountry == null
        ? allStations
        : allStations.where((s) => s.countryCode == selectedCountry).toList();

    final suggestion = suggestionForHour(DateTime.now().hour);
    final suggested = suggestion == null
        ? const <RadioStation>[]
        : stations
            .where(
              (s) => s.tags.any(
                (tag) => suggestion.tagKeywords
                    .any((keyword) => tag.toLowerCase().contains(keyword)),
              ),
            )
            .take(6)
            .toList();

    return Column(
      children: [
        if (suggested.isNotEmpty)
          _SuggestionStrip(label: suggestion!.label, stations: suggested),
        Expanded(child: _StationList(stations: stations)),
      ],
    );
  }
}

class _SuggestionStrip extends ConsumerWidget {
  const _SuggestionStrip({required this.label, required this.stations});

  final String label;
  final List<RadioStation> stations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Şimdi: $label',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        SizedBox(
          height: 88,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: stations.length,
            itemBuilder: (context, index) {
              final station = stations[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: () =>
                          ref.read(audioHandlerProvider).playStation(station),
                      child: station.favicon.isNotEmpty
                          ? CircleAvatar(
                              radius: 28,
                              backgroundImage: NetworkImage(station.favicon),
                            )
                          : const CircleAvatar(
                              radius: 28,
                              child: Icon(Icons.radio),
                            ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        station.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
      ],
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
