import 'dart:math';

import 'package:flutter/material.dart';

import '../app_colors.dart';

class DnaAnimationWidget extends StatefulWidget {
  final double height;

  const DnaAnimationWidget({super.key, this.height = 120});

  @override
  State<DnaAnimationWidget> createState() => _DnaAnimationWidgetState();
}

class _DnaAnimationWidgetState extends State<DnaAnimationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
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
      builder: (_, __) => CustomPaint(
        painter: _DnaPainter(_controller.value),
        size: Size(double.infinity, widget.height),
      ),
    );
  }
}

class _DnaPainter extends CustomPainter {
  final double phase;

  _DnaPainter(this.phase);

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final amp = size.height * .32;
    final step = size.width / 14;
    final teal = Paint()
      ..color = AppColors.primaryLight.withOpacity(.82)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final red = Paint()
      ..color = AppColors.accentSoft.withOpacity(.72)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final rung = Paint()
      ..color = AppColors.textSecondary.withOpacity(.18)
      ..strokeWidth = 1.2;

    final top = Path();
    final bottom = Path();
    for (double x = 0; x <= size.width; x += 4) {
      final angle = (x / size.width * pi * 4) + phase * pi * 2;
      final y1 = centerY + sin(angle) * amp;
      final y2 = centerY - sin(angle) * amp;
      if (x == 0) {
        top.moveTo(x, y1);
        bottom.moveTo(x, y2);
      } else {
        top.lineTo(x, y1);
        bottom.lineTo(x, y2);
      }
    }
    canvas.drawPath(top, teal);
    canvas.drawPath(bottom, red);

    for (double x = step; x < size.width; x += step) {
      final angle = (x / size.width * pi * 4) + phase * pi * 2;
      final y1 = centerY + sin(angle) * amp;
      final y2 = centerY - sin(angle) * amp;
      canvas.drawLine(Offset(x, y1), Offset(x, y2), rung);
      canvas.drawCircle(
        Offset(x, y1),
        3.5,
        Paint()..color = AppColors.primaryLight,
      );
      canvas.drawCircle(
        Offset(x, y2),
        3.5,
        Paint()..color = AppColors.accentSoft,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DnaPainter oldDelegate) =>
      oldDelegate.phase != phase;
}
