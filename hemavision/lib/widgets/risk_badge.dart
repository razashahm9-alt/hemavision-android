import 'package:flutter/material.dart';

import '../app_colors.dart';

class RiskBadgeWidget extends StatefulWidget {
  final String riskLevel;

  const RiskBadgeWidget({super.key, required this.riskLevel});

  @override
  State<RiskBadgeWidget> createState() => _RiskBadgeWidgetState();
}

class _RiskBadgeWidgetState extends State<RiskBadgeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  Color get _color {
    switch (widget.riskLevel) {
      case 'High':
        return AppColors.accentRed;
      case 'Medium':
        return AppColors.warningYellow;
      default:
        return AppColors.successGreen;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: 1.05), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.riskLevel == 'High') _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant RiskBadgeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.riskLevel == 'High' && !_controller.isAnimating)
      _controller.repeat();
    if (widget.riskLevel != 'High') _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _color.withOpacity(.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _color.withOpacity(.7)),
        ),
        child: Text(
          widget.riskLevel,
          style: TextStyle(
            color: _color,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
