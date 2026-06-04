import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/bilan.dart';
import '../models/bilan_page.dart';
import '../models/document_page.dart';
import '../models/medical_document.dart';
import '../models/patient.dart';
import '../services/audit_service.dart';
import '../services/bilan_parser.dart';
import '../services/document_scanner_service.dart';
import '../services/ocr_service.dart';
import '../widgets/patient_picker_sheet.dart';
import 'bilan_form_screen.dart';

class AddDocumentScreen extends StatefulWidget {
  /// Dossier patient cible. `null` quand l'écran est ouvert depuis la Home
  /// (« Ajouter un document ») : le médecin scanne d'abord, puis choisit le
  /// patient via le sélecteur intégré au formulaire.
  final int? patientId;

  const AddDocumentScreen({super.key, this.patientId});

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

  /// Patient choisi via le sélecteur quand l'écran est ouvert sans
  /// `widget.patientId` (flux Home). `null` tant qu'aucun n'est sélectionné.
  Patient? _selectedPatient;

  /// Id du dossier cible : celui passé en paramètre (flux dossier patient) ou,
  /// à défaut, celui du patient choisi dans le formulaire (flux Home).
  int? get _effectivePatientId => widget.patientId ?? _selectedPatient?.id;

  /// `true` si le médecin doit choisir le patient lui-même (flux Home).
  bool get _needsPatientPicker => widget.patientId == null;

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

  /// Galerie : import via ML Kit (détection des bords + recadrage + correction
  /// de perspective/orientation + amélioration), multi-pages. Les images
  /// renvoyées sont déjà propres — elles serviront telles quelles à l'OCR, à la
  /// visionneuse et à l'impression.
  Future<void> _addFromGallery() async {
    final files = await _scannerService.scanDocuments();
    if (files.isEmpty) return;
    setState(() => _pages.addAll(files));
    for (final file in files) {
      await _ocrPage(file);
    }
  }

  /// Lance l'OCR d'une page et mémorise le résultat. Utilise l'extraction
  /// structurée (lignes/blocs de lignes), comme les bilans, pour un texte
  /// lisible et bien organisé plutôt que le flux mot-à-mot de ML Kit.
  Future<void> _ocrPage(File image) async {
    debugPrint('[AddDocumentScreen] OCR page — type=$_selectedType path=${image.path}');
    setState(() => _isScanning = true);

    final text = await _ocrService.extractStructuredText(image);

    debugPrint('[AddDocumentScreen] OCR terminé — ${text.length} caractères extraits');
    if (!mounted) return;
    setState(() {
      _ocrByPath[image.path] = text;
      _isScanning = false;
    });
  }

  /// Éditeur du texte OCR d'une page : image + champ texte éditable.
  /// La correction se fait page par page (jamais sur le bloc concaténé).
  Future<void> _editPageText(int index) async {
    final file = _pages[index];
    final edited = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PageTextEditor(
        pageNumber: index + 1,
        image: file,
        initialText: _ocrByPath[file.path] ?? '',
      ),
    );
    if (edited == null) return;
    setState(() => _ocrByPath[file.path] = edited);
  }

  /// Aperçu compact du texte OCR d'une page (1re ligne) pour la tuile.
  String _pageSubtitle(String path) {
    final text = _ocrByPath[path]?.trim() ?? '';
    if (_isScanning && text.isEmpty) return 'Extraction du texte…';
    if (text.isEmpty) return 'Aucun texte — touchez pour saisir';
    final firstLine = text.split('\n').first.trim();
    return firstLine.isEmpty ? 'Touchez pour corriger le texte' : firstLine;
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

  /// Ouvre le sélecteur de dossier patient (flux Home). Retourne `true` si un
  /// patient est désormais sélectionné, `false` si l'utilisateur a annulé.
  Future<bool> _pickPatient() async {
    final patient = await PatientPickerSheet.show(context);
    if (patient == null || !mounted) return false;
    setState(() => _selectedPatient = patient);
    return true;
  }

  /// Analyse d'un bilan biologique — partage le MÊME formulaire de capture que
  /// les autres types (pages, OCR page par page déjà effectué) ; seule la fin
  /// du flux diffère : au lieu d'un simple enregistrement, on concatène l'OCR,
  /// on parse les valeurs biologiques ([BilanParser]) et on route vers le
  /// formulaire de correction [BilanFormScreen].
  ///
  /// Point critique (cf. BilanScanScreen) : le parsing se fait sur le texte
  /// concaténé de TOUTES les pages dans l'ordre, jamais page par page — une
  /// section (ex: BIOCHIMIE) peut s'étaler sur deux pages.
  Future<void> _analyzeBilan() async {
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez d\'abord ajouter au moins une page du bilan.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Flux Home : aucun dossier imposé → on exige un patient cible.
    if (_effectivePatientId == null) {
      final picked = await _pickPatient();
      if (!picked) return;
    }
    final patientId = _effectivePatientId!;

    setState(() => _isSaving = true);

    try {
      final dateIso = _dateController.text.trim().isNotEmpty
          ? _toIsoDate(_dateController.text.trim())
          : null;

      // Persiste chaque page (sous-dossier `bilans/`) et réutilise l'OCR déjà
      // extrait à l'ajout. Chaque page conserve son propre texte pour la
      // visionneuse ; la concaténation alimente le parser.
      final bilanPages = <BilanPage>[];
      for (var i = 0; i < _pages.length; i++) {
        final tempPath = _pages[i].path;
        final permanentPath = await _persistImage(_pages[i], subdir: 'bilans', index: i);
        final pageText = _ocrByPath[tempPath];
        bilanPages.add(
          BilanPage(
            bilanId: 0,
            pageNumber: i + 1,
            filePath: permanentPath,
            ocrText: (pageText != null && pageText.isNotEmpty) ? pageText : null,
          ),
        );
      }

      final texteConcatene = _ocrText;
      Bilan? initialBilan = texteConcatene.isNotEmpty
          ? BilanParser.parse(texteConcatene, patientId)
          : null;

      // La date saisie dans le formulaire prime sur celle devinée par l'OCR.
      if (dateIso != null) {
        final parsed = DateTime.tryParse(dateIso);
        if (parsed != null) {
          initialBilan = (initialBilan ?? Bilan(patientId: patientId))
              .copyWith(dateExamen: parsed);
        }
      }

      if (!mounted) return;
      final bilanId = await Navigator.push<int>(
        context,
        MaterialPageRoute(
          builder: (_) => BilanFormScreen(
            patientId: patientId,
            initialBilan: initialBilan,
            pages: bilanPages,
          ),
        ),
      );

      if (!mounted) return;
      // Bilan enregistré → on remonte au dossier patient (rafraîchissement).
      if (bilanId != null) Navigator.pop(context, true);
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
    final destDir = Directory(p.join(appDir.path, subdir, '$_effectivePatientId'));
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

    // Flux Home : aucun dossier n'est imposé → on exige un patient cible.
    if (_effectivePatientId == null) {
      final picked = await _pickPatient();
      if (!picked) return;
    }

    setState(() => _isSaving = true);

    try {
      final dateIso = _dateController.text.trim().isNotEmpty
          ? _toIsoDate(_dateController.text.trim())
          : null;

      // Persiste chaque page dans l'ordre d'affichage → pageNumber 1..N.
      // Chaque page conserve SON propre texte OCR (corrigé ou non).
      final docPages = <DocumentPage>[];
      for (var i = 0; i < _pages.length; i++) {
        final tempPath = _pages[i].path;
        final permanentPath = await _persistImage(_pages[i], subdir: 'documents', index: i);
        final pageText = _ocrByPath[tempPath];
        docPages.add(
          DocumentPage(
            documentId: 0,
            pageNumber: i + 1,
            filePath: permanentPath,
            ocrText: (pageText != null && pageText.isNotEmpty) ? pageText : null,
          ),
        );
      }

      // `description` = texte global concaténé, conservé pour recherche/résumé.
      final ocr = _ocrText;

      final titre = _titreController.text.trim();

      // `documentId: 0` est un placeholder ; la DAO l'écrase avec l'id généré.
      final docId = await DatabaseHelper.instance.insertMedicalDocument(
        MedicalDocument(
          patientId: _effectivePatientId!,
          typeDocument: _selectedType,
          titre: titre,
          description: ocr.isNotEmpty ? ocr : null,
          documentDate: dateIso,
          pages: docPages,
        ),
      );

      await AuditService.instance.logCreation(
        entityType: 'document',
        entityId: docId,
        patientId: _effectivePatientId,
        description: 'Ajout du document « $titre » ($_selectedType)',
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
          children: [
            // Flux Home : sélecteur de dossier patient en tête de formulaire.
            if (_needsPatientPicker) ...[
              _buildPatientSelector(),
              const SizedBox(height: 20),
            ],
            // Même formulaire de capture pour TOUS les types (harmonisé) :
            // boutons Caméra/Galerie + liste de pages, puis sélecteur de type.
            _buildPagesSection(),
            const SizedBox(height: 20),
            _buildTypeSelector(),
            const SizedBox(height: 16),
            // Le bilan est auto-nommé (« Bilan du … ») → on masque le titre,
            // seul champ qui n'a pas de sens pour ce type.
            if (_selectedType != 'bilan') ...[
              _buildTitreField(),
              const SizedBox(height: 16),
            ],
            _buildDateField(),
            const SizedBox(height: 28),
            _buildPrimaryButton(),
          ],
        ),
      ),
    );
  }

  /// Sélecteur de dossier patient (flux Home uniquement). Affiche le patient
  /// choisi ou une invite à en choisir un. Touchable pour (re)ouvrir la feuille.
  Widget _buildPatientSelector() {
    final patient = _selectedPatient;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dossier patient',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 10),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _isSaving ? null : _pickPatient,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: patient == null ? Colors.grey.shade300 : _primary,
                  width: patient == null ? 1 : 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    patient == null ? Icons.person_search : Icons.person,
                    color: patient == null ? Colors.grey : _primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: patient == null
                        ? Text(
                            'Choisir le dossier patient',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[600],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${patient.nom} ${patient.prenom}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              if (patient.age != null)
                                Text(
                                  '${patient.age} ans',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[500],
                                  ),
                                ),
                            ],
                          ),
                  ),
                  Icon(
                    patient == null ? Icons.chevron_right : Icons.edit_outlined,
                    color: patient == null ? Colors.grey : _primary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
            onTap: _isSaving ? null : () => _editPageText(index),
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
            subtitle: Text(
              _pageSubtitle(file.path),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  color: _primary,
                  onPressed: _isSaving ? null : () => _editPageText(index),
                  tooltip: 'Corriger le texte',
                ),
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
        labelText: _selectedType == 'bilan'
            ? 'Date de l\'examen (optionnel)'
            : 'Date du document (optionnel)',
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

  /// Bouton d'action final, adapté au type : « Analyser le bilan » (lance
  /// l'extraction des valeurs biologiques) pour un bilan, sinon « Enregistrer
  /// le document ». Même style pour rester harmonieux.
  Widget _buildPrimaryButton() {
    final isBilan = _selectedType == 'bilan';
    final n = _pages.length;
    final suffix = n > 1 ? ' ($n pages)' : '';

    final String label;
    if (isBilan) {
      label = _isSaving ? 'Analyse en cours…' : 'Analyser le bilan$suffix';
    } else {
      label = _isSaving ? 'Enregistrement…' : 'Enregistrer le document$suffix';
    }

    return ElevatedButton.icon(
      onPressed: _isSaving || _isScanning ? null : (isBilan ? _analyzeBilan : _save),
      icon: _isSaving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Icon(isBilan ? Icons.science_outlined : Icons.save_outlined),
      label: Text(label),
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

/// Éditeur du texte OCR d'une page : aperçu image + champ texte éditable.
/// Pop avec le texte corrigé si l'utilisateur valide, `null` s'il annule.
class _PageTextEditor extends StatefulWidget {
  final int pageNumber;
  final File image;
  final String initialText;

  const _PageTextEditor({
    required this.pageNumber,
    required this.image,
    required this.initialText,
  });

  @override
  State<_PageTextEditor> createState() => _PageTextEditorState();
}

class _PageTextEditorState extends State<_PageTextEditor> {
  static const Color _primary = Color(0xFF2563EB);
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Texte de la page ${widget.pageNumber}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                widget.image,
                height: 160,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 10,
              minLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Texte extrait (corrigeable)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _controller.text.trim()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Valider'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
