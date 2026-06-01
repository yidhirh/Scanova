// widgets/app_text_field.dart
//
// Champ de formulaire stylé Scanova : label au-dessus, icône préfixe,
// indicateur "à vérifier" en suffixe quand un champ provient de l'OCR
// avec un faible niveau de confiance.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData? prefixIcon;
  final Widget? suffix;
  final String? hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool needsVerification; // déclenche bordure ambre + icône warning
  final bool obscureText;
  final TextDirection? textDirection;

  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.prefixIcon,
    this.suffix,
    this.hint,
    this.keyboardType,
    this.validator,
    this.needsVerification = false,
    this.obscureText = false,
    this.textDirection,
  });

  @override
  Widget build(BuildContext context) {
    final amber = AppColors.warning500;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink900)),
            if (needsVerification) ...[
              const SizedBox(width: 6),
              Text('· à vérifier', style: TextStyle(fontSize: 13, color: amber, fontWeight: FontWeight.w500)),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          obscureText: obscureText,
          textDirection: textDirection,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
            suffixIcon: needsVerification
                ? Icon(Icons.warning_amber_rounded, color: amber)
                : suffix,
            enabledBorder: needsVerification
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    borderSide: BorderSide(color: amber),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
