import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/bilan.dart';
import '../models/bilan_page.dart';
import '../models/valeur_biologique.dart';
import '../services/audit_service.dart';

/// Étape 5 du BILAN_PARSER_BRIEF : formulaire de correction d'un bilan
/// pré-rempli par le parser.
///
/// L'utilisateur peut :
/// - éditer les 4 métadonnées (date, labo, médecin, n° dossier)
/// - corriger / ajouter / supprimer des valeurs (tap = bottom sheet d'édition)
/// - confirmer → insertBilan transactionnel
///
/// Style aligné sur [PatientFormScreen] : Form + ListView, OutlineInputBorder,
/// bouton "Confirmer" plein largeur, SnackBar rouge en cas d'erreur.
class BilanFormScreen extends StatefulWidget {
  final int patientId;

  /// Bilan pré-rempli par [BilanParser.parse]. `null` = bilan vierge créé
  /// à la main (cas où l'OCR a totalement échoué).
  final Bilan? initialBilan;

  /// Pages scannées du bilan (cf. flux étape 6). Persistées telles quelles
  /// dans `bilan_pages` au moment de la confirmation. `null` ou vide accepté.
  final List<BilanPage>? pages;

  const BilanFormScreen({
    super.key,
    required this.patientId,
    this.initialBilan,
    this.pages,
  });

  @override
  State<BilanFormScreen> createState() => _BilanFormScreenState();
}

class _BilanFormScreenState extends State<BilanFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _dateExamenController;
  late final TextEditingController _laboratoireController;
  late final TextEditingController _medecinController;
  late final TextEditingController _numeroDossierController;

  /// Liste éditée localement. Modèle immutable → on remplace les objets
  /// entiers dans la liste plutôt que muter en place.
  late List<ValeurBiologique> _valeurs;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.initialBilan;

    _dateExamenController = TextEditingController(
      text: b?.dateExamen != null ? _isoToDdmmyyyy(b!.dateExamen!) : '',
    );
    _laboratoireController = TextEditingController(text: b?.laboratoire ?? '');
    _medecinController = TextEditingController(text: b?.medecinPrescripteur ?? '');
    _numeroDossierController = TextEditingController(text: b?.numeroDossier ?? '');

    _valeurs = List<ValeurBiologique>.from(b?.valeurs ?? const []);
  }

  @override
  void dispose() {
    _dateExamenController.dispose();
    _laboratoireController.dispose();
    _medecinController.dispose();
    _numeroDossierController.dispose();
    super.dispose();
  }

  // ── Helpers date ──────────────────────────────────────────────────────────

  String _isoToDdmmyyyy(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Parse DD/MM/AAAA → DateTime. Retourne null si vide OU mal formé (laissé
  /// au validator de prévenir la sauvegarde).
  DateTime? _parseDdmmyyyy(String s) {
    final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(s.trim());
    if (m == null) return null;
    return DateTime.tryParse('${m.group(3)}-${m.group(2)}-${m.group(1)}');
  }

  String? _dateValidator(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return null; // date optionnelle
    if (_parseDdmmyyyy(input) == null) return 'Format attendu : JJ/MM/AAAA';
    return null;
  }

  // ── Édition d'une valeur (bottom sheet) ───────────────────────────────────

  Future<void> _openValeurSheet({int? index}) async {
    final existing = index != null ? _valeurs[index] : null;
    final result = await showModalBottomSheet<ValeurBiologique>(
      context: context,
      isScrollControlled: true, // laisse la place au clavier
      useSafeArea: true,
      builder: (_) => _ValeurEditSheet(
        initial: existing,
        ordreSiNouvelle: _valeurs.length,
      ),
    );
    if (result == null) return;

    setState(() {
      if (index != null) {
        _valeurs[index] = result;
      } else {
        _valeurs.add(result);
      }
    });
  }

  void _supprimerValeur(int index) {
    setState(() {
      _valeurs.removeAt(index);
      // Réindexation `ordre` pour rester contigu (utile au tri à l'affichage).
      for (var i = 0; i < _valeurs.length; i++) {
        if (_valeurs[i].ordre != i) {
          _valeurs[i] = _cloneWith(_valeurs[i], ordre: i);
        }
      }
    });
  }

  /// Pas de copyWith dans le modèle (le brief insiste sur l'immutabilité) :
  /// on reconstruit la valeur ici quand on doit changer un seul champ.
  ValeurBiologique _cloneWith(ValeurBiologique v, {int? ordre}) {
    return ValeurBiologique(
      id: v.id,
      bilanId: v.bilanId,
      nom: v.nom,
      methode: v.methode,
      valeurNumerique: v.valeurNumerique,
      valeurTexte: v.valeurTexte,
      unite: v.unite,
      normeMin: v.normeMin,
      normeMax: v.normeMax,
      normeTexte: v.normeTexte,
      categorie: v.categorie,
      ordre: ordre ?? v.ordre,
    );
  }

  // ── Enregistrement ────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_valeurs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ajoute au moins une valeur biologique.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final bilan = Bilan(
        patientId: widget.patientId,
        dateExamen: _parseDdmmyyyy(_dateExamenController.text),
        laboratoire: _emptyToNull(_laboratoireController.text),
        medecinPrescripteur: _emptyToNull(_medecinController.text),
        numeroDossier: _emptyToNull(_numeroDossierController.text),
        texteOcrBrut: widget.initialBilan?.texteOcrBrut,
        valeurs: _valeurs,
        pages: widget.pages,
        createdAt: DateTime.now(),
      );

      final id = await DatabaseHelper.instance.insertBilan(bilan);

      final d = bilan.dateExamen;
      final dateLabel = d != null
          ? ' du ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}'
          : '';
      await AuditService.instance.logCreation(
        entityType: 'bilan',
        entityId: id,
        patientId: widget.patientId,
        description: 'Ajout d\'un bilan biologique$dateLabel',
      );

      if (!mounted) return;
      Navigator.pop(context, id);
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

  String? _emptyToNull(String s) => s.trim().isEmpty ? null : s.trim();

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vérification du bilan')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle('Informations du bilan'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dateExamenController,
              keyboardType: TextInputType.datetime,
              decoration: const InputDecoration(
                labelText: 'Date du prélèvement (JJ/MM/AAAA)',
                border: OutlineInputBorder(),
              ),
              validator: _dateValidator,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _laboratoireController,
              decoration: const InputDecoration(
                labelText: 'Laboratoire',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _medecinController,
              decoration: const InputDecoration(
                labelText: 'Médecin prescripteur',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _numeroDossierController,
              decoration: const InputDecoration(
                labelText: 'Numéro de dossier',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Valeurs biologiques (${_valeurs.length})'),
            const SizedBox(height: 8),
            if (_valeurs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Aucune valeur détectée. Ajoute-les manuellement.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            else
              ..._valeurs.asMap().entries.map(
                    (e) => _ValeurTile(
                      valeur: e.value,
                      onTap: () => _openValeurSheet(index: e.key),
                      onDelete: () => _supprimerValeur(e.key),
                    ),
                  ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _openValeurSheet(),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une valeur'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
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

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      );
}

/// Ligne compacte d'une valeur dans la liste. Tap → ouvre le sheet d'édition.
/// Bordure rouge si [ValeurBiologique.estHorsNorme] vaut true.
class _ValeurTile extends StatelessWidget {
  final ValeurBiologique valeur;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ValeurTile({
    required this.valeur,
    required this.onTap,
    required this.onDelete,
  });

  String _resume() {
    final v = valeur.valeurNumerique?.toString() ?? valeur.valeurTexte ?? '—';
    final u = valeur.unite ?? '';
    return u.isEmpty ? v : '$v $u';
  }

  String? _normeText() {
    if (valeur.normeMin != null && valeur.normeMax != null) {
      return '${valeur.normeMin} – ${valeur.normeMax}';
    }
    if (valeur.normeMax != null) return '< ${valeur.normeMax}';
    if (valeur.normeMin != null) return '> ${valeur.normeMin}';
    return valeur.normeTexte;
  }

  @override
  Widget build(BuildContext context) {
    final horsNorme = valeur.estHorsNorme;
    final norme = _normeText();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: horsNorme ? Colors.red : Colors.grey.shade300,
          width: horsNorme ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          valeur.nom,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Row(
          children: [
            Text(
              _resume(),
              style: TextStyle(
                color: horsNorme ? Colors.red : null,
                fontWeight: horsNorme ? FontWeight.w600 : null,
              ),
            ),
            if (norme != null) ...[
              const SizedBox(width: 12),
              Text(
                '(norme : $norme)',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          color: Colors.red.shade400,
          onPressed: onDelete,
          tooltip: 'Supprimer',
        ),
      ),
    );
  }
}

/// Bottom sheet d'édition d'une valeur. Pop avec la [ValeurBiologique]
/// reconstruite si l'utilisateur valide, null s'il annule.
class _ValeurEditSheet extends StatefulWidget {
  final ValeurBiologique? initial;
  final int ordreSiNouvelle;

  const _ValeurEditSheet({this.initial, required this.ordreSiNouvelle});

  @override
  State<_ValeurEditSheet> createState() => _ValeurEditSheetState();
}

class _ValeurEditSheetState extends State<_ValeurEditSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nom;
  late final TextEditingController _valeurNum;
  late final TextEditingController _valeurTxt;
  late final TextEditingController _unite;
  late final TextEditingController _normeMin;
  late final TextEditingController _normeMax;
  late final TextEditingController _normeTxt;
  late final TextEditingController _categorie;

  @override
  void initState() {
    super.initState();
    final v = widget.initial;
    _nom = TextEditingController(text: v?.nom ?? '');
    _valeurNum = TextEditingController(
      text: v?.valeurNumerique?.toString() ?? '',
    );
    _valeurTxt = TextEditingController(text: v?.valeurTexte ?? '');
    _unite = TextEditingController(text: v?.unite ?? '');
    _normeMin = TextEditingController(text: v?.normeMin?.toString() ?? '');
    _normeMax = TextEditingController(text: v?.normeMax?.toString() ?? '');
    _normeTxt = TextEditingController(text: v?.normeTexte ?? '');
    _categorie = TextEditingController(text: v?.categorie ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _nom, _valeurNum, _valeurTxt, _unite,
      _normeMin, _normeMax, _normeTxt, _categorie,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parseDouble(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  void _valider() {
    if (!_formKey.currentState!.validate()) return;

    final v = widget.initial;
    final result = ValeurBiologique(
      id: v?.id,
      bilanId: v?.bilanId ?? 0, // placeholder, DAO écrase à l'insert
      nom: _nom.text.trim(),
      methode: v?.methode, // pas exposé en v1 — préservé tel quel
      valeurNumerique: _parseDouble(_valeurNum.text),
      valeurTexte: _valeurTxt.text.trim().isEmpty ? null : _valeurTxt.text.trim(),
      unite: _unite.text.trim().isEmpty ? null : _unite.text.trim(),
      normeMin: _parseDouble(_normeMin.text),
      normeMax: _parseDouble(_normeMax.text),
      normeTexte: _normeTxt.text.trim().isEmpty ? null : _normeTxt.text.trim(),
      categorie: _categorie.text.trim().isEmpty ? null : _categorie.text.trim(),
      ordre: v?.ordre ?? widget.ordreSiNouvelle,
    );
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    // Padding inférieur dynamique pour ne pas être caché par le clavier.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEdit ? 'Modifier la valeur' : 'Nouvelle valeur',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nom,
                decoration: const InputDecoration(
                  labelText: "Nom de l'analyse",
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _valeurNum,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Valeur',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _unite,
                      decoration: const InputDecoration(
                        labelText: 'Unité',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _valeurTxt,
                decoration: const InputDecoration(
                  labelText: 'Valeur texte (si non numérique : "Absence", etc.)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _normeMin,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Norme min',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _normeMax,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Norme max',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _normeTxt,
                decoration: const InputDecoration(
                  labelText: 'Norme (texte libre, si non parsable)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categorie,
                decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  border: OutlineInputBorder(),
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
                      onPressed: _valider,
                      child: const Text('Valider'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
