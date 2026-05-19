import 'package:flutter/material.dart';

import '../models/document_type.dart';
import 'cni_scan_screen.dart';

class DocumentTypeSelectionScreen extends StatelessWidget {
  const DocumentTypeSelectionScreen({super.key});

  void _openScanner(BuildContext context, DocumentType type) {
    if (type == DocumentType.cni) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const CniScanScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner une carte'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Choisissez le type de document. Pour la CNI, Scanova prend le recto et le verso avant de lancer le traitement.',
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

            Card(
              elevation: 1,
              color: Colors.grey.shade100,
              child: const ListTile(
                leading: Icon(
                  Icons.health_and_safety_outlined,
                  size: 36,
                  color: Colors.grey,
                ),
                title: Text(
                  'Carte Chifa',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Indisponible pour le moment. Le scanner Chifa sera ajouté plus tard.',
                ),
                trailing: Icon(Icons.lock_outline, size: 20),
              ),
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
        leading: Icon(
          icon,
          size: 36,
          color: const Color(0xFF2563EB),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
        onTap: onTap,
      ),
    );
  }
}