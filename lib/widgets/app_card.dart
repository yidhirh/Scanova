// widgets/app_card.dart
//
// Carte blanche, coins arrondis, ombre douce. Wrapper minimal
// autour d'un Container pour garantir la cohérence partout.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum AppCardElevation { card, elev, pop }

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final AppCardElevation elevation;
  final VoidCallback? onTap;
  final Color? background;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppRadii.xl,
    this.elevation = AppCardElevation.card,
    this.onTap,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final shadows = switch (elevation) {
      AppCardElevation.card => AppShadows.card,
      AppCardElevation.elev => AppShadows.elev,
      AppCardElevation.pop  => AppShadows.pop,
    };

    final container = Container(
      decoration: BoxDecoration(
        color: background ?? AppColors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadows,
      ),
      padding: padding,
      child: child,
    );

    if (onTap == null) return container;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: container,
      ),
    );
  }
}
