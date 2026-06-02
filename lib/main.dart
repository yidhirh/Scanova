import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'database/database_helper.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;

  // Écran de démarrage :
  //   - session active (« rester connecté ») → on entre directement dans l'app ;
  //   - aucun compte (premier lancement)     → écran d'inscription ;
  //   - sinon                                 → écran de connexion.
  final auth = AuthService.instance;
  final Widget home;
  if (await auth.tryRestoreSession()) {
    home = const MainNavigationScreen();
  } else if (await auth.hasAnyUser()) {
    home = const LoginScreen();
  } else {
    home = const SignupScreen();
  }

  runApp(ScanovaApp(home: home));
}

class ScanovaApp extends StatelessWidget {
  final Widget home;
  const ScanovaApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scanova',
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: home,
    );
  }
}
