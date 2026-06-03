import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/scanova_logo.dart';
import 'login_screen.dart';
import 'main_navigation_screen.dart';
import 'signup_screen.dart';

/// Écran de démarrage animé (logo + nom Scanova).
///
/// Affiché immédiatement au lancement : l'animation se joue PENDANT
/// l'initialisation (ouverture de la base, restauration de session). Une fois
/// l'init terminée ET une durée minimale écoulée (pour que l'animation soit
/// visible), on enchaîne en fondu vers l'écran approprié :
///   - session active        → l'app (MainNavigationScreen) ;
///   - aucun compte           → inscription ;
///   - sinon                  → connexion.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _textFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    // Le logo apparaît en premier (fondu + léger zoom rebond), le nom suit.
    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );
    _textFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );
    _controller.forward();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Init en parallèle de l'animation : on démarre la résolution tout de
    // suite, puis on attend le plus long entre l'init et la durée minimale,
    // pour que le splash reste affiché au moins le temps de l'animation.
    final homeFuture = _resolveHome();
    await Future<void>.delayed(const Duration(milliseconds: 1900));
    final home = await homeFuture;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => home,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<Widget> _resolveHome() async {
    await DatabaseHelper.instance.database;
    final auth = AuthService.instance;
    if (await auth.tryRestoreSession()) return const MainNavigationScreen();
    if (await auth.hasAnyUser()) return const LoginScreen();
    return const SignupScreen();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF2FE), Colors.white],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeTransition(
              opacity: _logoFade,
              child: ScaleTransition(
                scale: _logoScale,
                child: const ScanovaLogo(size: 108),
              ),
            ),
            const SizedBox(height: 24),
            FadeTransition(
              opacity: _textFade,
              child: Column(
                children: [
                  const Text(
                    'Scanova',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppColors.brand700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Numérisation médicale',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.ink500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 44),
            // Indicateur discret pendant l'initialisation.
            FadeTransition(
              opacity: _textFade,
              child: const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation(AppColors.brand500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
