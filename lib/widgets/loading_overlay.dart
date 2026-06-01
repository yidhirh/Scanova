// widgets/loading_overlay.dart
//
// Overlay plein écran utilisé pendant l'OCR (CNI, Chifa, bilans).
// On bloque l'UI sans masquer le contexte : carte blanche centrée,
// spinner brand, message court.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LoadingOverlay extends StatelessWidget {
  final String message;
  const LoadingOverlay({super.key, this.message = 'Analyse OCR en cours…'});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x730F172A),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadii.xl),
              boxShadow: AppShadows.pop,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 36, height: 36,
                  child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.brand600),
                ),
                const SizedBox(height: 12),
                Text(message, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
