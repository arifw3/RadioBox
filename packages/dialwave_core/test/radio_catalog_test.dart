import 'package:dialwave_core/dialwave_core.dart';
import 'package:test/test.dart';

void main() {
  group('RadioCatalog.fromJson / toJson', () {
    test('round-trips version, generatedAtUtc, and every station', () {
      final original = RadioCatalog(
        version: 'abc123hash',
        generatedAtUtc: DateTime.utc(2026, 7, 23, 10, 30),
        stations: const [
          RadioStation(
            id: 's1',
            name: 'Station One',
            streamUrl: 'https://one.example/stream',
            countryCode: 'TR',
          ),
          RadioStation(
            id: 's2',
            name: 'Station Two',
            streamUrl: 'https://two.example/stream',
            countryCode: 'US',
          ),
        ],
      );

      final roundTripped = RadioCatalog.fromJson(original.toJson());

      expect(roundTripped.version, original.version);
      expect(roundTripped.generatedAtUtc, original.generatedAtUtc);
      expect(roundTripped.stations.length, 2);
      expect(roundTripped.stations[0].id, 's1');
      expect(roundTripped.stations[1].id, 's2');
    });

    test('handles an empty station list', () {
      final catalog = RadioCatalog(
        version: 'empty',
        generatedAtUtc: DateTime.utc(2026, 1, 1),
        stations: const [],
      );

      final roundTripped = RadioCatalog.fromJson(catalog.toJson());

      expect(roundTripped.stations, isEmpty);
    });
  });
}
