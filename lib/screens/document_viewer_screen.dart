import 'dart:io';

import 'package:flutter/material.dart';

import '../models/medical_document.dart';

class DocumentViewerScreen extends StatefulWidget {
  final MedicalDocument document;

  const DocumentViewerScreen({super.key, required this.document});

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  bool _showInfo = true;

  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'ordonnance':
        return Icons.medical_services_outlined;
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

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    final pages = doc.pages ?? const [];
    final pageCount = pages.length;
    final typeColor = _colorForType(doc.typeDocument);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          doc.titre,
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Compteur de page n'affiché que pour les documents multi-page.
          if (pageCount > 1)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${_currentPage + 1} / $pageCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: Icon(_showInfo ? Icons.info : Icons.info_outline),
            tooltip: 'Informations',
            onPressed: () => setState(() => _showInfo = !_showInfo),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: pageCount == 0
                ? _buildError()
                : Stack(
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        itemCount: pageCount,
                        onPageChanged: (i) => setState(() => _currentPage = i),
                        itemBuilder: (context, index) {
                          final file = File(pages[index].filePath);
                          final exists = file.existsSync();
                          return GestureDetector(
                            onTap: () => setState(() => _showInfo = !_showInfo),
                            child: exists
                                ? InteractiveViewer(
                                    minScale: 0.5,
                                    maxScale: 5.0,
                                    child: Center(
                                      child: Image.file(
                                        file,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => _buildError(),
                                      ),
                                    ),
                                  )
                                : _buildError(),
                          );
                        },
                      ),
                      // Indicateurs de page (points), masqués si une seule page.
                      if (pageCount > 1)
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: _buildPageDots(pageCount),
                        ),
                    ],
                  ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _showInfo
                ? _buildInfoPanel(doc, typeColor)
                : const SizedBox.shrink(),
          ),
        ],
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
            color: active ? Colors.white : Colors.white38,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 12),
          Text(
            'Fichier introuvable',
            style: TextStyle(color: Colors.grey[500], fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel(MedicalDocument doc, Color typeColor) {
    return Container(
      key: const ValueKey('info'),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
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
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _capitalize(doc.typeDocument),
                      style: TextStyle(color: typeColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _infoRow(Icons.calendar_today_outlined, 'Date du document', _formatDate(doc.documentDate)),
          if (doc.description != null && doc.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Texte extrait (OCR)',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                doc.description!.length > 400
                    ? '${doc.description!.substring(0, 400)}…'
                    : doc.description!,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white54),
          const SizedBox(width: 8),
          Text(
            '$label : ',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
