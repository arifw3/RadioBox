import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'circular_visualizer.dart';

/// The Instagram/WhatsApp story card rendered for sharing (Section 8,
/// CLAUDE.md) — sized to the standard 1080x1920 story format. Built at
/// that exact logical size and captured via RepaintBoundary rather than
/// scaled to fit a phone screen; see SharePreviewScreen for how it's
/// displayed at preview size without affecting the captured resolution.
///
/// Uses the real artist/album art (or the station's own logo if no artist
/// match was found) as a full-bleed photo background — falls back to the
/// app's dynamic color gradient + visualizer glyph only when neither
/// image is available at all.
class ShareCard extends StatelessWidget {
  const ShareCard({
    super.key,
    required this.stationName,
    required this.artistName,
    required this.songTitle,
    required this.imageUrl,
    required this.seedColor,
  });

  final String stationName;
  final String artistName;
  final String songTitle;
  final String? imageUrl;
  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final title = artistName.isNotEmpty ? artistName : stationName;

    return SizedBox(
      width: 1080,
      height: 1920,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
            CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover)
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    seedColor.withValues(alpha: 0.85),
                    AppColors.background,
                  ],
                ),
              ),
              child: Center(
                child: Transform.scale(
                  scale: 2.3,
                  child: const CircularVisualizer(
                    color: Colors.white24,
                    isPlaying: true,
                    style: 0,
                  ),
                ),
              ),
            ),
          // Clear over most of the photo, dark enough at the bottom third
          // for the text block to stay legible over any image.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.transparent, Colors.black87],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          Positioned(
            top: 64,
            right: 64,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Image.asset(
                'assets/branding/logo_horizontal.png',
                height: 36,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            left: 64,
            right: 64,
            bottom: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 68,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 40),
                _InfoRow(icon: Icons.radio_rounded, label: stationName),
                if (songTitle.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _InfoRow(icon: Icons.music_note_rounded, label: songTitle),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 36),
        const SizedBox(width: 20),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
