import 'package:flutter/material.dart';

import '../models/document_type.dart';
import '../models/patient_data.dart';

class PatientFormScreen extends StatefulWidget {
  final PatientData initialData;

  const PatientFormScreen({
    super.key,
    required this.initialData,
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

  bool get _isChifa => widget.initialData.sourceType == DocumentType.chifa;
  bool get _isCni => widget.initialData.sourceType == DocumentType.cni;

  String get _numeroDocumentLabel {
    if (_isChifa) return 'Numéro de sécurité sociale';
    if (_isCni) return 'Numéro CNI';
    return 'Numéro document';
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;

    final finalData = PatientData(
      nom: _nomController.text.trim(),
      prenom: _prenomController.text.trim(),
      dateNaissance: _dateNaissanceController.text.trim(),
      numeroDocument: _numeroDocumentController.text.trim(),
      groupeSanguin: _isChifa ? '' : _groupeSanguinController.text.trim(),
      texteBrut: widget.initialData.texteBrut,
      sourceType: widget.initialData.sourceType,
      champsAVerifier: const {},
    );

    Navigator.pop(context, finalData);
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
                  color: Colors.amber.withOpacity(0.15),
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
              onPressed: _confirm,
              icon: const Icon(Icons.check),
              label: const Text('Confirmer'),
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