import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class TelemetryWaveform extends StatelessWidget {
  const TelemetryWaveform({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      width: double.infinity,
      child: CustomPaint(
        painter: WaveformPainter(),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    final path = Path();
    path.moveTo(0, height * 0.85);

    // Dynamic wave points
    final points = [
      Offset(0, height * 0.85),
      Offset(width * 0.08, height * 0.72),
      Offset(width * 0.16, height * 0.78),
      Offset(width * 0.24, height * 0.55),
      Offset(width * 0.32, height * 0.65),
      Offset(width * 0.40, height * 0.38),
      Offset(width * 0.48, height * 0.48),
      Offset(width * 0.56, height * 0.25),
      Offset(width * 0.64, height * 0.42),
      Offset(width * 0.72, height * 0.18),
      Offset(width * 0.80, height * 0.32),
      Offset(width * 0.88, height * 0.12),
      Offset(width * 0.94, height * 0.28),
      Offset(width, height * 0.22),
    ];

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    path.lineTo(width, points.last.dy);

    // Stroke paint
    final strokePaint = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Fill path
    final fillPath = Path.from(path)
      ..lineTo(width, height)
      ..lineTo(0, height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.secondary.withValues(alpha: 0.45),
          AppColors.secondary.withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, width, height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

