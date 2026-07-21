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
    // Once the catalog resolves, snap the default to the device's own
    // country if it's actually in the data set — this is what makes
    // onboarding feel automatic instead of dumping a raw country list.
    ref.listen(radioCatalogProvider, (previous, next) {
      if (state != null) return; // user (or a previous listen) already set one
      final catalog = next.valueOrNull;
      if (catalog == null || catalog.stations.isEmpty) return;

      final available = catalog.stations.map((s) => s.countryCode).toSet();
      final deviceCountry =
          PlatformDispatcher.instance.locale.countryCode?.toUpperCase();

      state = (deviceCountry != null && available.contains(deviceCountry))
          ? deviceCountry
          : catalog.stations.first.countryCode;
    });
    return null;
  }

  void select(String countryCode) => state = countryCode;
}
