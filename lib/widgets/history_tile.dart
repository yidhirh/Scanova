// lib/widgets/history_tile.dart
//
// HistoryTile — ligne d'historique réutilisable (Home + écran historique).
//
// Affiche une [HistoryEntry] : icône colorée selon le type, titre, nom du
// patient et libellé temporel relatif (« il y a 4 min »). Le mapping
// type → (icône, couleur) reste cohérent avec PatientDossierScreen et
// l'ancienne Home.

import 'package:flutter/material.dart';

import '../models/history_entry.dart';

/// Mapping type → (icône, couleur). Exposé en dehors du widget pour pouvoir
/// être réutilisé (ex. avatar dans un autre contexte).
({IconData icon, Color color}) historyStyle(String styleKey) {
  switch (styleKey) {
    case 'cni':
      return (icon: Icons.credit_card, color: const Color(0xFF2563EB));
    case 'chifa':
      return (icon: Icons.health_and_safety_outlined, color: const Color(0xFF16A34A));
    case 'bilan':
    case 'analyse':
      return (icon: Icons.science_outlined, color: const Color(0xFF16A34A));
    case 'ordonnance':
      return (icon: Icons.medical_services_outlined, color: const Color(0xFF2563EB));
    case 'radio':
    case 'radiographie':
      return (icon: Icons.image_outlined, color: const Color(0xFF9333EA));
    case 'compte rendu':
    case 'compte_rendu':
      return (icon: Icons.description_outlined, color: const Color(0xFF334155));
    default:
      return (icon: Icons.description_outlined, color: const Color(0xFF64748B));
  }
}

/// Libellé temporel relatif en français à partir d'un horodatage.
/// Renvoie « à l'instant », « il y a N min », « il y a N h », « hier »,
/// « il y a N j », puis une date courte (JJ/MM/AAAA) au-delà de ~30 jours.
String formatRelativeTime(DateTime? ts) {
  if (ts == null) return '—';
  final diff = DateTime.now().difference(ts);
  if (diff.isNegative || diff.inSeconds < 60) return "à l'instant";
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays == 1) return 'hier';
  if (diff.inDays < 30) return 'il y a ${diff.inDays} j';
  final d = ts;
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class HistoryTile extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback onTap;

  const HistoryTile({super.key, required this.entry, required this.onTap});

  static const Color _ink900 = Color(0xFF0F172A);
  static const Color _ink500 = Color(0xFF64748B);
  static const Color _ink400 = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    final s = historyStyle(entry.styleKey);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: s.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(s.icon, color: s.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _ink900,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${entry.patientFullName} · ${formatRelativeTime(entry.timestamp)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: _ink500),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _ink400, size: 20),
          ],
        ),
      ),
    );
  }
}
