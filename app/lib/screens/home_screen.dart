import 'package:dialwave_core/dialwave_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../state/country_providers.dart';
import '../state/drive_mode_providers.dart';
import '../state/favorites_providers.dart';
import '../state/play_history_providers.dart';
import '../state/player_providers.dart';
import '../theme/app_theme.dart';
import '../utils/time_of_day_suggestion.dart';
import '../widgets/alarm_button.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/country_picker_button.dart';
import '../widgets/language_picker_button.dart';
import '../widgets/mini_player.dart';
import '../widgets/sleep_timer_button.dart';
import 'search_screen.dart';

final _selectedTabProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final catalog = ref.watch(radioCatalogProvider);
    final selectedTab = ref.watch(_selectedTabProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Image.asset(
          'assets/branding/logo_horizontal.png',
          height: 40,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
        ),
        actions: [
          _AppBarIconButton(
            icon: Icons.search_rounded,
            tooltip: l10n.searchTooltip,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
            ),
          ),
          _AppBarIconButton(
            icon: Icons.directions_car_filled_outlined,
            tooltip: l10n.driveModeTooltip,
            onPressed: () => ref
                .read(driveModeManualOverrideProvider.notifier)
                .state = true,
          ),
          const _AppBarIconWrapper(child: CountryPickerButton()),
          const _OverflowMenuButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: _SegmentedTabs(
              labels: [l10n.tabAll, l10n.tabFavorites],
              selectedIndex: selectedTab,
              onChanged: (i) => ref.read(_selectedTabProvider.notifier).state = i,
            ),
          ),
          Expanded(
            child: catalog.when(
              data: (data) => selectedTab == 0
                  ? _AllStationsTab(allStations: data.stations)
                  : _FavoritesTab(allStations: data.stations),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.catalogLoadError(error.toString()),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [MiniPlayer(), BannerAdWidget()],
      ),
    );
  }
}

class _AppBarIconWrapper extends StatelessWidget {
  const _AppBarIconWrapper({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceRaised,
          shape: BoxShape.circle,
        ),
        child: child,
      ),
    );
  }
}

class _AppBarIconButton extends StatelessWidget {
  const _AppBarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _AppBarIconWrapper(
      child: IconButton(icon: Icon(icon), tooltip: tooltip, onPressed: onPressed),
    );
  }
}

enum _OverflowAction { alarm, sleepTimer, language }

/// Alarm + Sleep Timer + Language share one overflow menu — five-plus
/// separate circular AppBar icons left no room for the logo to breathe.
class _OverflowMenuButton extends ConsumerWidget {
  const _OverflowMenuButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return _AppBarIconWrapper(
      child: PopupMenuButton<_OverflowAction>(
        icon: const Icon(Icons.more_vert),
        tooltip: l10n.moreTooltip,
        onSelected: (action) {
          switch (action) {
            case _OverflowAction.alarm:
              openAlarmSheet(context, ref);
            case _OverflowAction.sleepTimer:
              openSleepTimerSheet(context, ref);
            case _OverflowAction.language:
              openLanguageSheet(context, ref);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _OverflowAction.alarm,
            child: ListTile(
              leading: const Icon(Icons.alarm),
              title: Text(l10n.alarmLabel),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: _OverflowAction.sleepTimer,
            child: ListTile(
              leading: const Icon(Icons.bedtime_outlined),
              title: Text(l10n.sleepTimerLabel),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: _OverflowAction.language,
            child: ListTile(
              leading: const Icon(Icons.language),
              title: Text(l10n.languageLabel),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

/// A rounded pill segmented control — replaces the flat Material TabBar to
/// match the "premium dark UI kit" look (rounded filter chips everywhere).
class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: i == selectedIndex ? AppColors.accent : null,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: i == selectedIndex ? Colors.white : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The onboarding-detected (or manually picked) country's station list,
/// topped with a hero card (Section 5 & 7, CLAUDE.md) — all computed
/// on-device, no cloud calls.
class _AllStationsTab extends ConsumerWidget {
  const _AllStationsTab({required this.allStations});

  final List<RadioStation> allStations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selectedCountry = ref.watch(selectedCountryProvider);
    final stations = selectedCountry == null
        ? allStations
        : allStations.where((s) => s.countryCode == selectedCountry).toList();

    if (stations.isEmpty) {
      return Center(child: Text(l10n.noStationsToList));
    }

    final suggestion = suggestionForHour(DateTime.now().hour);
    final suggested = suggestion == null
        ? const <RadioStation>[]
        : stations
            .where(
              (s) => s.tags.any(
                (tag) => suggestion.tagKeywords
                    .any((keyword) => tag.toLowerCase().contains(keyword)),
              ),
            )
            .toList();

    final sortedByPopularity = [...stations]
      ..sort((a, b) => b.clickCount.compareTo(a.clickCount));
    final hero = (suggested.isNotEmpty ? suggested : sortedByPopularity).first;
    // Coverage note: the time-of-day suggestion label itself (e.g. "Gece
    // Ritmi") isn't localized yet — only this static fallback is.
    final heroLabel = suggested.isNotEmpty ? suggestion!.label : l10n.featuredLabel;

    // "Sık dinlenen önce": personal play count beats favorite status or
    // radio-browser.info's global click count — a station you actually
    // listen to a lot should float up even if you never hearted it.
    final playCounts = ref.watch(playHistoryProvider);
    final rest = stations.where((s) => s.id != hero.id).toList()
      ..sort((a, b) {
        final byPersonalPlays =
            (playCounts[b.id] ?? 0).compareTo(playCounts[a.id] ?? 0);
        return byPersonalPlays != 0
            ? byPersonalPlays
            : b.clickCount.compareTo(a.clickCount);
      });

    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _HeroCard(label: heroLabel, station: hero),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(l10n.allStationsHeading, style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 4),
        _StationList(stations: rest),
      ],
    );
  }
}

class _HeroCard extends ConsumerWidget {
  const _HeroCard({required this.label, required this.station});

  final String label;
  final RadioStation station;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: () => ref.read(audioHandlerProvider).playStation(station),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: AppColors.surfaceRaised),
              // Most station logos are small square favicons — stretching
              // one across a 16:9 hero with BoxFit.cover looks blurry and
              // distorted, so show it at its natural aspect ratio instead.
              // (Tried a blurred-backdrop-plus-sharp-logo layout first, but
              // fetching the same favicon twice concurrently made some
              // CDNs — e.g. kanal7.com — fail to decode it at all.)
              if (station.favicon.isNotEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(36),
                    child: Image.network(
                      station.favicon,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.nowLabel(label),
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      station.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab({required this.allStations});

  final List<RadioStation> allStations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteIds = ref.watch(favoritesProvider).valueOrNull;

    if (favoriteIds == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final favorites =
        allStations.where((s) => favoriteIds.contains(s.id)).toList();

    if (favorites.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            AppLocalizations.of(context)!.emptyFavorites,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return _StationList(stations: favorites);
  }
}

class _StationList extends ConsumerWidget {
  const _StationList({required this.stations});

  final List<RadioStation> stations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (stations.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noStationsToList));
    }
    final favoriteIds = ref.watch(favoritesProvider).valueOrNull ?? const {};

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: stations.length,
      itemBuilder: (context, index) {
        final station = stations[index];
        final isFavorite = favoriteIds.contains(station.id);
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: station.favicon.isNotEmpty
                ? Image.network(
                    station.favicon,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _FallbackArt(name: station.name),
                  )
                : _FallbackArt(name: station.name),
          ),
          title: Text(
            station.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text(
            station.tags.isNotEmpty
                ? station.tags.join(', ')
                : station.countryCode,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              size: 22,
            ),
            color: isFavorite ? AppColors.pink : AppColors.textMuted,
            onPressed: () =>
                ref.read(favoritesProvider.notifier).toggle(station.id),
          ),
          onTap: () => ref.read(audioHandlerProvider).playStation(station),
        );
      },
    );
  }
}

class _FallbackArt extends StatelessWidget {
  const _FallbackArt({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(color: AppColors.accent),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    );
  }
}
