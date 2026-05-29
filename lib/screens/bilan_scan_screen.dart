import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/bilan.dart';
import '../models/bilan_page.dart';
import '../services/bilan_parser.dart';
import '../services/document_scanner_service.dart';
import '../services/ocr_service.dart';
import 'bilan_form_screen.dart';

/// Capture multi-page d'un bilan biologique.
///
/// Le mono-page n'est pas un chemin séparé : c'est simplement cet écran avec
/// une seule page dans [_pages]. L'utilisateur ajoute des pages via la caméra
/// (scanner ML Kit, une par une) ou la galerie (sélection multiple), peut les
/// réordonner et les supprimer, puis lance l'OCR + parsing en une fois.
///
/// Point critique : l'OCR de chaque page est concaténé AVANT un unique appel à
/// [BilanParser.parse]. Une section (ex: BIOCHIMIE) peut s'étaler sur 2 pages,
/// et seul le parsing du texte concaténé préserve l'état de catégorie courante
/// d'une page à l'autre. Ne JAMAIS parser page par page pour fusionner ensuite.
class BilanScanScreen extends StatefulWidget {
  final int patientId;

  const BilanScanScreen({super.key, required this.patientId});

  @override
  State<BilanScanScreen> createState() => _BilanScanScreenState();
}

class _BilanScanScreenState extends State<BilanScanScreen> {
  static const Color _primary = Color(0xFF2563EB);

  final _picker = ImagePicker();
  final _scannerService = DocumentScannerService();
  final _ocrService = OcrService();

  /// Pages capturées, dans l'ordre d'affichage (= ordre de parsing).
  final List<File> _pages = [];
  bool _isAnalyzing = false;

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  // ── Ajout de pages ──────────────────────────────────────────────────────

  /// Caméra : scanner ML Kit (recadrage + correction de perspective), une page.
  Future<void> _addFromCamera() async {
    final scanned = await _scannerService.scanDocument();
    if (scanned == null) return;
    setState(() => _pages.add(scanned));
  }

  /// Galerie : sélection multiple, ajoute toutes les images choisies.
  Future<void> _addFromGallery() async {
    final picked = await _picker.pickMultiImage(
      imageQuality: 100,
      maxWidth: 2000,
      maxHeight: 2500,
    );
    if (picked.isEmpty) return;
    setState(() => _pages.addAll(picked.map((x) => File(x.path))));
  }

  void _removePage(int index) {
    setState(() => _pages.removeAt(index));
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      // ReorderableListView : si on descend un élément, l'index cible est
      // décalé de 1 après retrait de l'ancien.
      if (newIndex > oldIndex) newIndex -= 1;
      final page = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, page);
    });
  }

  // ── Persistance ─────────────────────────────────────────────────────────

  /// Persiste [tempFile] dans `app/bilans/{patientId}/`. [index] garantit
  /// l'unicité du nom même si plusieurs pages sont copiées dans la même ms.
  Future<String> _persistImage(File tempFile, int index) async {
    final appDir = await getApplicationDocumentsDirectory();
    final destDir = Directory(p.join(appDir.path, 'bilans', '${widget.patientId}'));
    await destDir.create(recursive: true);
    final ext = p.extension(tempFile.path).isNotEmpty ? p.extension(tempFile.path) : '.jpg';
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$index$ext';
    final dest = File(p.join(destDir.path, fileName));
    await tempFile.copy(dest.path);
    return dest.path;
  }

  // ── Analyse ─────────────────────────────────────────────────────────────

  /// Pour chaque page (dans l'ordre) : persiste l'image + OCR. Concatène les
  /// textes, parse UNE fois, route vers le formulaire de correction avec les
  /// pages persistées. Au retour avec un id, remonte `true` jusqu'au dossier.
  Future<void> _analyser() async {
    if (_pages.isEmpty) return;
    setState(() => _isAnalyzing = true);

    try {
      final buffer = StringBuffer();
      final pagesBilan = <BilanPage>[];

      for (var i = 0; i < _pages.length; i++) {
        final permanentPath = await _persistImage(_pages[i], i);
        final texte = await _ocrService.extractStructuredText(File(permanentPath));
        if (texte.isNotEmpty) {
          if (buffer.isNotEmpty) buffer.write('\n');
          buffer.write(texte);
        }
        pagesBilan.add(
          BilanPage(bilanId: 0, pageNumber: i + 1, filePath: permanentPath),
        );
      }

      final texteConcatene = buffer.toString();
      debugPrint(
        '[BilanScanScreen] ${_pages.length} page(s) — ${texteConcatene.length} chars OCR concaténés',
      );

      final Bilan? initialBilan = texteConcatene.isNotEmpty
          ? BilanParser.parse(texteConcatene, widget.patientId)
          : null;

      if (!mounted) return;
      final bilanId = await Navigator.push<int>(
        context,
        MaterialPageRoute(
          builder: (_) => BilanFormScreen(
            patientId: widget.patientId,
            initialBilan: initialBilan,
            pages: pagesBilan,
          ),
        ),
      );

      if (!mounted) return;
      if (bilanId != null) {
        // Le bilan est enregistré : on remonte au dossier patient sans repasser
        // par un AddDocumentScreen à moitié rempli (qui se pop à son tour).
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Scanner un bilan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildAddButtons(),
          _buildCounter(),
          Expanded(
            child: _pages.isEmpty ? _buildEmptyState() : _buildPagesList(),
          ),
          _buildAnalyzeButton(),
        ],
      ),
    );
  }

  Widget _buildAddButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _addButton(
              icon: Icons.document_scanner_outlined,
              label: 'Caméra',
              onTap: _isAnalyzing ? null : _addFromCamera,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _addButton(
              icon: Icons.photo_library_outlined,
              label: 'Galerie',
              onTap: _isAnalyzing ? null : _addFromGallery,
            ),
          ),
        ],
      ),
    );
  }

  Widget _addButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: _primary,
        side: BorderSide(color: _primary.withValues(alpha: 0.5)),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildCounter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          _pages.isEmpty
              ? 'Aucune page'
              : '${_pages.length} page${_pages.length > 1 ? 's' : ''}',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'Ajoute les pages du bilan\nvia la caméra ou la galerie.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildPagesList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: _pages.length,
      onReorder: _reorder,
      itemBuilder: (context, index) {
        final file = _pages[index];
        return Card(
          key: ValueKey(file.path),
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(
                file,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
            title: Text(
              'Page ${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red.shade400,
                  onPressed: _isAnalyzing ? null : () => _removePage(index),
                  tooltip: 'Supprimer',
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.drag_handle, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnalyzeButton() {
    final n = _pages.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: (_isAnalyzing || _pages.isEmpty) ? null : _analyser,
          icon: _isAnalyzing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.science_outlined),
          label: Text(
            _isAnalyzing
                ? 'Analyse en cours…'
                : 'Analyser le bilan${n > 0 ? ' ($n page${n > 1 ? 's' : ''})' : ''}',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}
