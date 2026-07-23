import 'package:dialwave_core/dialwave_core.dart';
import 'package:radio_sync/radio_sync_logic.dart';
import 'package:test/test.dart';

RadioStation _station({
  required String id,
  required String name,
  String countryCode = 'TR',
  int clickCount = 0,
  int votes = 0,
}) {
  return RadioStation(
    id: id,
    name: name,
    streamUrl: 'https://$id.example/stream',
    countryCode: countryCode,
    clickCount: clickCount,
    votes: votes,
  );
}

void main() {
  group('cleanFavicon', () {
    test('passes through a normal URL unchanged', () {
      expect(
        cleanFavicon('https://example.com/favicon.ico'),
        'https://example.com/favicon.ico',
      );
    });

    test('treats the literal string "null" as empty', () {
      expect(cleanFavicon('null'), '');
      expect(cleanFavicon('NULL'), '');
      expect(cleanFavicon('  null  '), '');
    });

    test('treats an actually-null value as empty', () {
      expect(cleanFavicon(null), '');
    });

    test('trims surrounding whitespace on a real URL', () {
      expect(cleanFavicon('  https://example.com/x.png  '), 'https://example.com/x.png');
    });
  });

  group('looksLikeAudio', () {
    test('accepts a missing content-type (many Icecast mounts omit it)', () {
      expect(looksLikeAudio(''), isTrue);
    });

    test('accepts standard audio content types', () {
      expect(looksLikeAudio('audio/mpeg'), isTrue);
      expect(looksLikeAudio('audio/aac'), isTrue);
    });

    test('accepts HLS playlist content types', () {
      expect(looksLikeAudio('application/vnd.apple.mpegurl'), isTrue);
      expect(looksLikeAudio('application/x-mpegurl'), isTrue);
    });

    test('rejects an HTML error page', () {
      expect(looksLikeAudio('text/html'), isFalse);
    });
  });

  group('deduplicate', () {
    test('keeps the higher-clickcount entry among same-name duplicates', () {
      final stations = [
        _station(id: 'a', name: 'Metro FM', clickCount: 10),
        _station(id: 'b', name: 'Metro FM', clickCount: 50),
      ];

      final result = deduplicate(stations);

      expect(result, hasLength(1));
      expect(result.single.id, 'b');
    });

    test('falls back to votes when clickcount ties', () {
      final stations = [
        _station(id: 'a', name: 'Metro FM', clickCount: 5, votes: 3),
        _station(id: 'b', name: 'Metro FM', clickCount: 5, votes: 20),
      ];

      final result = deduplicate(stations);

      expect(result.single.id, 'b');
    });

    test('name matching ignores case and surrounding whitespace', () {
      final stations = [
        _station(id: 'a', name: 'Metro FM', clickCount: 1),
        _station(id: 'b', name: '  metro fm  ', clickCount: 99),
      ];

      final result = deduplicate(stations);

      expect(result, hasLength(1));
    });

    test('keeps same-named stations from different countries separate', () {
      final stations = [
        _station(id: 'a', name: 'Metro FM', countryCode: 'TR'),
        _station(id: 'b', name: 'Metro FM', countryCode: 'US'),
      ];

      final result = deduplicate(stations);

      expect(result, hasLength(2));
    });

    test('keeps distinctly-named stations untouched', () {
      final stations = [
        _station(id: 'a', name: 'Metro FM'),
        _station(id: 'b', name: 'Power FM'),
      ];

      expect(deduplicate(stations), hasLength(2));
    });
  });

  group('hashStations', () {
    test('is stable regardless of input order', () {
      final a = [_station(id: '1', name: 'A'), _station(id: '2', name: 'B')];
      final b = [_station(id: '2', name: 'B'), _station(id: '1', name: 'A')];

      expect(hashStations(a), hashStations(b));
    });

    test('changes when a stream URL changes', () {
      final original = [_station(id: '1', name: 'A')];
      final changed = [
        RadioStation(
          id: '1',
          name: 'A',
          streamUrl: 'https://different.example/stream',
          countryCode: 'TR',
        ),
      ];

      expect(hashStations(original), isNot(hashStations(changed)));
    });
  });
}
