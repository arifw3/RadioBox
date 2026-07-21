import 'package:meta/meta.dart';

/// A single, verified-reachable radio station.
///
/// Instances are produced by the nightly `radio_sync` script and consumed
/// as-is by the Flutter app — the JSON shape here is a contract shared by
/// both sides of the monorepo, so change it in one place.
@immutable
class RadioStation {
  const RadioStation({
    required this.id,
    required this.name,
    required this.streamUrl,
    required this.countryCode,
    this.favicon = '',
    this.tags = const [],
    this.codec = '',
    this.bitrateKbps = 0,
    this.votes = 0,
    this.clickCount = 0,
  });

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    return RadioStation(
      id: json['id'] as String,
      name: json['name'] as String,
      streamUrl: json['streamUrl'] as String,
      countryCode: json['countryCode'] as String,
      favicon: json['favicon'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      codec: json['codec'] as String? ?? '',
      bitrateKbps: json['bitrateKbps'] as int? ?? 0,
      votes: json['votes'] as int? ?? 0,
      clickCount: json['clickCount'] as int? ?? 0,
    );
  }

  /// Stable radio-browser.info station UUID.
  final String id;
  final String name;

  /// Verified-working stream URL (already passed the nightly ping check).
  final String streamUrl;

  /// ISO 3166-1 alpha-2, e.g. "TR".
  final String countryCode;
  final String favicon;
  final List<String> tags;
  final String codec;
  final int bitrateKbps;
  final int votes;
  final int clickCount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'streamUrl': streamUrl,
        'countryCode': countryCode,
        'favicon': favicon,
        'tags': tags,
        'codec': codec,
        'bitrateKbps': bitrateKbps,
        'votes': votes,
        'clickCount': clickCount,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is RadioStation && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'RadioStation($id, $name, $countryCode)';
}
