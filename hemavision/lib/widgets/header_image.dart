import 'package:flutter/material.dart';

import '../app_colors.dart';

class HeaderImageWidget extends StatelessWidget {
  final String imagePath;
  final double height;

  const HeaderImageWidget({
    super.key,
    required this.imagePath,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryTeal, AppColors.bgSurface],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryLight.withOpacity(.16),
              blurRadius: 20,
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imagePath,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.bloodtype,
                size: 80,
                color: AppColors.accentSoft,
              ),
            ),
            Container(color: Colors.black.withOpacity(.28)),
          ],
        ),
      ),
    );
  }
}
