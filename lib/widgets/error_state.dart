// widgets/error_state.dart
//
// Vue d'erreur : utilisée quand le chargement initial échoue
// (ex: dossier patient impossible à charger).

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64, height: 64,
            decoration: const BoxDecoration(
              color: AppColors.danger100, shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.danger600, size: 32),
          ),
          const SizedBox(height: 14),
          Text(
            'Une erreur est survenue',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink900),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.ink500, height: 1.45),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 18),
            AppButton(
              label: 'Réessayer',
              icon: Icons.refresh,
              variant: AppButtonVariant.outline,
              onPressed: onRetry,
              fullWidth: false,
            ),
          ],
        ],
      ),
    );
  }
}
