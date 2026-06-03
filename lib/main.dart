import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // L'initialisation (base de données, restauration de session) est réalisée
  // par SplashScreen pendant que l'animation de démarrage se joue.
  runApp(const ScanovaApp());
}

class ScanovaApp extends StatelessWidget {
  const ScanovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scanova',
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}
