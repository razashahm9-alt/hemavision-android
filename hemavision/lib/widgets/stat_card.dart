import 'package:flutter/material.dart';

import '../app_colors.dart';
import 'animated_counter.dart';

class StatCardWidget extends StatelessWidget {
  final IconData icon;
  final double value;
  final String label;
  final Color accentColor;
  final String suffix;
  final String? textValue;

  const StatCardWidget({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.accentColor,
    this.suffix = '',
    this.textValue,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.bgCard,
      child: SizedBox(
        height: 128,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              height: 4,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: accentColor),
                  const SizedBox(height: 12),
                  textValue == null
                      ? AnimatedCounterWidget(
                          targetValue: value,
                          suffix: suffix,
                        )
                      : Text(
                          textValue!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
