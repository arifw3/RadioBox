import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/drive_mode_screen.dart';
import 'screens/home_screen.dart';
import 'state/alarm_providers.dart';
import 'state/drive_mode_providers.dart';
import 'state/palette_providers.dart';
import 'theme/app_theme.dart';

class DialWaveApp extends ConsumerWidget {
  const DialWaveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // App-wide dynamic color palette (Section 7, CLAUDE.md) — tinted by
    // whatever station is currently playing; falls back to the brand mark's
    // own gradient color when nothing's playing yet.
    final seedColor =
        ref.watch(dynamicSeedColorProvider).valueOrNull ?? kDefaultSeedColor;

    return MaterialApp(
      title: 'DialWave',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(seedColor),
      home: const _RootScreen(),
    );
  }
}

class _RootScreen extends ConsumerWidget {
  const _RootScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Side-effect only: starts alarm playback if this launch came from
    // tapping the alarm notification. Result is intentionally unused.
    ref.watch(alarmAutoplayProvider);

    final driveMode = ref.watch(driveModeProvider);
    return driveMode ? const DriveModeScreen() : const HomeScreen();
  }
}
