import 'package:flutter/material.dart';

import '../app_colors.dart';

class CustomAppBarWidget extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final bool showBack;
  final List<Widget> actions;

  const CustomAppBarWidget({
    super.key,
    required this.title,
    this.showBack = false,
    this.actions = const [],
  });

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: showBack
          ? BackButton(onPressed: () => Navigator.pop(context))
          : Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
      title: Text(title),
      actions: actions,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.bgDark, AppColors.primaryTeal],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: Container(
          height: 2,
          color: AppColors.primaryLight.withOpacity(.55),
        ),
      ),
    );
  }
}
