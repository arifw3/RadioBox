import 'package:dialwave_core/dialwave_core.dart';
import 'package:test/test.dart';

void main() {
  group('RadioStation.fromJson', () {
    test('reads every field from a full JSON map', () {
      final station = RadioStation.fromJson({
        'id': 'abc-123',
        'name': 'Metro FM',
        'streamUrl': 'https://metrofm.com.tr/stream',
        'countryCode': 'TR',
        'favicon': 'https://metrofm.com.tr/favicon.ico',
        'tags': ['pop', 'turkish'],
        'codec': 'MP3',
        'bitrateKbps': 128,
        'votes': 42,
        'clickCount': 7,
      });

      expect(station.id, 'abc-123');
      expect(station.name, 'Metro FM');
      expect(station.streamUrl, 'https://metrofm.com.tr/stream');
      expect(station.countryCode, 'TR');
      expect(station.favicon, 'https://metrofm.com.tr/favicon.ico');
      expect(station.tags, ['pop', 'turkish']);
      expect(station.codec, 'MP3');
      expect(station.bitrateKbps, 128);
      expect(station.votes, 42);
      expect(station.clickCount, 7);
    });

    test('defaults optional fields when absent from JSON', () {
      final station = RadioStation.fromJson({
        'id': 'abc-123',
        'name': 'Metro FM',
        'streamUrl': 'https://metrofm.com.tr/stream',
        'countryCode': 'TR',
      });

      expect(station.favicon, '');
      expect(station.tags, isEmpty);
      expect(station.codec, '');
      expect(station.bitrateKbps, 0);
      expect(station.votes, 0);
      expect(station.clickCount, 0);
    });

    test('round-trips through toJson/fromJson unchanged', () {
      const original = RadioStation(
        id: 'abc-123',
        name: 'Metro FM',
        streamUrl: 'https://metrofm.com.tr/stream',
        countryCode: 'TR',
        favicon: 'https://metrofm.com.tr/favicon.ico',
        tags: ['pop'],
        codec: 'MP3',
        bitrateKbps: 128,
        votes: 42,
        clickCount: 7,
      );

      final roundTripped = RadioStation.fromJson(original.toJson());

      expect(roundTripped.id, original.id);
      expect(roundTripped.name, original.name);
      expect(roundTripped.streamUrl, original.streamUrl);
      expect(roundTripped.countryCode, original.countryCode);
      expect(roundTripped.favicon, original.favicon);
      expect(roundTripped.tags, original.tags);
      expect(roundTripped.codec, original.codec);
      expect(roundTripped.bitrateKbps, original.bitrateKbps);
      expect(roundTripped.votes, original.votes);
      expect(roundTripped.clickCount, original.clickCount);
    });
  });

  group('RadioStation equality', () {
    test('two stations with the same id are equal regardless of other fields', () {
      const a = RadioStation(
        id: 'same-id',
        name: 'A',
        streamUrl: 'https://a.example/stream',
        countryCode: 'TR',
      );
      const b = RadioStation(
        id: 'same-id',
        name: 'B',
        streamUrl: 'https://b.example/stream',
        countryCode: 'US',
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('stations with different ids are not equal', () {
      const a = RadioStation(
        id: 'id-1',
        name: 'Same Name',
        streamUrl: 'https://a.example/stream',
        countryCode: 'TR',
      );
      const b = RadioStation(
        id: 'id-2',
        name: 'Same Name',
        streamUrl: 'https://a.example/stream',
        countryCode: 'TR',
      );

      expect(a, isNot(equals(b)));
    });
  });
}
