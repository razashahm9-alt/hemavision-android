import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );
  runApp(const HemaVisionApp());
}

class HemaVisionApp extends StatelessWidget {
  const HemaVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppThemeController.current,
      builder: (_, themeName, __) => MaterialApp(
        title: 'HemaVision',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(themeName),
        home: const SplashScreen(),
      ),
    );
  }
}
