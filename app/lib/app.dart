import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'screens/drive_mode_screen.dart';
import 'screens/home_screen.dart';
import 'state/artist_spotlight_providers.dart';
import 'state/drive_mode_providers.dart';
import 'state/locale_providers.dart';
import 'state/network_providers.dart';
import 'state/palette_providers.dart';
import 'state/play_history_providers.dart';
import 'state/player_providers.dart';
import 'state/review_providers.dart';
import 'state/song_history_providers.dart';
import 'theme/app_theme.dart';

class RadioBoxApp extends ConsumerWidget {
  const RadioBoxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // App-wide dynamic color palette (Section 7, CLAUDE.md) — tinted by
    // whatever station is currently playing; falls back to the brand mark's
    // own gradient color when nothing's playing yet.
    final seedColor =
        ref.watch(dynamicSeedColorProvider).valueOrNull ?? kDefaultSeedColor;

    return MaterialApp(
      title: 'Radio Box',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(seedColor),
      locale: ref.watch(localeProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _RootScreen(),
    );
  }
}

class _RootScreen extends ConsumerWidget {
  const _RootScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Records a play exactly once per station change, regardless of
    // where playback was triggered from (list tap, hero card, Drive Mode
    // swipe) — drives "sık dinlenen önce" ordering on the station list.
    ref.listen(currentMediaItemProvider, (previous, next) {
      final id = next.valueOrNull?.id;
      if (id != null && id != previous?.valueOrNull?.id) {
        ref.read(playHistoryProvider.notifier).recordPlay(id);
        ref
            .read(reviewPromptServiceProvider)
            .maybePromptAfterPlay(ref.read(playHistoryProvider));
      }
    });

    // Logs a timestamped entry every time real ICY "Artist - Song" text
    // shows up (never the plain country-code fallback — rawNowPlayingTextProvider
    // already filters that out), independent of whether the iTunes lookup
    // for the artist spotlight card finds anything.
    ref.listen(rawNowPlayingTextProvider, (previous, next) {
      if (next != null && next != previous) {
        final stationName =
            ref.read(currentMediaItemProvider).valueOrNull?.title ?? '';
        ref.read(songHistoryProvider.notifier).record(next, stationName);
      }
    });

    // Data-saving notice (Section 8, CLAUDE.md): only worth a warning if
    // a stream is actively playing across the handoff — a silent app
    // sitting in the background switching networks isn't burning data.
    ref.listen(connectivityProvider, (previous, next) {
      final before = previous?.valueOrNull;
      final after = next.valueOrNull;
      if (before == null || after == null) return;
      final isPlaying = ref.read(playbackStateProvider).valueOrNull?.playing ?? false;
      if (!isPlaying || !isOnWifi(before) || isOnWifi(after)) return;

      if (ref.read(wifiOnlyProvider)) {
        // "Wi-Fi only" means the stream shouldn't silently keep burning
        // mobile data just because it already started on Wi-Fi.
        ref.read(audioHandlerProvider).pause();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.wifiOnlyBlocked)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.dataUsageSwitchWarning)),
        );
      }
    });

    final driveMode = ref.watch(driveModeProvider);
    return driveMode ? const DriveModeScreen() : const HomeScreen();
  }
}
