// screens/patient_dossier_screen.dart — redesign
//
// Conserve toute la logique de chargement (Future.wait sur le DAO),
// _openBilan, _openAddDocument du fichier original. Le rendu est
// refait avec les widgets factorisés (PatientInfoCard, AppCard,
// EmptyState, ErrorState) et l'ajout d'un FloatingActionButton étendu.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/patient_info_card.dart';
import '../database/database_helper.dart';
import '../models/bilan.dart';
import '../models/medical_document.dart';
import '../models/patient.dart';
import 'add_document_screen.dart';
import 'bilan_viewer_screen.dart';
import 'document_viewer_screen.dart';

class PatientDossierScreen extends StatefulWidget {
  final int patientId;
  const PatientDossierScreen({super.key, required this.patientId});

  @override
  State<PatientDossierScreen> createState() => _PatientDossierScreenState();
}

class _PatientDossierScreenState extends State<PatientDossierScreen> {
  Patient? _patient;
  List<MedicalDocument> _documents = [];
  List<Bilan> _bilans = [];
  bool _isLoading = true;
  String? _error;

  /// Type de document affiché en exclusivité (ex: 'ordonnance', 'bilan').
  /// `null` = tous les types. Piloté par les cartes de « Répartition ».
  String? _typeFilter;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final dao = DatabaseHelper.instance;
      final results = await Future.wait([
        dao.getPatientById(widget.patientId),
        dao.getDocumentsByPatientId(widget.patientId),
        dao.getBilansByPatientId(widget.patientId),
      ]);
      if (!mounted) return;
      setState(() {
        _patient   = results[0] as Patient?;
        _documents = results[1] as List<MedicalDocument>;
        _bilans    = results[2] as List<Bilan>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _openAddDocument() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddDocumentScreen(patientId: widget.patientId)),
    );
    if (added == true) _loadData();
  }

  Future<void> _openBilan(int bilanId) async {
    final full = await DatabaseHelper.instance.getBilanById(bilanId);
    if (full == null || !mounted) return;
    final changed = await Navigator.push<bool>(
      context, MaterialPageRoute(builder: (_) => BilanViewerScreen(bilan: full)),
    );
    if (changed == true) _loadData();
  }

  Future<void> _openDocument(MedicalDocument doc) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DocumentViewerScreen(document: doc)),
    );
    if (changed == true) _loadData(); // document supprimé → rafraîchir
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '—';
    final parts = isoDate.split('-');
    if (parts.length != 3) return isoDate;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  /// Calcule l'âge en années révolues à partir d'une date ISO (YYYY-MM-DD).
  /// Retourne `null` si la date est manquante ou invalide.
  /// Tient compte du mois/jour pour ne pas surévaluer (ex: né en décembre,
  /// nous sommes en janvier → l'âge n'a pas encore été atteint cette année).
  int? _ageFromIso(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return null;
    final birth = DateTime.tryParse(isoDate);
    if (birth == null) return null;
    final now = DateTime.now();
    var age = now.year - birth.year;
    final hasHadBirthdayThisYear = (now.month > birth.month) ||
        (now.month == birth.month && now.day >= birth.day);
    if (!hasHadBirthdayThisYear) age -= 1;
    return age < 0 ? null : age;
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'ordonnance':    return Icons.medical_services_outlined;
      case 'ordonnance_numerique': return Icons.edit_note;
      case 'bilan':
      case 'analyse':       return Icons.science_outlined;
      case 'radio':
      case 'radiographie':  return Icons.image_outlined;
      case 'compte rendu':
      case 'compte_rendu':  return Icons.description_outlined;
      default:              return Icons.folder_outlined;
    }
  }

  String _labelForType(String type) {
    switch (type.toLowerCase()) {
      case 'ordonnance':    return 'Ordonnances';
      case 'ordonnance_numerique': return 'Ordonnances numériques';
      case 'bilan':
      case 'analyse':       return 'Bilans biologiques';
      case 'radio':
      case 'radiographie':  return 'Radiographies';
      case 'compte rendu':
      case 'compte_rendu':  return 'Comptes rendus';
      case 'autre':         return 'Autres';
      default:              return _capitalize(type);
    }
  }

  Color _colorForType(String type) {
    switch (type.toLowerCase()) {
      case 'ordonnance':
      case 'ordonnance_numerique': return AppColors.docOrdonnance;
      case 'bilan':
      case 'analyse':       return AppColors.docBilan;
      case 'radio':
      case 'radiographie':  return AppColors.docRadio;
      case 'compte rendu':
      case 'compte_rendu':  return AppColors.docCr;
      default:              return AppColors.docAutre;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink050,
      appBar: AppBar(
        title: const Text('Dossier patient'),
        backgroundColor: AppColors.brand600,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      floatingActionButton: _patient == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _openAddDocument,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un document'),
            ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorState(message: _error!, onRetry: _loadData);
    final p = _patient;
    if (p == null) return const EmptyState(icon: Icons.person_search, message: 'Patient introuvable.');

    final hasAny = _documents.isNotEmpty || _bilans.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          // ── Carte identité ────────────────────────────────
          PatientInfoCard(
            fullName: '${p.nom} ${p.prenom}',
            patientId: 'P-${p.id}',
            rows: [
              PatientInfoRow(icon: Icons.calendar_today_outlined, label: 'Né(e) le',        value: _formatDate(p.dateNaissance)),
              if (_ageFromIso(p.dateNaissance) != null)
                PatientInfoRow(icon: Icons.cake_outlined,         label: 'Âge',             value: '${_ageFromIso(p.dateNaissance)} ans'),
              if (_bilans.isNotEmpty)
                PatientInfoRow(icon: Icons.science_outlined,      label: 'Bilans',          value: '${_bilans.length}'),
              if (p.groupeSanguin != null && p.groupeSanguin!.isNotEmpty)
                PatientInfoRow(icon: Icons.bloodtype_outlined,    label: 'Groupe sanguin',  value: p.groupeSanguin!),
              if (p.numeroCni != null && p.numeroCni!.isNotEmpty)
                PatientInfoRow(icon: Icons.badge_outlined,        label: 'N° CNI',          value: p.numeroCni!),
              if (p.numeroSecuriteSociale != null && p.numeroSecuriteSociale!.isNotEmpty)
                PatientInfoRow(icon: Icons.credit_card_outlined,  label: 'N° Sécu',         value: p.numeroSecuriteSociale!),
            ],
          ),

          const SizedBox(height: 22),

          // ── Répartition par type (bilans inclus) ──────────
          // Chaque carte est tappable : elle filtre la liste sur son type.
          // Re-toucher la carte sélectionnée (ou « Tout afficher ») réinitialise.
          const _SectionTitle('Répartition des documents'),
          const SizedBox(height: 10),
          hasAny
              ? _buildStatsRow()
              : _buildEmptyHint('Aucun document pour ce patient'),

          const SizedBox(height: 22),

          // ── Documents groupés par type, filtrables ────────
          if (hasAny) ..._buildGroupedSections(),
        ],
      ),
    );
  }

  /// Comptage par type, bilans compris. Les bilans biologiques vivent dans une
  /// table dédiée (`_bilans`) : on les expose sous le type synthétique 'bilan'.
  Map<String, int> _typeCounts() {
    final counts = <String, int>{};
    for (final d in _documents) {
      // Sécurité : un éventuel document hérité de type 'bilan' ne doit pas
      // entrer en collision avec le groupe synthétique des bilans.
      if (d.typeDocument.toLowerCase() == 'bilan') continue;
      counts[d.typeDocument] = (counts[d.typeDocument] ?? 0) + 1;
    }
    if (_bilans.isNotEmpty) counts['bilan'] = _bilans.length;
    return counts;
  }

  /// Ordonne les types selon une priorité d'affichage stable, les types
  /// inattendus étant ajoutés à la fin par ordre alphabétique.
  List<String> _orderedTypes(Iterable<String> types) {
    const order = ['ordonnance', 'ordonnance_numerique', 'bilan', 'radio', 'compte rendu', 'autre'];
    final remaining = types.toSet();
    final result = [for (final t in order) if (remaining.remove(t)) t];
    result.addAll(remaining.toList()..sort());
    return result;
  }

  /// Filtre effectif : ignore un filtre devenu obsolète (ex: dernier document
  /// d'un type supprimé) en retombant sur « tous ».
  String? _effectiveFilter(Map<String, int> counts) =>
      (_typeFilter != null && counts.containsKey(_typeFilter)) ? _typeFilter : null;

  Widget _buildStatsRow() {
    final counts = _typeCounts();
    final types = _orderedTypes(counts.keys);
    final active = _effectiveFilter(counts);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: types.map((type) {
          final c = _colorForType(type);
          final selected = active == type;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              // Toggle : re-toucher la carte active réinitialise le filtre.
              onTap: () => setState(() => _typeFilter = selected ? null : type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: selected ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(
                    color: c.withValues(alpha: selected ? 1 : 0.30),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text('${counts[type]}',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c, height: 1)),
                    const SizedBox(height: 4),
                    Text(_labelForType(type),
                        style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Sections de documents groupées par type (et filtrées si un type est
  /// sélectionné via la répartition). Le groupe 'bilan' est alimenté par les
  /// bilans biologiques, les autres par les documents médicaux du type.
  List<Widget> _buildGroupedSections() {
    final counts = _typeCounts();
    final active = _effectiveFilter(counts);
    final types = active != null
        ? [active]
        : _orderedTypes(counts.keys);

    final widgets = <Widget>[];

    // Bandeau de filtre actif avec réinitialisation.
    if (active != null) {
      widgets.add(_buildFilterBanner(active));
      widgets.add(const SizedBox(height: 14));
    }

    for (final type in types) {
      widgets.add(_SectionTitle('${_labelForType(type)} (${counts[type]})'));
      widgets.add(const SizedBox(height: 10));
      if (type == 'bilan') {
        widgets.addAll(_bilans.map(_buildBilanTile));
      } else {
        widgets.addAll(
          _documents
              .where((d) => d.typeDocument == type)
              .map(_buildDocumentTile),
        );
      }
      widgets.add(const SizedBox(height: 22));
    }
    return widgets;
  }

  /// Bandeau indiquant le filtre actif + bouton « Tout afficher ».
  Widget _buildFilterBanner(String type) {
    final c = _colorForType(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: c.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(_iconForType(type), size: 18, color: c),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Filtré : ${_labelForType(type)}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c)),
          ),
          GestureDetector(
            onTap: () => setState(() => _typeFilter = null),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.close, size: 16, color: AppColors.ink500),
                const SizedBox(width: 4),
                Text('Tout afficher',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentTile(MedicalDocument doc) {
    final c = _colorForType(doc.typeDocument);
    final nbPages = doc.pages?.length ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.card,
      ),
      child: ListTile(
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Icon(_iconForType(doc.typeDocument), color: c, size: 22),
        ),
        title: Text(doc.titre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(
          '${_capitalize(doc.typeDocument.replaceAll('_', ' '))}  ·  ${_formatDate(doc.documentDate)}'
          '${nbPages > 1 ? '  ·  $nbPages pages' : ''}',
          style: const TextStyle(fontSize: 13, color: AppColors.ink500),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.ink400),
        onTap: () => _openDocument(doc),
      ),
    );
  }

  Widget _buildBilanTile(Bilan b) {
    final dateStr = b.dateExamen != null
        ? '${b.dateExamen!.day.toString().padLeft(2, '0')}/${b.dateExamen!.month.toString().padLeft(2, '0')}/${b.dateExamen!.year}'
        : '—';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.card,
      ),
      child: ListTile(
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: AppColors.docBilan.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: const Icon(Icons.science_outlined, color: AppColors.docBilan, size: 22),
        ),
        title: Text('Bilan du $dateStr', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(
          [dateStr, if (b.laboratoire != null && b.laboratoire!.isNotEmpty) b.laboratoire!].join('  ·  '),
          style: const TextStyle(fontSize: 13, color: AppColors.ink500),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.ink400),
        onTap: b.id != null ? () => _openBilan(b.id!) : null,
      ),
    );
  }

  Widget _buildEmptyHint(String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.ink500, fontSize: 14)),
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink900)),
      );
}
