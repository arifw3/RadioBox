import 'dart:math';

import 'package:flutter/material.dart';

/// Winamp-style circular EQ visualizer (Section 7, CLAUDE.md). There's no
/// cheap way to get real PCM/FFT data out of an Icecast stream through
/// just_audio, so this is a deliberately "fake" but reactive-looking
/// animation — tapping cycles through [style] via the parent.
class CircularVisualizer extends StatefulWidget {
  const CircularVisualizer({
    super.key,
    required this.color,
    required this.isPlaying,
    required this.style,
  });

  final Color color;
  final bool isPlaying;
  final int style;

  static const styleCount = 3;

  @override
  State<CircularVisualizer> createState() => _CircularVisualizerState();
}

class _CircularVisualizerState extends State<CircularVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: const Size.square(260),
        painter: _VisualizerPainter(
          progress: _controller.value,
          color: widget.color,
          active: widget.isPlaying,
          style: widget.style,
        ),
      ),
    );
  }
}

class _VisualizerPainter extends CustomPainter {
  _VisualizerPainter({
    required this.progress,
    required this.color,
    required this.active,
    required this.style,
  });

  final double progress;
  final Color color;
  final bool active;
  final int style;

  static const _barCount = 32;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final baseRadius = size.width / 2 * 0.55;
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;
    final phase = progress * 2 * pi;

    for (var i = 0; i < _barCount; i++) {
      final angle = (i / _barCount) * 2 * pi;
      final wave = switch (style) {
        1 => sin(angle * 3 + phase),
        2 => sin(angle * 6 - phase) * cos(phase),
        _ => sin(angle * 2 + phase) * 0.6 + sin(angle * 5 - phase) * 0.4,
      };
      final magnitude = active ? (0.5 + 0.5 * wave).abs() : 0.15;
      final barLength = 16 + magnitude * 40;

      final start = center + Offset(cos(angle), sin(angle)) * baseRadius;
      final end =
          center + Offset(cos(angle), sin(angle)) * (baseRadius + barLength);
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VisualizerPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.active != active ||
      oldDelegate.style != style;
}
