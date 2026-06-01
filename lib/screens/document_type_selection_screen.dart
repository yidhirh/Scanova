import 'package:flutter/material.dart';

import '../models/document_type.dart';
import '../widgets/app_drawer.dart';
import '../widgets/main_nav_scope.dart';
import 'chifa_scan_screen.dart';
import 'cni_scan_screen.dart';

class DocumentTypeSelectionScreen extends StatelessWidget {
  const DocumentTypeSelectionScreen({super.key});

  void _openScanner(BuildContext context, DocumentType type) {
    Widget screen;
    switch (type) {
      case DocumentType.cni:
        screen = const CniScanScreen();
        break;
      case DocumentType.chifa:
        screen = const ChifaScanScreen();
        break;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Affiché comme onglet « Scanner » → garde le menu hamburger comme les
      // autres onglets. Poussé depuis « Nouvelle numérisation » (Accueil) →
      // pas de MainNavScope dans le contexte, donc pas de drawer (bouton retour).
      drawer: MainNavScope.maybeOf(context) != null ? const AppDrawer() : null,
      appBar: AppBar(title: const Text('Scanner une carte')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Choisissez le type de document. Pour la CNI, Scanova prend le recto et le verso avant de lancer le traitement. Pour la Chifa, une seule photo suffit.',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 20),
            _DocumentTypeCard(
              title: DocumentType.cni.label,
              subtitle: DocumentType.cni.description,
              icon: Icons.credit_card,
              onTap: () => _openScanner(context, DocumentType.cni),
            ),
            const SizedBox(height: 12),
            _DocumentTypeCard(
              title: DocumentType.chifa.label,
              subtitle: DocumentType.chifa.description,
              icon: Icons.health_and_safety_outlined,
              onTap: () => _openScanner(context, DocumentType.chifa),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentTypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _DocumentTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, size: 36, color: const Color(0xFF2563EB)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
        onTap: onTap,
      ),
    );
  }
}