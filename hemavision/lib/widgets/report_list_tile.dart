import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/analysis_result.dart';
import '../utils/result_display.dart';
import 'risk_badge.dart';

class ReportListTileWidget extends StatelessWidget {
  final AnalysisResult result;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const ReportListTileWidget({
    super.key,
    required this.result,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = result.riskLevel == 'High'
        ? AppColors.accentRed
        : result.riskLevel == 'Medium'
        ? AppColors.warningYellow
        : AppColors.successGreen;

    final initials =
        result.cancerType == 'None' || result.cancerType == 'Normal'
        ? 'N'
        : result.cancerType.length <= 3
        ? result.cancerType
        : result.cancerType.substring(0, 1);

    return Card(
      color: AppColors.bgCard,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 4,
              height: 86,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.18),
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                title: Text(
                  result.primaryDisplayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${result.analyzedAt.toLocal().toString().split('.').first} - '
                  '${ResultDisplay.stageLine(result)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RiskBadgeWidget(riskLevel: result.riskLevel),
                    const SizedBox(width: 8),
                    Text(
                      '${result.confidenceScore.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (onDelete != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Delete report',
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.accentSoft,
                        ),
                        onPressed: onDelete,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
