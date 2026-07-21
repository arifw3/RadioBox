import 'package:dialwave_core/dialwave_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/player_providers.dart';
import '../widgets/mini_player.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(radioCatalogProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('DialWave')),
      body: catalog.when(
        data: (data) => _StationList(stations: data.stations),
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
      bottomNavigationBar: const MiniPlayer(),
    );
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
    return ListView.builder(
      itemCount: stations.length,
      itemBuilder: (context, index) {
        final station = stations[index];
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
          onTap: () => ref.read(audioHandlerProvider).playStation(station),
        );
      },
    );
  }
}
