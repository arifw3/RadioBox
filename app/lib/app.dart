import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/drive_mode_screen.dart';
import 'screens/home_screen.dart';
import 'state/drive_mode_providers.dart';

class DialWaveApp extends StatelessWidget {
  const DialWaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DialWave',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6C5CE7),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const _RootScreen(),
    );
  }
}

class _RootScreen extends ConsumerWidget {
  const _RootScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driveMode = ref.watch(driveModeProvider);
    return driveMode ? const DriveModeScreen() : const HomeScreen();
  }
}
