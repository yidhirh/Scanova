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
      case 'bilan':
      case 'analyse':       return Icons.science_outlined;
      case 'radio':
      case 'radiographie':  return Icons.image_outlined;
      case 'compte rendu':
      case 'compte_rendu':  return Icons.description_outlined;
      default:              return Icons.folder_outlined;
    }
  }

  Color _colorForType(String type) {
    switch (type.toLowerCase()) {
      case 'ordonnance':    return AppColors.docOrdonnance;
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

          // ── Stats par type ────────────────────────────────
          const _SectionTitle('Répartition des documents'),
          const SizedBox(height: 10),
          _documents.isEmpty
              ? _buildEmptyHint('Aucun document pour ce patient')
              : _buildStatsRow(),

          const SizedBox(height: 22),

          // ── Bilans ────────────────────────────────────────
          if (_bilans.isNotEmpty) ...[
            _SectionTitle('Bilans biologiques (${_bilans.length})'),
            const SizedBox(height: 10),
            ..._bilans.map(_buildBilanTile),
            const SizedBox(height: 22),
          ],

          // ── Documents ─────────────────────────────────────
          _SectionTitle('Documents (${_documents.length})'),
          const SizedBox(height: 10),
          _documents.isEmpty
              ? _buildEmptyHint('Aucun document')
              : Column(children: _documents.map(_buildDocumentTile).toList()),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final counts = <String, int>{};
    for (final d in _documents) {
      counts[d.typeDocument] = (counts[d.typeDocument] ?? 0) + 1;
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: counts.entries.map((e) {
          final c = _colorForType(e.key);
          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: c.withValues(alpha: 0.30)),
            ),
            child: Column(
              children: [
                Text('${e.value}',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c, height: 1)),
                const SizedBox(height: 4),
                Text(_capitalize(e.key),
                    style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }).toList(),
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
          '${_capitalize(doc.typeDocument)}  ·  ${_formatDate(doc.documentDate)}'
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
