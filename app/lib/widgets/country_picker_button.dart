import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/country_providers.dart';
import '../state/player_providers.dart';

/// "Dünya Turu" sheet (Section 7, CLAUDE.md) — lets the user override the
/// onboarding-detected country. Opened from the AppBar overflow menu.
Future<void> openCountrySheet(BuildContext context, WidgetRef ref) async {
  final catalog = ref.read(radioCatalogProvider).valueOrNull;
  if (catalog == null) return;

  final counts = <String, int>{};
  for (final station in catalog.stations) {
    counts.update(station.countryCode, (n) => n + 1, ifAbsent: () => 1);
  }
  final countries = counts.keys.toList()..sort();

  if (!context.mounted) return;
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
