import 'package:flutter/material.dart';

/// Logo Scanova affiché sur les écrans d'authentification (login/signup).
/// Charge l'image `assets/images/scanova_logo.png` dans une pastille blanche
/// arrondie avec une légère ombre bleue.
class ScanovaLogo extends StatelessWidget {
  /// Taille du logo (côté de la pastille). 58 par défaut (taille historique).
  final double size;

  const ScanovaLogo({super.key, this.size = 58});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Image.asset(
          'assets/images/scanova_logo.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
