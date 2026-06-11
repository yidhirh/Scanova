import 'dart:io';

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/document_page.dart';
import '../models/medical_document.dart';
import '../models/ordonnance_numerique.dart';
import '../services/audit_service.dart';
import '../services/auth_service.dart';
import '../services/document_print_service.dart';
import 'fullscreen_image_viewer.dart';

/// Visionneuse d'un document médical générique (ordonnance, radio, compte
/// rendu, autre). Style aligné sur [BilanViewerScreen] : fond clair, AppBar
/// bleue, grandes cartes blanches arrondies, aperçu page par page dans une
/// carte (tap → plein écran), texte OCR de la page courante dans une carte.
///
/// Différences métier conservées : type de document, date du document, texte
/// OCR par page. Menu "3 points" : Imprimer / Supprimer.
class DocumentViewerScreen extends StatefulWidget {
  final MedicalDocument document;

  const DocumentViewerScreen({super.key, required this.document});

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  static const Color _primary = Color(0xFF2563EB);
  static const Color _background = Color(0xFFF8FAFC);

  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  MedicalDocument get doc => widget.document;

  /// Ordonnance saisie dans l'app (aucune image) : l'aperçu des pages est
  /// masqué et `description` contient le contenu structuré de l'ordonnance.
  bool get _isOrdonnanceNumerique =>
      doc.typeDocument == OrdonnanceNumerique.typeDocument;

  // ── Helpers présentation ──────────────────────────────────────────────────

  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '—';
    final parts = isoDate.split('-');
    if (parts.length != 3) return isoDate;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  /// Libellé lisible du type ('ordonnance_numerique' → 'Ordonnance numerique').
  String _typeLabel(String type) => _capitalize(type.replaceAll('_', ' '));

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'ordonnance':
        return Icons.medical_services_outlined;
      case 'ordonnance_numerique':
        return Icons.edit_note;
      case 'bilan':
      case 'analyse':
        return Icons.science_outlined;
      case 'radio':
      case 'radiographie':
        return Icons.image_outlined;
      case 'compte rendu':
      case 'compte_rendu':
        return Icons.description_outlined;
      default:
        return Icons.folder_outlined;
    }
  }

  Color _colorForType(String type) {
    switch (type.toLowerCase()) {
      case 'ordonnance':
      case 'ordonnance_numerique':
        return Colors.blue;
      case 'bilan':
      case 'analyse':
        return Colors.green;
      case 'radio':
      case 'radiographie':
        return Colors.purple;
      default:
        return Colors.orange;
    }
  }

  // ── Actions (menu 3 points) ───────────────────────────────────────────────

  Future<void> _print() async {
    final pages = doc.pages ?? const <DocumentPage>[];
    final printPages = pages
        .map((p) => PrintPage(number: p.pageNumber, imagePath: p.filePath, ocrText: p.ocrText))
        .toList();

    try {
      await DocumentPrintService.printDocument(
        title: doc.titre,
        metaLines: [
          'Type : ${_typeLabel(doc.typeDocument)}',
          'Date du document : ${_formatDate(doc.documentDate)}',
        ],
        pages: printPages,
        // Document sans page (ordonnance numérique) : le contenu vit dans
        // `description`, on l'imprime comme corps de texte.
        bodyText: printPages.isEmpty ? doc.description : null,
      );
      await AuditService.instance.logExport(
        entityType: 'document',
        entityId: doc.id,
        patientId: doc.patientId,
        description: 'Export du document « ${doc.titre} » (${_typeLabel(doc.typeDocument)})',
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

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce document ?'),
        content: const Text(
          'Voulez-vous vraiment supprimer ce document ? '
          'Cette action est irréversible.',
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
    if (ok != true || doc.id == null) return;

    await DatabaseHelper.instance.deleteMedicalDocument(doc.id!);
    await AuditService.instance.logSuppression(
      entityType: 'document',
      entityId: doc.id,
      patientId: doc.patientId,
      description: 'Suppression du document « ${doc.titre} » (${_typeLabel(doc.typeDocument)})',
    );
    if (mounted) Navigator.pop(context, true);
  }

  void _openFullscreen() {
    final pages = doc.pages ?? const <DocumentPage>[];
    if (pages.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenImageViewer(
          imagePaths: pages.map((p) => p.filePath).toList(),
          initialIndex: _currentPage,
          title: doc.titre,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pages = doc.pages ?? const <DocumentPage>[];
    final typeColor = _colorForType(doc.typeDocument);

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: Text(
          doc.titre,
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [_buildMenu()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard(typeColor),
          const SizedBox(height: 16),
          // Ordonnance numérique : aucune image par construction → on masque
          // l'aperçu des pages (sinon « Aucune image disponible » serait
          // affiché à tort comme une anomalie).
          if (!(_isOrdonnanceNumerique && pages.isEmpty)) ...[
            _buildPagesSection(pages),
            const SizedBox(height: 16),
          ],
          _buildPageText(pages),
        ],
      ),
    );
  }

  Widget _buildMenu() {
    final auth = AuthService.instance;
    final canExport = auth.canExportRecords;
    final canDelete = auth.canDeleteRecords;
    // Archiviste : aucune action sensible → on masque le menu entièrement.
    if (!canExport && !canDelete) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        if (value == 'print') _print();
        if (value == 'delete') _confirmDelete();
      },
      itemBuilder: (_) => [
        if (canExport)
          const PopupMenuItem(
            value: 'print',
            child: ListTile(
              leading: Icon(Icons.print_outlined),
              title: Text('Imprimer'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (canDelete)
          const PopupMenuItem(
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

  // ── Carte d'en-tête (infos métier) ────────────────────────────────────────

  Widget _buildHeaderCard(Color typeColor) {
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconForType(doc.typeDocument), color: typeColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.titre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _typeLabel(doc.typeDocument),
                      style: TextStyle(color: typeColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow(Icons.calendar_today_outlined, 'Date du document', _formatDate(doc.documentDate)),
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

  // ── Aperçu des pages (image par page, tap → plein écran) ──────────────────

  Widget _buildPagesSection(List<DocumentPage> pages) {
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

    return ClipRRect(
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
            // Indice "plein écran" pour signaler l'interaction.
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
            color: active ? Colors.white : Colors.white54,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  // ── Texte OCR de la page courante (jamais le bloc global) ─────────────────

  Widget _buildPageText(List<DocumentPage> pages) {
    final hasPageText = _currentPage < pages.length &&
        (pages[_currentPage].ocrText?.isNotEmpty ?? false);

    // Repli sur `description` (concaténé) pour les documents mono-page créés
    // avant le stockage du texte par page.
    final String text = hasPageText
        ? pages[_currentPage].ocrText!.trim()
        : ((pages.length <= 1 ? doc.description : null)?.trim() ?? '');

    final multi = pages.length > 1;
    final label = _isOrdonnanceNumerique
        ? 'Contenu de l\'ordonnance'
        : (multi ? 'Texte extrait (page ${_currentPage + 1})' : 'Texte extrait (OCR)');

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
            constraints: const BoxConstraints(maxHeight: 280),
            child: SingleChildScrollView(
              child: Text(
                text.isEmpty
                    ? (multi
                        ? 'Aucun texte extrait pour la page ${_currentPage + 1}.'
                        : 'Aucun texte extrait.')
                    : text,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: text.isEmpty ? Colors.grey[400] : const Color(0xFF374151),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
