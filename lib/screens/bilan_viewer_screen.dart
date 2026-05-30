import 'dart:io';

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/bilan.dart';
import '../models/bilan_page.dart';
import '../models/valeur_biologique.dart';
import '../services/document_print_service.dart';
import 'fullscreen_image_viewer.dart';

/// Étape 7 du BILAN_PARSER_BRIEF : visionneuse d'un bilan structuré.
///
/// Affiche les métadonnées du bilan (date, labo, médecin, n°), les pages
/// scannées **page par page** (image + texte OCR de la page courante via un
/// PageView) et la liste des valeurs **groupées par catégorie**, avec mise en
/// évidence rouge des valeurs hors-norme.
///
/// Choix produit : les valeurs ne sont PAS rattachées à une page (le parser
/// concatène volontairement car une catégorie peut s'étaler sur 2 pages) — elles
/// restent donc affichées une seule fois, groupées par catégorie, sous l'aperçu.
///
/// Le [Bilan] passé doit être **hydraté** (valeurs et pages chargées),
/// typiquement obtenu via [DatabaseHelper.getBilanById].
class BilanViewerScreen extends StatefulWidget {
  final Bilan bilan;

  const BilanViewerScreen({super.key, required this.bilan});

  @override
  State<BilanViewerScreen> createState() => _BilanViewerScreenState();
}

class _BilanViewerScreenState extends State<BilanViewerScreen> {
  static const Color _primary = Color(0xFF2563EB);
  static const Color _background = Color(0xFFF8FAFC);

  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Bilan get bilan => widget.bilan;

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

  // ── Menu 3 points (Imprimer / Supprimer) ──────────────────────────────────

  Widget _buildMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        if (value == 'print') _print();
        if (value == 'delete') _confirmDelete(context);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'print',
          child: ListTile(
            leading: Icon(Icons.print_outlined),
            title: Text('Imprimer'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.red),
            title: Text('Supprimer', style: TextStyle(color: Colors.red)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Future<void> _print() async {
    final pages = bilan.pages ?? const <BilanPage>[];
    final printPages = pages
        .map((p) => PrintPage(number: p.pageNumber, imagePath: p.filePath, ocrText: p.ocrText))
        .toList();

    final meta = <String>[
      'Prélevé le : ${_formatDate(bilan.dateExamen)}',
      if (bilan.laboratoire != null && bilan.laboratoire!.isNotEmpty)
        'Laboratoire : ${bilan.laboratoire}',
      if (bilan.medecinPrescripteur != null && bilan.medecinPrescripteur!.isNotEmpty)
        'Médecin : ${bilan.medecinPrescripteur}',
      if (bilan.numeroDossier != null && bilan.numeroDossier!.isNotEmpty)
        'Dossier : ${bilan.numeroDossier}',
    ];

    try {
      await DocumentPrintService.printDocument(
        title: 'Bilan biologique',
        metaLines: meta,
        pages: printPages,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impression impossible : $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openFullscreen() {
    final pages = bilan.pages ?? const <BilanPage>[];
    if (pages.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenImageViewer(
          imagePaths: pages.map((p) => p.filePath).toList(),
          initialIndex: _currentPage,
          title: 'Bilan biologique',
        ),
      ),
    );
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
    final pages = bilan.pages ?? const <BilanPage>[];
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
        actions: [_buildMenu()],
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
          _buildPagesSection(pages),
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

  // ── Aperçu des pages (image + texte OCR par page) ─────────────────────────

  Widget _buildPagesSection(List<BilanPage> pages) {
    if (pages.isEmpty) {
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

    final pageCount = pages.length;
    final current = pages[_currentPage];
    final String pageText = current.ocrText?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 260,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: pageCount,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (context, index) {
                    final f = File(pages[index].filePath);
                    return GestureDetector(
                      onTap: _openFullscreen,
                      child: Container(
                        color: Colors.black12,
                        child: f.existsSync()
                            ? Image.file(f, fit: BoxFit.contain, width: double.infinity)
                            : Center(
                                child: Text(
                                  'Fichier introuvable',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ),
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.fullscreen, color: Colors.white, size: 18),
                  ),
                ),
                if (pageCount > 1)
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
                        '${_currentPage + 1} / $pageCount',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                if (pageCount > 1)
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: _buildPageDots(pageCount),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildPageText(pageCount, pageText),
      ],
    );
  }

  Widget _buildPageDots(int pageCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (i) {
        final active = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? _primary : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  /// Texte OCR de la page COURANTE (suit le PageView), jamais le bloc global.
  Widget _buildPageText(int pageCount, String pageText) {
    final label = pageCount > 1
        ? 'Texte extrait (page ${_currentPage + 1})'
        : 'Texte extrait (OCR)';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.text_snippet_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: Text(
                pageText.isEmpty
                    ? 'Aucun texte extrait pour cette page.'
                    : pageText,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: pageText.isEmpty ? Colors.grey[400] : const Color(0xFF374151),
                ),
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
