import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'circular_visualizer.dart';

/// The Instagram/WhatsApp story card rendered for sharing (Section 8,
/// CLAUDE.md) — sized to the standard 1080x1920 story format. Built at
/// that exact logical size and captured via RepaintBoundary rather than
/// scaled to fit a phone screen; see SharePreviewScreen for how it's
/// displayed at preview size without affecting the captured resolution.
class ShareCard extends StatelessWidget {
  const ShareCard({
    super.key,
    required this.stationName,
    required this.subtitle,
    required this.seedColor,
  });

  final String stationName;
  final String subtitle;
  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1080,
      height: 1920,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [seedColor.withValues(alpha: 0.85), AppColors.background],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 3),
          Transform.scale(
            scale: 2.3,
            child: CircularVisualizer(
              color: Colors.white,
              isPlaying: true,
              style: 0,
            ),
          ),
          const Spacer(flex: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 72),
            child: Text(
              stationName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 64,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 72),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 36),
              ),
            ),
          ],
          const Spacer(flex: 4),
          Image.asset(
            'assets/branding/logo_horizontal.png',
            height: 72,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 72),
        ],
      ),
    );
  }
}
