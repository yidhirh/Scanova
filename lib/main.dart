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
  /// Écran racine. En production il reste `null` → on affiche le [SplashScreen]
  /// (qui initialise la base et restaure la session). Il sert de point
  /// d'injection pour les tests : passer un widget léger évite de déclencher
  /// l'init sqflite / les animations du splash dans l'environnement de test.
  final Widget? home;

  const ScanovaApp({super.key, this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scanova',
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: home ?? const SplashScreen(),
    );
  }
}
