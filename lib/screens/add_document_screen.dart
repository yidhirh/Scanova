import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../database/database_helper.dart';
import '../models/document_page.dart';
import '../models/medical_document.dart';
import '../services/document_scanner_service.dart';
import '../services/ocr_service.dart';
import 'bilan_scan_screen.dart';

class AddDocumentScreen extends StatefulWidget {
  final int patientId;

  const AddDocumentScreen({super.key, required this.patientId});

  @override
  State<AddDocumentScreen> createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends State<AddDocumentScreen> {
  static const Color _primary = Color(0xFF2563EB);

  static const List<_DocType> _types = [
    _DocType('ordonnance', 'Ordonnance', Icons.medical_services_outlined, Colors.blue),
    _DocType('bilan', 'Bilan / Analyse', Icons.science_outlined, Colors.green),
    _DocType('radio', 'Radiographie', Icons.image_outlined, Colors.purple),
    _DocType('compte rendu', 'Compte rendu', Icons.description_outlined, Colors.orange),
    _DocType('autre', 'Autre', Icons.folder_outlined, Colors.grey),
  ];

  final _formKey = GlobalKey<FormState>();
  final _titreController = TextEditingController();
  final _dateController = TextEditingController();
  final _ocrService = OcrService();
  final _picker = ImagePicker();
  final _scannerService = DocumentScannerService();

  /// Pages du document, dans l'ordre d'affichage (= ordre de stockage et de
  /// concaténation de l'OCR). Le mono-page n'est qu'un cas particulier : une
  /// seule entrée dans cette liste.
  final List<File> _pages = [];

  /// OCR mémorisé par page (clé = chemin du fichier temporaire). Évite de
  /// relancer l'OCR au réordonnancement : on ne fait qu'une extraction par page
  /// à l'ajout, puis on concatène dans l'ordre courant via [_ocrText].
  final Map<String, String> _ocrByPath = {};

  String _selectedType = 'ordonnance';
  bool _isScanning = false;
  bool _isSaving = false;

  /// Texte OCR concaténé dans l'ordre d'affichage des pages.
  String get _ocrText {
    final buffer = StringBuffer();
    for (final page in _pages) {
      final text = _ocrByPath[page.path];
      if (text != null && text.isNotEmpty) {
        if (buffer.isNotEmpty) buffer.write('\n');
        buffer.write(text);
      }
    }
    return buffer.toString();
  }

  @override
  void dispose() {
    _titreController.dispose();
    _dateController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  // ── Ajout de pages ────────────────────────────────────────────────────────

  /// Caméra : scanner ML Kit (détection des bords + correction de perspective),
  /// une page à la fois — même qualité de capture que les bilans et les cartes.
  Future<void> _addFromCamera() async {
    final scanned = await _scannerService.scanDocument();
    if (scanned == null) return;
    setState(() => _pages.add(scanned));
    await _ocrPage(scanned);
  }

  /// Galerie : sélection multiple, ajoute toutes les images choisies.
  Future<void> _addFromGallery() async {
    final picked = await _picker.pickMultiImage(
      imageQuality: 100,
      maxWidth: 2000,
      maxHeight: 2500,
    );
    if (picked.isEmpty) return;
    final files = picked.map((x) => File(x.path)).toList();
    setState(() => _pages.addAll(files));
    for (final file in files) {
      await _ocrPage(file);
    }
  }

  /// Lance l'OCR (extraction plate) d'une page et mémorise le résultat.
  Future<void> _ocrPage(File image) async {
    debugPrint('[AddDocumentScreen] OCR page — type=$_selectedType path=${image.path}');
    setState(() => _isScanning = true);

    final text = await _ocrService.extractTextFromImage(image.path);

    debugPrint('[AddDocumentScreen] OCR terminé — ${text.length} caractères extraits');
    if (!mounted) return;
    setState(() {
      _ocrByPath[image.path] = text;
      _isScanning = false;
    });
  }

  void _removePage(int index) {
    setState(() {
      final removed = _pages.removeAt(index);
      _ocrByPath.remove(removed.path);
    });
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

  /// Le bilan biologique a son propre flux multi-page : on délègue à
  /// [BilanScanScreen] (capture N pages → OCR + parsing → formulaire). Au
  /// retour avec succès, on remonte `true` jusqu'au dossier patient sans
  /// laisser cet écran à moitié rempli visible.
  Future<void> _openBilanScan() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BilanScanScreen(patientId: widget.patientId),
      ),
    );
    if (!mounted) return;
    if (ok == true) Navigator.pop(context, true);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1990),
      lastDate: now,
    );
    if (picked == null) return;
    final formatted =
        '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    setState(() => _dateController.text = formatted);
  }

  String? _toIsoDate(String ddmmyyyy) {
    final parts = ddmmyyyy.split('/');
    if (parts.length != 3) return null;
    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }

  // ── Persistance ───────────────────────────────────────────────────────────

  /// Persiste [tempFile] dans `app/[subdir]/{patientId}/`. [index] garantit
  /// l'unicité du nom même si plusieurs pages sont copiées dans la même ms.
  Future<String> _persistImage(File tempFile, {required String subdir, required int index}) async {
    final appDir = await getApplicationDocumentsDirectory();
    final destDir = Directory(p.join(appDir.path, subdir, '${widget.patientId}'));
    await destDir.create(recursive: true);
    final ext = p.extension(tempFile.path).isNotEmpty ? p.extension(tempFile.path) : '.jpg';
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$index$ext';
    final dest = File(p.join(destDir.path, fileName));
    await tempFile.copy(dest.path);
    return dest.path;
  }

  Future<void> _save() async {
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez d\'abord ajouter au moins une page du document.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final dateIso = _dateController.text.trim().isNotEmpty
          ? _toIsoDate(_dateController.text.trim())
          : null;

      // Persiste chaque page dans l'ordre d'affichage → pageNumber 1..N.
      final docPages = <DocumentPage>[];
      for (var i = 0; i < _pages.length; i++) {
        final permanentPath = await _persistImage(_pages[i], subdir: 'documents', index: i);
        docPages.add(
          DocumentPage(documentId: 0, pageNumber: i + 1, filePath: permanentPath),
        );
      }

      final ocr = _ocrText;

      // `documentId: 0` est un placeholder ; la DAO l'écrase avec l'id généré.
      await DatabaseHelper.instance.insertMedicalDocument(
        MedicalDocument(
          patientId: widget.patientId,
          typeDocument: _selectedType,
          titre: _titreController.text.trim(),
          description: ocr.isNotEmpty ? ocr : null,
          documentDate: dateIso,
          pages: docPages,
        ),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Ajouter un document',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          // Le bilan a un flux multi-page dédié : on masque les champs
          // génériques (pages, titre, date) — redondants car BilanFormScreen
          // gère déjà date/labo et le titre est dérivable.
          children: _selectedType == 'bilan'
              ? [
                  _buildTypeSelector(),
                  const SizedBox(height: 20),
                  _buildBilanScanCard(),
                ]
              : [
                  _buildPagesSection(),
                  const SizedBox(height: 20),
                  _buildTypeSelector(),
                  const SizedBox(height: 16),
                  _buildTitreField(),
                  const SizedBox(height: 16),
                  _buildDateField(),
                  if (_ocrText.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildOcrPreview(),
                  ],
                  const SizedBox(height: 28),
                  _buildSaveButton(),
                ],
        ),
      ),
    );
  }

  /// Carte d'entrée du flux bilan multi-page (remplace la section générique
  /// quand le type "bilan" est sélectionné).
  Widget _buildBilanScanCard() {
    return GestureDetector(
      onTap: _openBilanScan,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _primary, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            const Icon(Icons.document_scanner_outlined, size: 48, color: _primary),
            const SizedBox(height: 12),
            const Text(
              'Scanner le bilan (multi-page)',
              style: TextStyle(
                color: _primary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Caméra page par page ou import depuis la galerie',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section multi-page ──────────────────────────────────────────────────────

  Widget _buildPagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _addButton(
                icon: Icons.document_scanner_outlined,
                label: 'Caméra',
                onTap: _isSaving ? null : _addFromCamera,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _addButton(
                icon: Icons.photo_library_outlined,
                label: 'Galerie',
                onTap: _isSaving ? null : _addFromGallery,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_pages.isEmpty)
          _buildEmptyPages()
        else
          _buildPagesList(),
        if (_isScanning) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text('Extraction du texte…', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ],
      ],
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

  Widget _buildEmptyPages() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_photo_alternate_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'Ajoute une ou plusieurs pages\nvia la caméra ou la galerie.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildPagesList() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
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
                  onPressed: _isSaving ? null : () => _removePage(index),
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

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Type de document',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _types.map((type) {
            final selected = _selectedType == type.value;
            return GestureDetector(
              onTap: () => setState(() => _selectedType = type.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? type.color.withValues(alpha: 0.12)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? type.color : Colors.grey.shade300,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(type.icon,
                        size: 16,
                        color: selected ? type.color : Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      type.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected ? type.color : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTitreField() {
    return TextFormField(
      controller: _titreController,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: 'Titre',
        hintText: 'Ex : Ordonnance du 12/05/2026',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.title),
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null,
    );
  }

  Widget _buildDateField() {
    return TextFormField(
      controller: _dateController,
      readOnly: true,
      onTap: _pickDate,
      decoration: InputDecoration(
        labelText: 'Date du document (optionnel)',
        hintText: 'JJ/MM/AAAA',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.calendar_today_outlined),
        suffixIcon: _dateController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() => _dateController.clear()),
              )
            : null,
      ),
    );
  }

  Widget _buildOcrPreview() {
    return Container(
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
                'Texte extrait (${_ocrText.length} caractères)',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _ocrText.length > 300
                ? '${_ocrText.substring(0, 300)}…'
                : _ocrText,
            style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    final n = _pages.length;
    return ElevatedButton.icon(
      onPressed: _isSaving || _isScanning ? null : _save,
      icon: _isSaving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.save_outlined),
      label: Text(
        _isSaving
            ? 'Enregistrement…'
            : 'Enregistrer le document${n > 1 ? ' ($n pages)' : ''}',
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }
}

class _DocType {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _DocType(this.value, this.label, this.icon, this.color);
}
