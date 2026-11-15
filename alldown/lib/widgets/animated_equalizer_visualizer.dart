import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A sleek, high-performance animated graphic equalizer visualizer.
/// Displays dynamic frequency bars that dance smoothly when audio is playing.
class AnimatedEqualizerVisualizer extends StatefulWidget {
  final bool isPlaying;
  final int barCount;
  final double height;
  final double spacing;
  final Color? startColor;
  final Color? endColor;

  const AnimatedEqualizerVisualizer({
    super.key,
    required this.isPlaying,
    this.barCount = 24,
    this.height = 36,
    this.spacing = 3.0,
    this.startColor,
    this.endColor,
  });

  @override
  State<AnimatedEqualizerVisualizer> createState() => _AnimatedEqualizerVisualizerState();
}

class _AnimatedEqualizerVisualizerState extends State<AnimatedEqualizerVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedEqualizerVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        if (!_controller.isAnimating) {
          _controller.repeat();
        }
      } else {
        // Stop animation gracefully
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(double.infinity, widget.height),
          painter: _EqualizerPainter(
            progress: _controller.value,
            isPlaying: widget.isPlaying,
            barCount: widget.barCount,
            spacing: widget.spacing,
            startColor: widget.startColor ?? AppColors.secondary,
            endColor: widget.endColor ?? AppColors.primaryAccent,
          ),
        );
      },
    );
  }
}

class _EqualizerPainter extends CustomPainter {
  final double progress;
  final bool isPlaying;
  final int barCount;
  final double spacing;
  final Color startColor;
  final Color endColor;

  _EqualizerPainter({
    required this.progress,
    required this.isPlaying,
    required this.barCount,
    required this.spacing,
    required this.startColor,
    required this.endColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || barCount <= 0) return;

    final totalSpacing = spacing * (barCount - 1);
    final barWidth = math.max(2.0, (size.width - totalSpacing) / barCount);
    final twoPi = 2 * math.pi;
    final t = progress * twoPi;

    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      final normalizedIndex = i / (barCount - 1);
      double normalizedHeight;

      if (isPlaying) {
        // Multi-frequency synthesis to mimic authentic spectrum analyzer
        // 1. Bass component (prominent on low indices)
        final bassWeight = math.exp(-normalizedIndex * 3.5);
        final bass = math.sin(t * 3.0 + i * 0.4) * 0.5 + 0.5;

        // 2. Mid-range component (rhythmic pulses in the middle)
        final midWeight = math.sin(normalizedIndex * math.pi);
        final mid = (math.sin(t * 5.5 + i * 0.7) * math.cos(t * 2.2 - i * 0.3)) * 0.5 + 0.5;

        // 3. Treble component (fast jitter on higher indices)
        final trebleWeight = normalizedIndex;
        final treble = (math.sin(t * 9.0 + i * 1.1) * 0.5 + 0.5) *
            (math.cos(t * 4.5 + i * 0.5) * 0.5 + 0.5);

        // Combined dynamic height (between 0.12 and 1.0)
        final rawHeight = 0.15 +
            bassWeight * bass * 0.8 +
            midWeight * mid * 0.7 +
            trebleWeight * treble * 0.55;

        normalizedHeight = rawHeight.clamp(0.12, 1.0);
      } else {
        // Idle gentle curve when paused
        final idleWave = math.sin(normalizedIndex * math.pi) * 0.15 + 0.1;
        normalizedHeight = idleWave.clamp(0.08, 0.25);
      }

      final barH = size.height * normalizedHeight;
      final x = i * (barWidth + spacing);
      final y = size.height - barH;

      // Color interpolation across spectrum
      final barColor = Color.lerp(startColor, endColor, normalizedIndex)!;
      paint.color = barColor;

      // Draw rounded capsule bar
      final rect = Rect.fromLTWH(x, y, barWidth, barH);
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(barWidth / 2));
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EqualizerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.barCount != barCount;
  }
}
