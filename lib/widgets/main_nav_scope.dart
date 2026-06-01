// lib/widgets/main_nav_scope.dart
//
// Petit InheritedWidget exposé par MainNavigationScreen pour permettre
// à n'importe quel écran d'onglet (ou au Drawer partagé) de connaître
// l'onglet courant et de basculer entre les onglets de la
// BottomNavigationBar sans passer de callbacks par les constructeurs.

import 'package:flutter/material.dart';

class MainNavScope extends InheritedWidget {
  /// Index de l'onglet actif (0 = Accueil, 1 = Scanner, 2 = Patients).
  final int currentIndex;

  /// Bascule la BottomNavigationBar sur l'onglet [index].
  final void Function(int index) goToTab;

  const MainNavScope({
    super.key,
    required this.currentIndex,
    required this.goToTab,
    required super.child,
  });

  static MainNavScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MainNavScope>();

  static MainNavScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'MainNavScope introuvable dans le contexte.');
    return scope!;
  }

  @override
  bool updateShouldNotify(MainNavScope oldWidget) =>
      currentIndex != oldWidget.currentIndex;
}
