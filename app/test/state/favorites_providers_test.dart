import 'package:dialwave/state/favorites_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // Real FavoritesRepository, backed by shared_preferences' in-memory
    // mock store — no fake repository class needed for this one.
    SharedPreferences.setMockInitialValues({});
  });

  test('toggle adds a station id that was not yet a favorite', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(favoritesProvider.future);
    await container.read(favoritesProvider.notifier).toggle('station-1');

    expect(container.read(favoritesProvider).value, {'station-1'});
  });

  test('toggle removes a station id that is already a favorite', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(favoritesProvider.future);
    await container.read(favoritesProvider.notifier).toggle('station-1');
    await container.read(favoritesProvider.notifier).toggle('station-1');

    expect(container.read(favoritesProvider).value, isEmpty);
  });

  test('toggling one station id does not affect other favorites', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(favoritesProvider.future);
    await container.read(favoritesProvider.notifier).toggle('station-1');
    await container.read(favoritesProvider.notifier).toggle('station-2');
    await container.read(favoritesProvider.notifier).toggle('station-1');

    expect(container.read(favoritesProvider).value, {'station-2'});
  });

  test('persists across a fresh provider container (survives "app restart")', () async {
    final first = ProviderContainer();
    await first.read(favoritesProvider.future);
    await first.read(favoritesProvider.notifier).toggle('station-1');
    first.dispose();

    final second = ProviderContainer();
    addTearDown(second.dispose);
    final loaded = await second.read(favoritesProvider.future);

    expect(loaded, {'station-1'});
  });
}
