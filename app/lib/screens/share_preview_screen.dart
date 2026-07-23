import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../state/artist_spotlight_providers.dart';
import '../state/palette_providers.dart';
import '../state/player_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/share_card.dart';

/// Renders the shareable story card, previews it at on-screen size, and
/// captures the full-resolution version via RepaintBoundary when the user
/// actually shares (Section 8, CLAUDE.md).
class SharePreviewScreen extends ConsumerStatefulWidget {
  const SharePreviewScreen({super.key});

  @override
  ConsumerState<SharePreviewScreen> createState() =>
      _SharePreviewScreenState();
}

class _SharePreviewScreenState extends ConsumerState<SharePreviewScreen> {
  final _boundaryKey = GlobalKey();
  bool _sharing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mediaItem = ref.watch(currentMediaItemProvider).valueOrNull;
    final spotlight = ref.watch(artistSpotlightProvider).valueOrNull;
    final seedColor =
        ref.watch(dynamicSeedColorProvider).valueOrNull ?? kDefaultSeedColor;

    final stationName = mediaItem?.title ?? '';
    final artistName = spotlight?.artistName ?? '';
    final songTitle = spotlight?.songTitle ?? '';
    // Real artist/album art when the iTunes match resolved one; otherwise
    // the station's own logo — the card should never show nothing when a
    // perfectly good station favicon is sitting right there in mediaItem.
    final imageUrl = spotlight?.imageUrl ?? mediaItem?.artUri?.toString();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l10n.sharePreviewTitle)),
      bottomNavigationBar: const BannerAdWidget(),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1080 / 1920,
                // FittedBox scales the on-screen *preview* only — it sits
                // outside the RepaintBoundary, so toImage() below still
                // captures the card at its true 1080x1920 layout size.
                child: FittedBox(
                  child: RepaintBoundary(
                    key: _boundaryKey,
                    child: ShareCard(
                      stationName: stationName,
                      artistName: artistName,
                      songTitle: songTitle,
                      imageUrl: imageUrl,
                      seedColor: seedColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sharing ? null : _share,
                icon: const Icon(Icons.ios_share),
                label: Text(l10n.shareAction),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/radiobox_share.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles([XFile(file.path)]);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }
}
