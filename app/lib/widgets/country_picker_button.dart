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
    // The catalog spans 100+ countries — a plain Column with
    // MainAxisSize.min had no scroll at all, so the sheet just clipped to
    // whatever height fit and the rest (GB, CN, ...) were unreachable.
    // isScrollControlled + DraggableScrollableSheet gives it a real,
    // resizable, scrollable list instead.
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) => SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Dünya Turu',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: countries.length,
                itemBuilder: (context, index) {
                  final code = countries[index];
                  return ListTile(
                    title: Text(code),
                    trailing: Text('${counts[code]} istasyon'),
                    onTap: () {
                      ref.read(selectedCountryProvider.notifier).select(code);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
