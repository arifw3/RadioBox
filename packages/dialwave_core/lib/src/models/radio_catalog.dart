import 'package:meta/meta.dart';

import 'radio_station.dart';

/// The top-level shape of `radios.json`.
///
/// [version] lets the app skip re-downloading/re-parsing the full station
/// list when nothing changed since the last successful nightly run.
@immutable
class RadioCatalog {
  const RadioCatalog({
    required this.version,
    required this.generatedAtUtc,
    required this.stations,
  });

  factory RadioCatalog.fromJson(Map<String, dynamic> json) {
    return RadioCatalog(
      version: json['version'] as String,
      generatedAtUtc: DateTime.parse(json['generatedAtUtc'] as String),
      stations: (json['stations'] as List<dynamic>)
          .map((e) => RadioStation.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Content hash of [stations] — changes only when the station list does,
  /// independent of [generatedAtUtc].
  final String version;
  final DateTime generatedAtUtc;
  final List<RadioStation> stations;

  Map<String, dynamic> toJson() => {
        'version': version,
        'generatedAtUtc': generatedAtUtc.toIso8601String(),
        'stations': stations.map((s) => s.toJson()).toList(),
      };
}
