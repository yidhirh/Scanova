// lib/screens/main_navigation_screen.dart
//
// Shell de navigation principal de Scanova — 3 onglets via une
// NavigationBar Material 3 :
//   0. Accueil  → HomeScreen (tableau de bord)
//   1. Scanner  → DocumentTypeSelectionScreen (choix CNI / Chifa — identique
//                 à l'action « Nouvelle numérisation » de l'Accueil)
//   2. Patients → PatientListScreen (liste des dossiers)
//
// Les onglets sont conservés vivants par un IndexedStack. Un MainNavScope
// est exposé au-dessus de la pile pour que le Drawer partagé (accès
// secondaire) puisse basculer d'onglet depuis n'importe quel écran.
//
// Les flux Navigator.push existants (scan, dossier, formulaire…) continuent
// de fonctionner : ils s'empilent par-dessus ce shell sans le modifier.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/main_nav_scope.dart';
import 'document_type_selection_screen.dart';
import 'home_screen.dart';
import 'patient_list_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _index = 0;

  void _goToTab(int i) {
    if (i == _index) return;
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MainNavScope(
        currentIndex: _index,
        goToTab: _goToTab,
        child: IndexedStack(
          index: _index,
          children: const [
            HomeScreen(),
            DocumentTypeSelectionScreen(),
            PatientListScreen(),
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.ink200)),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: AppColors.white,
              indicatorColor: AppColors.brand100,
              surfaceTintColor: Colors.transparent,
              labelTextStyle: WidgetStateProperty.resolveWith(
                (states) => TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: states.contains(WidgetState.selected)
                      ? AppColors.brand700
                      : AppColors.ink500,
                ),
              ),
              iconTheme: WidgetStateProperty.resolveWith(
                (states) => IconThemeData(
                  size: 24,
                  color: states.contains(WidgetState.selected)
                      ? AppColors.brand700
                      : AppColors.ink500,
                ),
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _goToTab,
            height: 64,
            elevation: 0,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Accueil',
              ),
              NavigationDestination(
                icon: Icon(Icons.document_scanner_outlined),
                selectedIcon: Icon(Icons.document_scanner),
                label: 'Scanner',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: 'Patients',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
