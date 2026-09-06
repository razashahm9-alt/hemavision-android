import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_colors.dart';

class CancerCardWidget extends StatefulWidget {
  final String type;
  final String fullName;
  final String description;
  final Color color;

  const CancerCardWidget({
    super.key,
    required this.type,
    required this.fullName,
    required this.description,
    required this.color,
  });

  @override
  State<CancerCardWidget> createState() => _CancerCardWidgetState();
}

class _CancerCardWidgetState extends State<CancerCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _controller.isCompleted
          ? _controller.reverse()
          : _controller.forward(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          final angle = _controller.value * math.pi;
          final back = angle > math.pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .001)
              ..rotateY(angle),
            child: Card(
              color: AppColors.bgCard,
              child: Container(
                width: 170,
                height: 150,
                padding: const EdgeInsets.all(16),
                child: back
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(math.pi),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.fullName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Text(
                                widget.description,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.biotech_rounded,
                            color: widget.color,
                            size: 34,
                          ),
                          const Spacer(),
                          Text(
                            widget.type,
                            style: TextStyle(
                              color: widget.color,
                              fontWeight: FontWeight.w900,
                              fontSize: 26,
                            ),
                          ),
                          Text(
                            'Tap for details',
                            style: TextStyle(
                              color: widget.color.withOpacity(.75),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}
