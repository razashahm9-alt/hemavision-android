import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_colors.dart';
import '../firebase_options.dart';
import '../utils/demo_session.dart';
import 'dashboard_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _visible = false;
  bool _float = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(
      const Duration(milliseconds: 150),
      () => mounted ? setState(() => _visible = true) : null,
    );
    Future.delayed(
      const Duration(milliseconds: 550),
      () => mounted ? setState(() => _float = true) : null,
    );
    Future.delayed(const Duration(seconds: 3), _route);
  }

  Future<void> _route() async {
    final prefs = await SharedPreferences.getInstance();
    final firstSeen = prefs.getBool('onboarding_seen') ?? false;
    final loggedIn = DefaultFirebaseOptions.isDemoConfig
        ? await DemoSession.isLoggedIn
        : FirebaseAuth.instance.currentUser != null;
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      _fadeRoute(
        loggedIn
            ? const DashboardScreen()
            : OnboardingScreen(showLoginFirst: firstSeen),
      ),
    );
  }

  PageRouteBuilder _fadeRoute(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            for (final item in [
              (26.0, 42.0, 90.0),
              (280.0, 90.0, 130.0),
              (44.0, 520.0, 160.0),
              (300.0, 640.0, 86.0),
            ])
              AnimatedPositioned(
                duration: const Duration(seconds: 3),
                curve: Curves.easeInOut,
                left: _float ? item.$1 + 18 : item.$1,
                top: _float ? item.$2 - 24 : item.$2,
                child: AnimatedContainer(
                  duration: const Duration(seconds: 3),
                  width: item.$3,
                  height: item.$3,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryLight.withOpacity(.07),
                  ),
                ),
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: .5, end: 1),
                    duration: const Duration(milliseconds: 1500),
                    curve: Curves.elasticOut,
                    builder: (_, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: AnimatedOpacity(
                      opacity: _visible ? 1 : 0,
                      duration: const Duration(milliseconds: 1500),
                      child: Column(
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accentRed.withOpacity(.18),
                              border: Border.all(color: AppColors.accentSoft),
                            ),
                            child: const Icon(
                              Icons.bloodtype_rounded,
                              size: 54,
                              color: AppColors.accentSoft,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'HemaVision',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: _visible ? 1 : 0,
                    duration: const Duration(milliseconds: 900),
                    curve: const Interval(.35, 1),
                    child: const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Detect. Classify. Save Lives.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
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
