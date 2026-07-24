import 'package:dialwave/services/wikipedia_artist_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('looksLikeMusicianOrPerson', () {
    test(
      'rejects an animal description — regression test for the "Ceylan" '
      'bug (a gazelle photo was shown for the Turkish singer Ceylan)',
      () {
        expect(
          looksLikeMusicianOrPerson(
            'boynuzlugiller familyasından Gazella cinsini oluşturan çift '
            'toynaklılar',
          ),
          isFalse,
        );
      },
    );

    test('accepts a real Turkish singer description', () {
      expect(looksLikeMusicianOrPerson('Türk şarkıcı'), isTrue);
    });

    test('rejects a filmmaker description (a different kind of person)', () {
      expect(
        looksLikeMusicianOrPerson(
          'Türk yönetmen, senarist, film yapımcısı ve fotoğrafçı',
        ),
        isFalse,
      );
    });

    test('accepts an English band description', () {
      expect(looksLikeMusicianOrPerson('British rock band'), isTrue);
    });

    test('accepts an English musician description', () {
      expect(looksLikeMusicianOrPerson('American singer-songwriter'), isTrue);
    });

    test('is case-insensitive', () {
      expect(looksLikeMusicianOrPerson('AMERICAN RAPPER'), isTrue);
    });
  });
}
