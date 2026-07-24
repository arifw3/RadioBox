import 'package:dialwave/state/artist_spotlight_providers.dart';
import 'package:flutter_test/flutter_test.dart';

class _Track {
  const _Track(this.artist, this.name);
  final String artist;
  final String name;
}

void main() {
  group('findConfidentMatch', () {
    test('returns null for an empty track list', () {
      final result = findConfidentMatch<_Track>(
        const [],
        (t) => t.name,
        (t) => t.artist,
        'Barış Manço',
        'Kuzu Kuzu',
      );
      expect(result, isNull);
    });

    test('returns null when no result is by the expected artist', () {
      const tracks = [_Track('Some Other Artist', 'Kuzu Kuzu')];
      final result = findConfidentMatch<_Track>(
        tracks,
        (t) => t.name,
        (t) => t.artist,
        'Barış Manço',
        'Kuzu Kuzu',
      );
      expect(result, isNull);
    });

    test('returns the first same-artist result when there is no expected song to verify', () {
      const tracks = [
        _Track('Barış Manço', 'Kuzu Kuzu'),
        _Track('Barış Manço', 'Şıkıdım'),
      ];
      final result = findConfidentMatch<_Track>(
        tracks,
        (t) => t.name,
        (t) => t.artist,
        'Barış Manço',
        null,
      );
      expect(result, same(tracks.first));
    });

    test('prefers an exact (case-insensitive) title match', () {
      const tracks = [
        _Track('Barış Manço', 'Şıkıdım'),
        _Track('Barış Manço', 'kuzu kuzu'),
      ];
      final result = findConfidentMatch<_Track>(
        tracks,
        (t) => t.name,
        (t) => t.artist,
        'Barış Manço',
        'Kuzu Kuzu',
      );
      expect(result?.name, 'kuzu kuzu');
    });

    test('falls back to a fuzzy match ignoring "(Remastered)" suffixes', () {
      const tracks = [
        _Track('Sakiler', 'Şıkıdım'),
        _Track('Sakiler', 'Tutkunum (Remastered)'),
      ];
      final result = findConfidentMatch<_Track>(
        tracks,
        (t) => t.name,
        (t) => t.artist,
        'Sakiler',
        'Tutkunum',
      );
      expect(result?.name, 'Tutkunum (Remastered)');
    });

    test(
      'returns null instead of guessing when the expected song is not among '
      'the results — regression test for the "wrong song/cover art" bug',
      () {
        const tracks = [_Track('Melihat Gülses', 'Completely Different Song')];
        final result = findConfidentMatch<_Track>(
          tracks,
          (t) => t.name,
          (t) => t.artist,
          'Melihat Gülses',
          'Alaturka',
        );
        expect(result, isNull);
      },
    );

    test('a same-artist different-song result never wins over no match', () {
      // Same shape as the real "Radyo Alaturka" bug: ICY says "Melihat
      // Gülses - Alaturka" but the search API only has a different track
      // by the same artist — must not silently accept tracks.first here.
      const tracks = [
        _Track('Melihat Gülses', 'Bambaşka Biri'),
        _Track('Melihat Gülses', 'Yalan Dünya'),
      ];
      final result = findConfidentMatch<_Track>(
        tracks,
        (t) => t.name,
        (t) => t.artist,
        'Melihat Gülses',
        'Alaturka',
      );
      expect(result, isNull);
    });

    test(
      'a different artist\'s same-titled track never wins — regression test '
      'for the "unrelated cover art" bug (artist name was never verified)',
      () {
        const tracks = [_Track('Some Cover Band', 'Canıma Minnet')];
        final result = findConfidentMatch<_Track>(
          tracks,
          (t) => t.name,
          (t) => t.artist,
          'Sakiler',
          'Canıma Minnet',
        );
        expect(result, isNull);
      },
    );
  });

  group('normalizeTitle', () {
    test('lowercases and trims', () {
      expect(normalizeTitle('  Kuzu Kuzu  '), 'kuzu kuzu');
    });

    test('strips parenthetical qualifiers', () {
      expect(normalizeTitle('Tutkunum (Remastered)'), 'tutkunum');
    });

    test('strips bracketed qualifiers', () {
      expect(normalizeTitle('Live Forever [Live]'), 'live forever');
    });
  });
}
