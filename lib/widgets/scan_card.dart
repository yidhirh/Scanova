// widgets/scan_card.dart
//
// Carte d'aperçu pour une face scannée (recto / verso de la CNI,
// face unique de la Chifa, etc). Header bleu + corps blanc avec
// l'image ou un placeholder.

import 'dart:io';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ScanCard extends StatelessWidget {
  final String title;
  final File? image;
  final IconData placeholderIcon;
  final double height;

  const ScanCard({
    super.key,
    required this.title,
    required this.image,
    this.placeholderIcon = Icons.credit_card,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          boxShadow: AppShadows.card,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: AppColors.brand600,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(
              child: image == null
                  ? Center(child: Icon(placeholderIcon, size: 56, color: AppColors.ink300))
                  : Stack(
                      children: [
                        Positioned.fill(child: Image.file(image!, fit: BoxFit.contain)),
                        const Positioned(
                          top: 10, right: 10,
                          child: _SuccessPin(),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessPin extends StatelessWidget {
  const _SuccessPin();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(color: AppColors.success600, shape: BoxShape.circle),
      child: const Icon(Icons.check, color: AppColors.white, size: 16),
    );
  }
}
