import 'package:dialwave_core/dialwave_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../state/artist_spotlight_providers.dart';
import '../state/country_providers.dart';
import '../state/drive_mode_providers.dart';
import '../state/favorites_providers.dart';
import '../state/network_providers.dart';
import '../state/play_history_providers.dart';
import '../state/player_providers.dart';
import '../theme/app_theme.dart';
import '../utils/contact.dart';
import '../utils/playback_navigation.dart';
import '../utils/time_of_day_suggestion.dart';
import '../widgets/alarm_button.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/country_picker_button.dart';
import '../widgets/language_picker_button.dart';
import '../widgets/mini_player.dart';
import '../widgets/sleep_timer_button.dart';
import '../widgets/station_art.dart';
import 'search_screen.dart';
import 'song_history_screen.dart';

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
          _AppBarIconButton(
            icon: Icons.history,
            tooltip: l10n.songHistoryLabel,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SongHistoryScreen()),
            ),
          ),
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

enum _OverflowAction {
  alarm,
  sleepTimer,
  language,
  countryPicker,
  wifiOnly,
  contact,
}

/// Alarm + Sleep Timer + Language + Dünya Turu + Wi-Fi Only + Contact
/// share one overflow menu — six-plus separate circular AppBar icons left
/// no room for the logo to breathe.
class _OverflowMenuButton extends ConsumerWidget {
  const _OverflowMenuButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final wifiOnly = ref.watch(wifiOnlyProvider);
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
            case _OverflowAction.countryPicker:
              openCountrySheet(context, ref);
            case _OverflowAction.wifiOnly:
              ref.read(wifiOnlyProvider.notifier).toggle();
            case _OverflowAction.contact:
              openContactEmail();
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
          const PopupMenuItem(
            value: _OverflowAction.countryPicker,
            child: ListTile(
              leading: Icon(Icons.public),
              title: Text('Dünya Turu'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuDivider(),
          CheckedPopupMenuItem(
            value: _OverflowAction.wifiOnly,
            checked: wifiOnly,
            child: Text(l10n.wifiOnlyLabel),
          ),
          PopupMenuItem(
            value: _OverflowAction.contact,
            child: ListTile(
              leading: const Icon(Icons.mail_outline),
              title: Text(l10n.contactLabel),
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
class _AllStationsTab extends ConsumerStatefulWidget {
  const _AllStationsTab({required this.allStations});

  final List<RadioStation> allStations;

  @override
  ConsumerState<_AllStationsTab> createState() => _AllStationsTabState();
}

class _AllStationsTabState extends ConsumerState<_AllStationsTab> {
  // A snapshot, not a live watch: re-sorting the list the instant a play
  // count changes (i.e. right as the user taps something) made stations
  // jump position while still on screen, which read as a bug ("I tapped
  // the wrong thing"). Personal-play ordering should only change the
  // *next* time this tab is entered, not mid-session.
  late final Map<String, int> _playCountSnapshot =
      ref.read(playHistoryProvider);

  String? _selectedCategory;
  bool _alphabetical = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selectedCountry = ref.watch(selectedCountryProvider);
    final countryStations = selectedCountry == null
        ? widget.allStations
        : widget.allStations
            .where((s) => s.countryCode == selectedCountry)
            .toList();

    if (countryStations.isEmpty) {
      return Center(child: Text(l10n.noStationsToList));
    }

    // Categories are derived from whatever tags actually show up in this
    // country's stations rather than a fixed list — radio-browser.info
    // tags are free text with no set taxonomy, and a hardcoded Turkish
    // genre list wouldn't make sense once "Dünya Turu" switches country.
    final categories = _topCategories(countryStations);
    final category = _selectedCategory;
    final stations = category == null
        ? countryStations
        : countryStations
            .where(
              (s) => s.tags.any((t) => t.toLowerCase() == category),
            )
            .toList();

    if (stations.isEmpty) {
      return Column(
        children: [
          _CategorySortBar(
            categories: categories,
            selectedCategory: _selectedCategory,
            alphabetical: _alphabetical,
            onCategorySelected: (c) => setState(() => _selectedCategory = c),
            onSortModeChanged: (a) => setState(() => _alphabetical = a),
          ),
          Expanded(child: Center(child: Text(l10n.noStationsToList))),
        ],
      );
    }

    // Alphabetical browsing is a systematic scan through everything
    // matching the filter — the "featured" hero pick and personal-play
    // ordering below are about surfacing a favorite quickly, which is the
    // opposite intent, so skip both and just show a flat A-Z list.
    if (_alphabetical) {
      final sorted = [...stations]
        ..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      return Column(
        children: [
          _CategorySortBar(
            categories: categories,
            selectedCategory: _selectedCategory,
            alphabetical: _alphabetical,
            onCategorySelected: (c) => setState(() => _selectedCategory = c),
            onSortModeChanged: (a) => setState(() => _alphabetical = a),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [_StationSliverList(stations: sorted)],
            ),
          ),
        ],
      );
    }

    // A station the user actually keeps coming back to beats any generic
    // suggestion — only fall back to time-of-day/popularity for a
    // first-run user with no play history yet.
    final mostPlayed = [...stations]
      ..sort(
        (a, b) => (_playCountSnapshot[b.id] ?? 0)
            .compareTo(_playCountSnapshot[a.id] ?? 0),
      );
    final hasPlayHistory =
        mostPlayed.isNotEmpty && (_playCountSnapshot[mostPlayed.first.id] ?? 0) > 0;

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
    final hero = hasPlayHistory
        ? mostPlayed.first
        : (suggested.isNotEmpty ? suggested : sortedByPopularity).first;
    // Coverage note: the time-of-day suggestion label itself (e.g. "Gece
    // Ritmi") isn't localized yet — only this static fallback is.
    final heroLabel = hasPlayHistory
        ? l10n.mostPlayedLabel
        : (suggested.isNotEmpty ? suggestion!.label : l10n.featuredLabel);

    // "Sık dinlenen önce": personal play count beats favorite status or
    // radio-browser.info's global click count — a station you actually
    // listen to a lot should float up even if you never hearted it.
    final rest = stations.where((s) => s.id != hero.id).toList()
      ..sort((a, b) {
        final byPersonalPlays = (_playCountSnapshot[b.id] ?? 0)
            .compareTo(_playCountSnapshot[a.id] ?? 0);
        return byPersonalPlays != 0
            ? byPersonalPlays
            : b.clickCount.compareTo(a.clickCount);
      });

    // A plain ListView with a nested shrinkWrap ListView.builder inside it
    // (the previous layout) defeats lazy loading entirely: shrinkWrap
    // forces every single item — all ~2000 stations, each with its own
    // Image.network — to build up front instead of only the ones on
    // screen. A single CustomScrollView with real slivers keeps the hero
    // card as one item and the station rows properly virtualized.
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _CategorySortBar(
            categories: categories,
            selectedCategory: _selectedCategory,
            alphabetical: _alphabetical,
            onCategorySelected: (c) => setState(() => _selectedCategory = c),
            onSortModeChanged: (a) => setState(() => _alphabetical = a),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _HeroCard(label: heroLabel, station: hero),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l10n.allStationsHeading, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 4)),
        _StationSliverList(stations: rest),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
      ],
    );
  }

  /// Top N most common tags in this station set, title-cased for display.
  /// Recomputed from `countryStations` (not the category-filtered list) so
  /// the chip row itself doesn't shrink away once a category is picked.
  List<String> _topCategories(List<RadioStation> stations, {int limit = 10}) {
    final counts = <String, int>{};
    for (final station in stations) {
      for (final tag in station.tags) {
        final normalized = tag.trim().toLowerCase();
        if (normalized.isEmpty) continue;
        counts.update(normalized, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    final sorted = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return sorted.take(limit).toList();
  }
}

/// Category filter chips + a Popüler/A-Z sort toggle, sitting above the
/// station list on the "Tümü" tab.
class _CategorySortBar extends StatelessWidget {
  const _CategorySortBar({
    required this.categories,
    required this.selectedCategory,
    required this.alphabetical,
    required this.onCategorySelected,
    required this.onSortModeChanged,
  });

  final List<String> categories;
  final String? selectedCategory;
  final bool alphabetical;
  final ValueChanged<String?> onCategorySelected;
  final ValueChanged<bool> onSortModeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _CategoryChip(
                    label: l10n.categoryAllLabel,
                    selected: selectedCategory == null,
                    onTap: () => onCategorySelected(null),
                  ),
                  for (final category in categories) ...[
                    const SizedBox(width: 8),
                    _CategoryChip(
                      label: category[0].toUpperCase() + category.substring(1),
                      selected: selectedCategory == category,
                      onTap: () => onCategorySelected(category),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: Icon(
                alphabetical ? Icons.sort_by_alpha : Icons.local_fire_department,
              ),
              tooltip: alphabetical
                  ? l10n.sortAlphabeticalLabel
                  : l10n.sortPopularLabel,
              color: AppColors.accent,
              onPressed: () => onSortModeChanged(!alphabetical),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
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

    // This hero is "the user's most-played station", which isn't
    // necessarily what's playing right now. When it IS, reuse the exact
    // spotlight chain (iTunes -> Deezer -> Wikipedia) Now Playing already
    // resolves. When it's not, a short-lived ICY metadata probe (Wi-Fi-
    // gated the same way starting playback is) reads what's live on it
    // without requiring the user to press play first — same chain either
    // way, just a different source for the raw "Artist - Song" text.
    final isCurrentlyPlayingThis =
        ref.watch(currentMediaItemProvider).valueOrNull?.id == station.id;
    final spotlightAsync = isCurrentlyPlayingThis
        ? ref.watch(artistSpotlightProvider)
        : ref.watch(heroSpotlightProvider(station));
    final spotlight = spotlightAsync.valueOrNull;
    final hasLiveSpotlight = spotlight?.imageUrl?.isNotEmpty ?? false;
    final isResolvingSpotlight = spotlightAsync.isLoading && !hasLiveSpotlight;
    final playing = isCurrentlyPlayingThis &&
        (ref.watch(playbackStateProvider).valueOrNull?.playing ?? false);

    return Semantics(
      button: true,
      label: l10n.playStationLabel(station.name),
      excludeSemantics: true,
      child: GestureDetector(
      onTap: () => playStationAndShowNowPlaying(context, ref, station),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: AppColors.surfaceRaised),
              if (hasLiveSpotlight)
                StationArt(
                  imageUrl: spotlight!.imageUrl!,
                  fit: BoxFit.cover,
                )
              // Most station logos are small square favicons — stretching
              // one across a 16:9 hero with BoxFit.cover looks blurry and
              // distorted, so show it at its natural aspect ratio instead.
              // (Tried a blurred-backdrop-plus-sharp-logo layout first, but
              // fetching the same favicon twice concurrently made some
              // CDNs — e.g. kanal7.com — fail to decode it at all.)
              else if (station.favicon.isNotEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(36),
                    child: StationArt(
                      imageUrl: station.favicon,
                      fit: BoxFit.contain,
                      errorWidget: (_) => const SizedBox.shrink(),
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
              if (hasLiveSpotlight || isResolvingSpotlight)
                Positioned(
                  left: 20,
                  top: 18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      station.name,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 18,
                child: hasLiveSpotlight
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            spotlight!.artistName,
                            style: Theme.of(context).textTheme.headlineSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (spotlight.songTitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              spotlight.songTitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.white70),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      )
                    : isResolvingSpotlight
                        ? const _HeroTextSkeleton()
                        : Column(
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
                  child: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// Placeholder for the artist-name/song-title pair while the spotlight
/// chain (iTunes -> Deezer -> Wikipedia) is still resolving for the
/// currently-playing hero station.
class _HeroTextSkeleton extends StatefulWidget {
  const _HeroTextSkeleton();

  @override
  State<_HeroTextSkeleton> createState() => _HeroTextSkeletonState();
}

class _HeroTextSkeletonState extends State<_HeroTextSkeleton>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller.drive(Tween(begin: 0.3, end: 0.7)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 160,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 100,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
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
    return CustomScrollView(
      slivers: [_StationSliverList(stations: favorites)],
    );
  }
}

/// Real virtualization (Section: on-device performance) — a bare
/// SliverList.builder, always used inside a CustomScrollView. Never wrap
/// this in shrinkWrap: true; that forces every row (and its
/// Image.network) to build immediately instead of only the visible ones,
/// which is what made the station list slow to open and slow to react to
/// taps on a ~2000-station catalog.
class _StationSliverList extends ConsumerWidget {
  const _StationSliverList({required this.stations});

  final List<RadioStation> stations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteIds = ref.watch(favoritesProvider).valueOrNull ?? const {};

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      sliver: SliverList.builder(
        itemCount: stations.length,
        itemBuilder: (context, index) {
          final station = stations[index];
          final isFavorite = favoriteIds.contains(station.id);
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: station.favicon.isNotEmpty
                  ? StationArt(
                      imageUrl: station.favicon,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorWidget: (_) => _FallbackArt(name: station.name),
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
              tooltip: isFavorite
                  ? AppLocalizations.of(context)!.favoriteRemove
                  : AppLocalizations.of(context)!.favoriteAdd,
              onPressed: () =>
                  ref.read(favoritesProvider.notifier).toggle(station.id),
            ),
            onTap: () => playStationAndShowNowPlaying(context, ref, station),
          );
        },
      ),
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
