// screens/patient_manual_form_screen.dart
//
// Création d'un dossier patient SANS scan de carte (ni CNI ni Chifa).
// Cas d'usage : le médecin n'a aucune carte à disposition et saisit
// lui-même les informations personnelles du patient.
//
// À la différence de [PatientFormScreen] (alimenté par l'OCR), cet écran :
//   - ne reçoit aucune donnée pré-remplie ni image,
//   - n'insère AUCUN CardScan (le dossier n'a pas de scan rattaché),
//   - rend les numéros CNI / sécurité sociale facultatifs.
// La détection de doublon (nom + prénom + date de naissance) reste identique.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import '../database/database_helper.dart';
import '../models/patient.dart';
import 'patient_dossier_screen.dart';
import 'patient_form_screen.dart' show BloodGroupPicker;

class PatientManualFormScreen extends StatefulWidget {
  const PatientManualFormScreen({super.key});

  @override
  State<PatientManualFormScreen> createState() => _PatientManualFormScreenState();
}

class _PatientManualFormScreenState extends State<PatientManualFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _dateNaissanceController = TextEditingController();
  final _groupeSanguinController = TextEditingController();
  final _numeroCniController = TextEditingController();
  final _numeroSecuController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _dateNaissanceController.dispose();
    _groupeSanguinController.dispose();
    _numeroCniController.dispose();
    _numeroSecuController.dispose();
    super.dispose();
  }

  String _toIsoDate(String ddmmyyyy) {
    final parts = ddmmyyyy.split('/');
    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }

  String? _requiredValidator(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null;

  String? _dateValidator(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Champ obligatoire';
    final ok = RegExp(r'^(0[1-9]|[12][0-9]|3[01])\/(0[1-9]|1[0-2])\/((19|20)\d{2})$').hasMatch(s);
    return ok ? null : 'Format attendu : JJ/MM/AAAA';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Date de naissance',
    );
    if (picked == null) return;
    final dd = picked.day.toString().padLeft(2, '0');
    final mm = picked.month.toString().padLeft(2, '0');
    _dateNaissanceController.text = '$dd/$mm/${picked.year}';
  }

  Future<void> _tryConfirm() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await _confirmDialog();
    if (ok == true) _saveOrShowDuplicate();
  }

  Future<bool?> _confirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.xxl)),
        icon: Container(
          width: 56, height: 56,
          decoration: const BoxDecoration(color: Color(0x1F2563EB), shape: BoxShape.circle),
          child: const Icon(Icons.person_add, color: AppColors.brand600),
        ),
        title: const Text('Créer ce dossier patient ?'),
        content: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.ink050,
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _summary('Nom',      '${_nomController.text} ${_prenomController.text}'),
              _summary('Né(e) le', _dateNaissanceController.text),
              _summary('Groupe',   _groupeSanguinController.text.isEmpty ? '—' : _groupeSanguinController.text),
              if (_numeroCniController.text.trim().isNotEmpty)
                _summary('N° CNI', _numeroCniController.text),
              if (_numeroSecuController.text.trim().isNotEmpty)
                _summary('N° sécu.', _numeroSecuController.text),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Créer le dossier')),
        ],
      ),
    );
  }

  Widget _summary(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.ink500)),
            const Spacer(),
            Flexible(
              child: Text(value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink900)),
            ),
          ],
        ),
      );

  Future<void> _saveOrShowDuplicate() async {
    setState(() => _isSaving = true);

    try {
      final nom = _nomController.text.trim();
      final prenom = _prenomController.text.trim();
      final dateIso = _toIsoDate(_dateNaissanceController.text.trim());
      final groupeSanguin = _groupeSanguinController.text.trim();
      final numeroCni = _numeroCniController.text.trim();
      final numeroSecu = _numeroSecuController.text.trim();

      final dao = DatabaseHelper.instance;
      final existing = await dao.findPatientByIdentity(
        nom: nom, prenom: prenom, dateNaissance: dateIso,
      );

      if (existing != null) {
        // Un dossier existe déjà : on n'a pas de scan à rattacher ici,
        // on propose simplement d'ouvrir le dossier existant.
        if (!mounted) return;
        final open = await _duplicateDialog(existing);
        setState(() => _isSaving = false);
        if (open == true && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => PatientDossierScreen(patientId: existing.id!)),
          );
        }
        return;
      }

      final patientId = await dao.insertPatient(Patient(
        nom: nom,
        prenom: prenom,
        dateNaissance: dateIso,
        groupeSanguin: groupeSanguin.isNotEmpty ? groupeSanguin : null,
        numeroCni: numeroCni.isNotEmpty ? numeroCni : null,
        numeroSecuriteSociale: numeroSecu.isNotEmpty ? numeroSecu : null,
      ));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PatientDossierScreen(patientId: patientId)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de l'enregistrement : $e"), backgroundColor: AppColors.danger600),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool?> _duplicateDialog(Patient existing) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.xxl)),
        icon: Container(
          width: 56, height: 56,
          decoration: const BoxDecoration(color: Color(0x26F59E0B), shape: BoxShape.circle),
          child: const Icon(Icons.error_outline, color: AppColors.warning600),
        ),
        title: const Text('Patient déjà existant'),
        content: Text(
          "Un dossier existe déjà pour ${existing.nom} ${existing.prenom} "
          "(né(e) le ${existing.dateNaissance}). Vous pouvez ouvrir le dossier "
          "existant ou annuler.",
        ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ouvrir le dossier')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink050,
      appBar: AppBar(
        title: const Text('Nouveau dossier patient'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.ink900,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink900),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(top: BorderSide(color: AppColors.ink200)),
          ),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Annuler',
                  icon: Icons.close,
                  variant: AppButtonVariant.outline,
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: _isSaving ? 'Enregistrement…' : 'Créer le dossier',
                  icon: Icons.check,
                  loading: _isSaving,
                  onPressed: _isSaving ? null : _tryConfirm,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildInfoBanner(),
            const SizedBox(height: 18),
            AppTextField(
              label: 'Nom',
              prefixIcon: Icons.person,
              controller: _nomController,
              validator: _requiredValidator,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Prénom',
              prefixIcon: Icons.person_outline,
              controller: _prenomController,
              validator: _requiredValidator,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Date de naissance',
              prefixIcon: Icons.calendar_today,
              controller: _dateNaissanceController,
              keyboardType: TextInputType.datetime,
              validator: _dateValidator,
              hint: 'JJ/MM/AAAA',
              suffix: IconButton(
                icon: const Icon(Icons.event, size: 20),
                tooltip: 'Choisir une date',
                onPressed: _pickDate,
              ),
            ),
            const SizedBox(height: 14),
            StatefulBuilder(
              builder: (context, setLocalState) => BloodGroupPicker(
                value: _groupeSanguinController.text.trim(),
                ocrDetected: true, // pas d'OCR → on masque le badge "non détecté"
                onChanged: (v) {
                  setLocalState(() => _groupeSanguinController.text = v);
                },
              ),
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Numéro CNI (facultatif)',
              prefixIcon: Icons.badge,
              controller: _numeroCniController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Numéro de sécurité sociale (facultatif)',
              prefixIcon: Icons.credit_card,
              controller: _numeroSecuController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.brand100,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: AppColors.brand600.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.edit_note, color: AppColors.brand700),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Saisie manuelle, sans carte. Renseignez les informations du patient. "
                "Vous pourrez ajouter une carte plus tard depuis le dossier.",
                style: TextStyle(fontSize: 13, color: AppColors.ink900, height: 1.4),
              ),
            ),
          ],
        ),
      );
}
