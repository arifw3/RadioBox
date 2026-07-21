import 'package:dialwave_core/dialwave_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/country_providers.dart';
import '../state/player_providers.dart';

/// AppBar action for "Dünya Turu" (Section 7, CLAUDE.md) — lets the user
/// override the onboarding-detected country.
class CountryPickerButton extends ConsumerWidget {
  const CountryPickerButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(radioCatalogProvider).valueOrNull;

    return IconButton(
      icon: const Icon(Icons.public),
      tooltip: 'Dünya Turu',
      onPressed: catalog == null ? null : () => _openSheet(context, ref, catalog.stations),
    );
  }

  Future<void> _openSheet(
    BuildContext context,
    WidgetRef ref,
    List<RadioStation> stations,
  ) async {
    final counts = <String, int>{};
    for (final station in stations) {
      counts.update(station.countryCode, (n) => n + 1, ifAbsent: () => 1);
    }
    final countries = counts.keys.toList()..sort();

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Dünya Turu',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            for (final code in countries)
              ListTile(
                title: Text(code),
                trailing: Text('${counts[code]} istasyon'),
                onTap: () {
                  ref.read(selectedCountryProvider.notifier).select(code);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}
