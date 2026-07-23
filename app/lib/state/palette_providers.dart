import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

import '../theme/app_theme.dart';
import 'player_providers.dart';

/// Brand pink from the Radio Box mark — the app's identity before any
/// station-specific tint kicks in.
const kDefaultSeedColor = AppColors.pink;

/// Dominant color of the current station's logo (Section 7, CLAUDE.md) —
/// falls back to the app's default seed if there's no art or extraction
/// fails (e.g. a broken favicon URL).
final dynamicSeedColorProvider = FutureProvider<Color>((ref) async {
  final artUri = ref.watch(currentMediaItemProvider).valueOrNull?.artUri;
  if (artUri == null) return kDefaultSeedColor;

  try {
    final palette = await PaletteGenerator.fromImageProvider(
      NetworkImage(artUri.toString()),
      size: const Size(100, 100),
    );
    return palette.dominantColor?.color ??
        palette.vibrantColor?.color ??
        kDefaultSeedColor;
  } catch (_) {
    return kDefaultSeedColor;
  }
});
