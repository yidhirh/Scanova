// screens/patient_form_screen.dart — redesign
//
// Identique fonctionnellement à l'original : reçoit un PatientData
// pré-rempli par l'OCR, expose les champs adaptés au type de carte
// (CNI vs Chifa), persiste via DatabaseHelper, redirige vers le
// dossier. Aucune logique métier n'a été changée.
//
// Améliorations design :
//   - Bannière warning douce ("certains champs à vérifier")
//   - Pill source (CNI / Chifa) en tête
//   - Champs avec icône prefix, label en haut, indicateur "à vérifier"
//   - Dialog de confirmation avant création
//   - Dialog de doublon avec action "Ouvrir le dossier"

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import '../database/database_helper.dart';
import '../models/card_scan.dart';
import '../models/document_type.dart';
import '../models/patient.dart';
import '../models/patient_data.dart';
import '../services/audit_service.dart';
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

  bool _isSaving = false;

  bool get _isChifa => widget.initialData.sourceType == DocumentType.chifa;
  bool get _isCni   => widget.initialData.sourceType == DocumentType.cni;

  String get _numeroDocumentLabel {
    if (_isChifa) return 'Numéro de sécurité sociale';
    if (_isCni)   return 'Numéro CNI';
    return 'Numéro document';
  }

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _nomController             = TextEditingController(text: d.nom);
    _prenomController          = TextEditingController(text: d.prenom);
    _dateNaissanceController   = TextEditingController(text: d.dateNaissance);
    _numeroDocumentController  = TextEditingController(text: d.numeroDocument);
    _groupeSanguinController   = TextEditingController(text: d.groupeSanguin);
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

  Future<void> _tryConfirm() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await _confirmDialog();
    if (ok == true) _saveOrShowDuplicate();
  }

  /// Dialog de confirmation avant insertion. Récap des champs.
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
              _summary('Nom',          '${_nomController.text} ${_prenomController.text}'),
              _summary('Né(e) le',     _dateNaissanceController.text),
              if (!_isChifa)
                _summary('Groupe', _groupeSanguinController.text.isEmpty ? '—' : _groupeSanguinController.text),
              _summary(_numeroDocumentLabel, _numeroDocumentController.text),
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
      final numeroDocument = _numeroDocumentController.text.trim();
      final groupeSanguin = _isChifa ? '' : _groupeSanguinController.text.trim();

      final dao = DatabaseHelper.instance;
      final existing = await dao.findPatientByIdentity(
        nom: nom, prenom: prenom, dateNaissance: dateIso,
      );

      final bool isNewPatient = existing == null;
      int patientId;
      if (existing != null) {
        // Patient existant → on demande quoi faire avant d'ajouter le scan.
        if (!mounted) return;
        final choice = await _duplicateDialog(existing);
        if (choice == _DuplicateChoice.cancel) {
          setState(() => _isSaving = false);
          return;
        }
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

      final typeCarte = _isChifa ? 'CHIFA' : 'CNI';
      await dao.insertCardScan(CardScan(
        patientId: patientId,
        typeCarte: typeCarte,
        imagePath: widget.imagePath,
        ocrRawText: widget.ocrRawText,
      ));

      // Traçabilité : nouveau patient → création de dossier ; patient existant
      // → simple ajout d'une carte au dossier.
      if (isNewPatient) {
        await AuditService.instance.logCreation(
          entityType: 'patient',
          entityId: patientId,
          patientId: patientId,
          description: 'Création du patient $nom $prenom (carte $typeCarte)',
        );
      } else {
        await AuditService.instance.logCreation(
          entityType: 'scan',
          patientId: patientId,
          description: 'Ajout d\'une carte $typeCarte au dossier de $nom $prenom',
        );
      }

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

  Future<_DuplicateChoice> _duplicateDialog(Patient existing) async {
    final r = await showDialog<_DuplicateChoice>(
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
          "existant et y rattacher ce scan, ou annuler.",
        ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _DuplicateChoice.cancel),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, _DuplicateChoice.open),
            child: const Text('Ouvrir le dossier'),
          ),
        ],
      ),
    );
    return r ?? _DuplicateChoice.cancel;
  }

  @override
  Widget build(BuildContext context) {
    final hasWarnings = widget.initialData.champsAVerifier.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.ink050,
      appBar: AppBar(
        title: const Text('Vérification des données'),
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
                  label: _isSaving ? 'Enregistrement…' : 'Confirmer',
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
            if (hasWarnings) _buildWarningBanner(),
            const SizedBox(height: 18),
            _buildSourcePill(),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Nom',
              prefixIcon: Icons.person,
              controller: _nomController,
              validator: _requiredValidator,
              needsVerification: widget.initialData.doitVerifier('nom'),
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Prénom',
              prefixIcon: Icons.person_outline,
              controller: _prenomController,
              validator: _requiredValidator,
              needsVerification: widget.initialData.doitVerifier('prenom'),
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Date de naissance',
              prefixIcon: Icons.calendar_today,
              controller: _dateNaissanceController,
              keyboardType: TextInputType.datetime,
              validator: _dateValidator,
              hint: 'JJ/MM/AAAA',
              needsVerification: widget.initialData.doitVerifier('dateNaissance'),
            ),
            if (!_isChifa) ...[
              const SizedBox(height: 14),
              // Le BloodGroupPicker reste lié au controller existant : on lit/écrit
              // dans _groupeSanguinController.text pour garder TOUT le pipeline de
              // sauvegarde inchangé (le DAO insère ce que contient le controller).
              StatefulBuilder(
                builder: (context, setLocalState) => BloodGroupPicker(
                  value: _groupeSanguinController.text.trim(),
                  ocrDetected: widget.initialData.groupeSanguin.trim().isNotEmpty,
                  onChanged: (v) {
                    setLocalState(() => _groupeSanguinController.text = v);
                  },
                ),
              ),
            ],
            const SizedBox(height: 14),
            AppTextField(
              label: _numeroDocumentLabel,
              prefixIcon: _isChifa ? Icons.credit_card : Icons.badge,
              controller: _numeroDocumentController,
              keyboardType: TextInputType.number,
              validator: _requiredValidator,
              needsVerification: widget.initialData.doitVerifier('numeroDocument'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningBanner() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning500.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: AppColors.warning500),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning600),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Certains champs n'ont pas été détectés avec certitude. Vérifiez-les avant de confirmer.",
                style: TextStyle(fontSize: 13, color: AppColors.ink900, height: 1.4),
              ),
            ),
          ],
        ),
      );

  Widget _buildSourcePill() => Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.brand100,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_isChifa ? Icons.health_and_safety_outlined : Icons.credit_card,
                    size: 14, color: AppColors.brand700),
                const SizedBox(width: 6),
                Text(_isChifa ? 'CHIFA' : 'CNI',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brand700)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Données extraites par OCR',
            style: TextStyle(fontSize: 13, color: AppColors.ink500),
          ),
        ],
      );
}

enum _DuplicateChoice { cancel, open }

/// Sélecteur de groupe sanguin en chips (8 groupes ABO/Rh).
///
/// Logique :
///   - [value] vide → on affiche une pastille ambre "Non détecté · sélectionner"
///     pour expliquer pourquoi le sélecteur est là.
///   - [value] non vide → on présélectionne le chip correspondant. Si la
///     valeur n'est pas reconnue (ex: l'OCR a lu "O positif"), aucun chip
///     n'est sélectionné mais la valeur brute reste dans le controller.
///   - Re-tap d'un chip déjà sélectionné → désélectionne (utile quand le
///     patient ne connaît pas son groupe).
class BloodGroupPicker extends StatelessWidget {
  static const _groups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  final String value;            // ex: "O+", "" si rien
  final bool ocrDetected;        // utile pour afficher / masquer le badge ambre
  final ValueChanged<String> onChanged;

  const BloodGroupPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.ocrDetected = true,
  });

  bool get _showAmberBadge => !ocrDetected && value.isEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Groupe sanguin',
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A),
              ),
            ),
            if (_showAmberBadge) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 12, color: Color(0xFFD97706)),
                    SizedBox(width: 4),
                    Text(
                      'Non détecté · sélectionner',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        // Grille 4 × 2
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.0,
          children: _groups.map((g) {
            final isSelected = value == g;
            return _BloodChip(
              label: g,
              selected: isSelected,
              onTap: () => onChanged(isSelected ? '' : g),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _BloodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _BloodChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2563EB);
    return Material(
      color: selected ? primary : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? primary : const Color(0xFFCBD5E1),
              width: 1.5,
            ),
            boxShadow: selected
                ? [BoxShadow(color: primary.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }
}
