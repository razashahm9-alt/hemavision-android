import 'package:flutter/material.dart';

class AnimatedCounterWidget extends StatelessWidget {
  final double targetValue;
  final Duration duration;
  final String suffix;
  final TextStyle? style;

  const AnimatedCounterWidget({
    super.key,
    required this.targetValue,
    this.duration = const Duration(milliseconds: 1500),
    this.suffix = '',
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: targetValue),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, value, __) {
        final text = targetValue % 1 == 0
            ? value.toInt().toString()
            : value.toStringAsFixed(1);
        return Text(
          '$text$suffix',
          style:
              style ??
              Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        );
      },
    );
  }
}
