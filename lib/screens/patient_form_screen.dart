import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/card_scan.dart';
import '../models/document_type.dart';
import '../models/patient.dart';
import '../models/patient_data.dart';
import 'patient_dossier_screen.dart';

class PatientFormScreen extends StatefulWidget {
  final PatientData initialData;
  final String imagePath;
  final String? ocrRawText;

  const PatientFormScreen({
    super.key,
    required this.initialData,
    required this.imagePath,
    this.ocrRawText,
  });

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nomController;
  late final TextEditingController _prenomController;
  late final TextEditingController _dateNaissanceController;
  late final TextEditingController _numeroDocumentController;
  late final TextEditingController _groupeSanguinController;

  @override
  void initState() {
    super.initState();

    _nomController = TextEditingController(text: widget.initialData.nom);
    _prenomController = TextEditingController(text: widget.initialData.prenom);
    _dateNaissanceController =
        TextEditingController(text: widget.initialData.dateNaissance);
    _numeroDocumentController =
        TextEditingController(text: widget.initialData.numeroDocument);
    _groupeSanguinController =
        TextEditingController(text: widget.initialData.groupeSanguin);
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _dateNaissanceController.dispose();
    _numeroDocumentController.dispose();
    _groupeSanguinController.dispose();
    super.dispose();
  }

  bool _isSaving = false;

  bool get _isChifa => widget.initialData.sourceType == DocumentType.chifa;
  bool get _isCni => widget.initialData.sourceType == DocumentType.cni;

  String get _numeroDocumentLabel {
    if (_isChifa) return 'Numéro de sécurité sociale';
    if (_isCni) return 'Numéro CNI';
    return 'Numéro document';
  }

  /// Convertit une date DD/MM/YYYY (format formulaire) en YYYY-MM-DD (format ISO pour SQLite).
  String _toIsoDate(String ddmmyyyy) {
    final parts = ddmmyyyy.split('/');
    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final nom = _nomController.text.trim();
      final prenom = _prenomController.text.trim();
      final dateIso = _toIsoDate(_dateNaissanceController.text.trim());
      final numeroDocument = _numeroDocumentController.text.trim();
      final groupeSanguin = _isChifa ? '' : _groupeSanguinController.text.trim();

      final dao = DatabaseHelper.instance;

      final existing = await dao.findPatientByIdentity(
        nom: nom,
        prenom: prenom,
        dateNaissance: dateIso,
      );

      int patientId;
      if (existing != null) {
        patientId = existing.id!;
      } else {
        patientId = await dao.insertPatient(Patient(
          nom: nom,
          prenom: prenom,
          dateNaissance: dateIso,
          groupeSanguin: groupeSanguin.isNotEmpty ? groupeSanguin : null,
          numeroCni: _isCni ? numeroDocument : null,
          numeroSecuriteSociale: _isChifa ? numeroDocument : null,
        ));
      }

      await dao.insertCardScan(CardScan(
        patientId: patientId,
        typeCarte: _isChifa ? 'CHIFA' : 'CNI',
        imagePath: widget.imagePath,
        ocrRawText: widget.ocrRawText,
      ));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PatientDossierScreen(patientId: patientId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de l'enregistrement : $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool _containsArabic(String value) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(value);
  }

  Widget _warningIcon(String fieldName) {
    if (!widget.initialData.doitVerifier(fieldName)) {
      return const SizedBox.shrink();
    }
    return const Tooltip(
      message: 'À vérifier',
      child: Icon(Icons.warning_amber_rounded, color: Colors.amber),
    );
  }

  Widget _buildTextField({
    required String label,
    required String fieldName,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final isArabic = _containsArabic(controller.text);

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      textAlign: isArabic ? TextAlign.right : TextAlign.left,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _warningIcon(fieldName),
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Champ obligatoire';
    }
    return null;
  }

  String? _dateValidator(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Champ obligatoire';

    final isValid = RegExp(
      r'^(0[1-9]|[12][0-9]|3[01])\/(0[1-9]|1[0-2])\/((19|20)\d{2})$',
    ).hasMatch(input);

    if (!isValid) return 'Format attendu : JJ/MM/AAAA';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hasWarnings = widget.initialData.champsAVerifier.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Vérification des données')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (hasWarnings)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Certains champs n’ont pas été détectés avec certitude. Vérifiez-les avant de confirmer.",
                      ),
                    ),
                  ],
                ),
              ),
            _buildTextField(
              label: 'Nom',
              fieldName: 'nom',
              controller: _nomController,
              validator: _requiredValidator,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              label: 'Prénom',
              fieldName: 'prenom',
              controller: _prenomController,
              validator: _requiredValidator,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              label: 'Date de naissance',
              fieldName: 'dateNaissance',
              controller: _dateNaissanceController,
              keyboardType: TextInputType.datetime,
              validator: _dateValidator,
            ),
            // Groupe sanguin uniquement pour la CNI
            if (!_isChifa) ...[
              const SizedBox(height: 14),
              _buildTextField(
                label: 'Groupe sanguin',
                fieldName: 'groupeSanguin',
                controller: _groupeSanguinController,
              ),
            ],
            const SizedBox(height: 14),
            _buildTextField(
              label: _numeroDocumentLabel,
              fieldName: 'numeroDocument',
              controller: _numeroDocumentController,
              keyboardType: TextInputType.number,
              validator: _requiredValidator,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _confirm,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(_isSaving ? 'Enregistrement...' : 'Confirmer'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}