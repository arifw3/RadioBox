import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'player_providers.dart';

/// The country (ISO 3166-1 alpha-2) the "Tümü" tab is currently filtered
/// to. Defaults to the device's system locale country if we happen to
/// have stations for it, otherwise the most common code in the catalog.
final selectedCountryProvider =
    NotifierProvider<SelectedCountryNotifier, String?>(
  SelectedCountryNotifier.new,
);

class SelectedCountryNotifier extends Notifier<String?> {
  @override
  String? build() {
    // A Notifier's `state` getter throws until build() has returned once,
    // so the default has to be computed here directly from the current
    // catalog value rather than via a ref.listen callback (which fired
    // before initialization and silently crashed).
    final catalog = ref.watch(radioCatalogProvider).valueOrNull;
    if (catalog == null || catalog.stations.isEmpty) return null;

    final available = catalog.stations.map((s) => s.countryCode).toSet();
    final deviceCountry =
        PlatformDispatcher.instance.locale.countryCode?.toUpperCase();

    return (deviceCountry != null && available.contains(deviceCountry))
        ? deviceCountry
        : catalog.stations.first.countryCode;
  }

  void select(String countryCode) => state = countryCode;
}
