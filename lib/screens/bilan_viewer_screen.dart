import 'dart:io';

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/bilan.dart';
import '../models/valeur_biologique.dart';

/// Étape 7 du BILAN_PARSER_BRIEF : visionneuse d'un bilan structuré.
///
/// Affiche les métadonnées du bilan (date, labo, médecin, n°), la 1re page
/// scannée (stage A multi-page) et la liste des valeurs **groupées par
/// catégorie**, avec mise en évidence rouge des valeurs hors-norme.
///
/// Le [Bilan] passé doit être **hydraté** (valeurs et pages chargées),
/// typiquement obtenu via [DatabaseHelper.getBilanById].
class BilanViewerScreen extends StatelessWidget {
  final Bilan bilan;

  const BilanViewerScreen({super.key, required this.bilan});

  static const Color _primary = Color(0xFF2563EB);
  static const Color _background = Color(0xFFF8FAFC);

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce bilan ?'),
        content: const Text(
          'Cette action supprimera le bilan, toutes ses valeurs '
          'et toutes ses pages scannées. Elle est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (bilan.id == null) return;

    await DatabaseHelper.instance.deleteBilan(bilan.id!);
    if (context.mounted) Navigator.pop(context, true);
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  /// Groupe les valeurs par catégorie en préservant l'ordre d'apparition.
  /// Les valeurs sans catégorie sont regroupées sous "Autres".
  Map<String, List<ValeurBiologique>> _groupByCategorie(
    List<ValeurBiologique> valeurs,
  ) {
    final groupes = <String, List<ValeurBiologique>>{};
    for (final v in valeurs) {
      final cat = v.categorie ?? 'Autres';
      groupes.putIfAbsent(cat, () => []).add(v);
    }
    return groupes;
  }

  @override
  Widget build(BuildContext context) {
    final valeurs = bilan.valeurs ?? const <ValeurBiologique>[];
    final groupes = _groupByCategorie(valeurs);
    final pages = bilan.pages ?? const [];
    final firstPage = pages.isNotEmpty ? File(pages.first.filePath) : null;
    final imageExists = firstPage != null && firstPage.existsSync();
    final horsNormeCount = valeurs.where((v) => v.estHorsNorme).length;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          'Bilan biologique',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Supprimer',
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard(),
          if (horsNormeCount > 0) ...[
            const SizedBox(height: 12),
            _buildHorsNormeBanner(horsNormeCount),
          ],
          const SizedBox(height: 16),
          _buildImagePreview(imageExists ? firstPage : null, pages.length),
          const SizedBox(height: 20),
          if (valeurs.isEmpty)
            _buildEmptyHint('Aucune valeur enregistrée pour ce bilan.')
          else
            ...groupes.entries.map((e) => _buildCategorieSection(e.key, e.value)),
        ],
      ),
    );
  }

  // ── Header (métadonnées) ──────────────────────────────────────────────────

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(Icons.calendar_today_outlined, 'Prélevé le', _formatDate(bilan.dateExamen)),
          if (bilan.laboratoire != null && bilan.laboratoire!.isNotEmpty)
            _infoRow(Icons.business_outlined, 'Laboratoire', bilan.laboratoire!),
          if (bilan.medecinPrescripteur != null && bilan.medecinPrescripteur!.isNotEmpty)
            _infoRow(Icons.person_outline, 'Médecin', bilan.medecinPrescripteur!),
          if (bilan.numeroDossier != null && bilan.numeroDossier!.isNotEmpty)
            _infoRow(Icons.tag, 'Dossier', bilan.numeroDossier!),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _primary),
          const SizedBox(width: 10),
          Text(
            '$label : ',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bandeau hors-norme ────────────────────────────────────────────────────

  Widget _buildHorsNormeBanner(int count) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count valeur${count > 1 ? 's' : ''} hors norme',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Aperçu image ──────────────────────────────────────────────────────────

  Widget _buildImagePreview(File? file, int totalPages) {
    if (file == null) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            'Aucune image disponible',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          Image.file(file, fit: BoxFit.cover, width: double.infinity, height: 220),
          if (totalPages > 1)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '1 / $totalPages',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Liste des valeurs par catégorie ───────────────────────────────────────

  Widget _buildCategorieSection(String categorie, List<ValeurBiologique> valeurs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 4),
            child: Text(
              categorie,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                for (var i = 0; i < valeurs.length; i++) ...[
                  _ValeurRow(valeur: valeurs[i]),
                  if (i < valeurs.length - 1)
                    Divider(height: 1, color: Colors.grey.shade200),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHint(String message) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey[500], fontSize: 14),
      ),
    );
  }
}

/// Une ligne de valeur biologique (lecture seule). Rouge si hors-norme.
class _ValeurRow extends StatelessWidget {
  final ValeurBiologique valeur;

  const _ValeurRow({required this.valeur});

  String _valeurDisplay() {
    final v = valeur.valeurNumerique?.toString() ?? valeur.valeurTexte ?? '—';
    final u = valeur.unite ?? '';
    return u.isEmpty ? v : '$v $u';
  }

  String? _normeDisplay() {
    if (valeur.normeMin != null && valeur.normeMax != null) {
      return '${valeur.normeMin} – ${valeur.normeMax}';
    }
    if (valeur.normeMax != null) return '< ${valeur.normeMax}';
    if (valeur.normeMin != null) return '> ${valeur.normeMin}';
    return valeur.normeTexte;
  }

  @override
  Widget build(BuildContext context) {
    final horsNorme = valeur.estHorsNorme;
    final norme = _normeDisplay();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valeur.nom,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (norme != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Norme : $norme',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (horsNorme)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.warning_amber_rounded,
                        size: 16, color: Colors.red),
                  ),
                Flexible(
                  child: Text(
                    _valeurDisplay(),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: horsNorme ? Colors.red : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
