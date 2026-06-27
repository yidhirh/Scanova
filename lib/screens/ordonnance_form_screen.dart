// lib/screens/ordonnance_form_screen.dart
//
// OrdonnanceFormScreen — saisie d'une ordonnance numérique (sans scan).
//
// Complète le module OCR : au lieu de numériser une ordonnance papier, le
// médecin saisit directement médecin, date, médicaments (multi-lignes :
// nom / dosage / posologie / durée) et remarques. L'ordonnance est persistée
// comme un [MedicalDocument] de type 'ordonnance_numerique' (cf.
// [OrdonnanceNumerique]).
//
// Pop avec l'id du patient (int) après enregistrement — l'appelant
// ([AddDocumentScreen]) redirige alors vers le dossier du patient.

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/ordonnance_numerique.dart';
import '../models/patient.dart';
import '../services/audit_service.dart';
import '../widgets/patient_picker_sheet.dart';

class OrdonnanceFormScreen extends StatefulWidget {
  /// Dossier patient cible. `null` quand on vient de la Home : le médecin
  /// choisit alors le patient via le sélecteur intégré au formulaire.
  final int? patientId;

  /// Patient pré-sélectionné (optionnel, flux Home où un patient a déjà été
  /// choisi dans [AddDocumentScreen]). Ignoré si [patientId] est fourni.
  final Patient? initialPatient;

  const OrdonnanceFormScreen({super.key, this.patientId, this.initialPatient});

  @override
  State<OrdonnanceFormScreen> createState() => _OrdonnanceFormScreenState();
}

class _OrdonnanceFormScreenState extends State<OrdonnanceFormScreen> {
  static const Color _primary = Color(0xFF2563EB);

  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();
  final _medecinController = TextEditingController();
  final _remarquesController = TextEditingController();

  /// Lignes de médicaments (1 minimum). Chaque entrée porte ses 4 contrôleurs.
  final List<_MedicamentControllers> _medicaments = [];

  /// Patient cible. Chargé depuis la base si [widget.patientId] est fourni
  /// (dossier verrouillé), sinon choisi via le sélecteur.
  Patient? _patient;

  bool _isSaving = false;

  /// `true` si le patient est imposé par l'appelant (flux dossier patient) :
  /// le sélecteur est alors désactivé.
  bool get _patientLocked => widget.patientId != null;

  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _dateController.text = _formatDate(_date);
    _medicaments.add(_MedicamentControllers());
    if (widget.patientId != null) {
      _loadPatient(widget.patientId!);
    } else {
      _patient = widget.initialPatient;
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _medecinController.dispose();
    _remarquesController.dispose();
    for (final m in _medicaments) {
      m.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPatient(int id) async {
    final patient = await DatabaseHelper.instance.getPatientById(id);
    if (!mounted) return;
    setState(() => _patient = patient);
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _toIsoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _date = picked;
      _dateController.text = _formatDate(picked);
    });
  }

  Future<void> _pickPatient() async {
    if (_patientLocked) return;
    final patient = await PatientPickerSheet.show(context);
    if (patient == null || !mounted) return;
    setState(() => _patient = patient);
  }

  void _addMedicament() {
    setState(() => _medicaments.add(_MedicamentControllers()));
  }

  void _removeMedicament(int index) {
    setState(() => _medicaments.removeAt(index).dispose());
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Le patient n'est pas un champ de Form : validation manuelle.
    if (_patient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner le patient.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final patient = _patient!;

    setState(() => _isSaving = true);

    try {
      final ordonnance = OrdonnanceNumerique(
        patientId: patient.id!,
        nomPatient: '${patient.nom} ${patient.prenom}',
        dateIso: _toIsoDate(_date),
        nomMedecin: _medecinController.text.trim(),
        medicaments: _medicaments
            .map((m) => MedicamentPrescrit(
                  nom: m.nom.text.trim(),
                  dosage: m.dosage.text.trim(),
                  posologie: m.posologie.text.trim(),
                  duree: m.duree.text.trim(),
                ))
            .toList(),
        remarques: _remarquesController.text.trim(),
      );

      final docId = await DatabaseHelper.instance
          .insertMedicalDocument(ordonnance.toMedicalDocument());

      await AuditService.instance.logCreation(
        entityType: 'document',
        entityId: docId,
        patientId: patient.id,
        description:
            'Création de l\'ordonnance numérique « ${ordonnance.titre} »',
      );

      if (!mounted) return;
      // Pop avec l'id du patient : l'appelant redirige vers son dossier.
      Navigator.pop(context, patient.id);
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
          'Ordonnance numérique',
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
          children: [
            _buildPatientSelector(),
            const SizedBox(height: 16),
            _buildDateField(),
            const SizedBox(height: 16),
            _buildMedecinField(),
            const SizedBox(height: 24),
            _buildMedicamentsSection(),
            const SizedBox(height: 24),
            _buildRemarquesField(),
            const SizedBox(height: 28),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  /// Champ « Nom du patient ». Verrouillé (lecture seule) quand l'écran est
  /// ouvert depuis un dossier ; sinon touchable pour ouvrir le sélecteur.
  Widget _buildPatientSelector() {
    final patient = _patient;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nom du patient',
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
            onTap: _isSaving || _patientLocked ? null : _pickPatient,
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
                            style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                          )
                        : Text(
                            '${patient.nom} ${patient.prenom}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                  ),
                  if (!_patientLocked)
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

  Widget _buildDateField() {
    return TextFormField(
      controller: _dateController,
      readOnly: true,
      onTap: _isSaving ? null : _pickDate,
      decoration: InputDecoration(
        labelText: 'Date de l\'ordonnance',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.calendar_today_outlined),
      ),
    );
  }

  Widget _buildMedecinField() {
    return TextFormField(
      controller: _medecinController,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: 'Nom du médecin',
        hintText: 'Ex : Dr Benali',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.medical_information_outlined),
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null,
    );
  }

  Widget _buildMedicamentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Médicaments prescrits',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < _medicaments.length; i++) ...[
          _buildMedicamentCard(i),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: _isSaving ? null : _addMedicament,
          icon: const Icon(Icons.add),
          label: const Text('Ajouter un médicament'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _primary,
            side: BorderSide(color: _primary.withValues(alpha: 0.5)),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildMedicamentCard(int index) {
    final m = _medicaments[index];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Médicament ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
              // 1 médicament minimum : la suppression n'apparaît qu'au-delà.
              if (_medicaments.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red.shade400,
                  onPressed: _isSaving ? null : () => _removeMedicament(index),
                  tooltip: 'Supprimer ce médicament',
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: m.nom,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Nom du médicament',
              hintText: 'Ex : Paracétamol',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: m.dosage,
            decoration: InputDecoration(
              labelText: 'Dosage',
              hintText: 'Ex : 500 mg',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: m.posologie,
            decoration: InputDecoration(
              labelText: 'Posologie',
              hintText: 'Ex : 1 comprimé 3 fois par jour',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: m.duree,
            decoration: InputDecoration(
              labelText: 'Durée du traitement',
              hintText: 'Ex : 5 jours',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemarquesField() {
    return TextFormField(
      controller: _remarquesController,
      maxLines: 4,
      minLines: 2,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: 'Remarques ou conseils (optionnel)',
        hintText: 'Ex : à prendre pendant les repas',
        alignLabelWithHint: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.notes_outlined),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      onPressed: _isSaving ? null : _save,
      icon: _isSaving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.save_outlined),
      label: Text(_isSaving ? 'Enregistrement…' : 'Enregistrer l\'ordonnance'),
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

/// Contrôleurs des 4 champs d'une ligne médicament.
class _MedicamentControllers {
  final nom = TextEditingController();
  final dosage = TextEditingController();
  final posologie = TextEditingController();
  final duree = TextEditingController();

  void dispose() {
    nom.dispose();
    dosage.dispose();
    posologie.dispose();
    duree.dispose();
  }
}
