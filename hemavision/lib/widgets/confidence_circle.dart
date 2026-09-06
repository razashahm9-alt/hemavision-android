import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../app_colors.dart';

class ConfidenceCircleWidget extends StatelessWidget {
  final double score;

  const ConfidenceCircleWidget({super.key, required this.score});

  Color get color {
    if (score > 80) return AppColors.successGreen;
    if (score >= 50) return AppColors.warningYellow;
    return AppColors.accentRed;
  }

  @override
  Widget build(BuildContext context) {
    return CircularPercentIndicator(
      radius: 58,
      lineWidth: 11,
      percent: (score.clamp(0, 100)) / 100,
      animation: true,
      animationDuration: 1400,
      circularStrokeCap: CircularStrokeCap.round,
      progressColor: color,
      backgroundColor: AppColors.bgSurface,
      center: Text(
        '${score.toStringAsFixed(0)}%',
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
      ),
    );
  }
}
