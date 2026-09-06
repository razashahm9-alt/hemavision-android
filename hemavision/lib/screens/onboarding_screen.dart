import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_colors.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final bool showLoginFirst;

  const OnboardingScreen({super.key, this.showLoginFirst = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _controller = PageController();
  late final AnimationController _anim;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  int _index = 0;

  final _slides = const [
    (
      Icons.upload_file_rounded,
      'Upload Your CBC Report',
      'Scan or enter your blood count values manually',
    ),
    (
      Icons.psychology_alt_rounded,
      'Screening Support',
      'Prototype model and rule-based outputs for research review',
    ),
    (
      Icons.fact_check_rounded,
      'Get Detailed Results',
      'Download your report and consult your doctor',
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.showLoginFirst) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        ),
      );
    }
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _slide = Tween(
      begin: const Offset(.18, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _done(Widget page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: _index < 2
                    ? TextButton(
                        onPressed: () => _done(const RegisterScreen()),
                        child: const Text('Skip'),
                      )
                    : const SizedBox(height: 48),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (i) => setState(() {
                    _index = i;
                    _anim.forward(from: 0);
                  }),
                  itemCount: _slides.length,
                  itemBuilder: (_, i) {
                    final slide = _slides[i];
                    return FadeTransition(
                      opacity: _fade,
                      child: SlideTransition(
                        position: _slide,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 210,
                              height: 210,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primaryTeal.withOpacity(.35),
                                    AppColors.accentRed.withOpacity(.16),
                                  ],
                                ),
                              ),
                              child: Icon(
                                slide.$1,
                                size: 96,
                                color: AppColors.primaryLight,
                              ),
                            ),
                            const SizedBox(height: 40),
                            Text(
                              slide.$2,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              slide.$3,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.all(4),
                    width: _index == i ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _index == i
                          ? AppColors.primaryLight
                          : AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: () => _index == 2
                    ? _done(const RegisterScreen())
                    : _controller.nextPage(
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutCubic,
                      ),
                child: Text(_index == 2 ? 'Get Started' : 'Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
