import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/medical_document.dart';
import '../models/patient.dart';
import 'add_document_screen.dart';
import 'document_viewer_screen.dart';

class PatientDossierScreen extends StatefulWidget {
  final int patientId;

  const PatientDossierScreen({super.key, required this.patientId});

  @override
  State<PatientDossierScreen> createState() => _PatientDossierScreenState();
}

class _PatientDossierScreenState extends State<PatientDossierScreen> {
  static const Color _primary = Color(0xFF2563EB);
  static const Color _background = Color(0xFFF8FAFC);

  Patient? _patient;
  List<MedicalDocument> _documents = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _openAddDocument() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddDocumentScreen(patientId: widget.patientId),
      ),
    );
    if (added == true) _loadData();
  }

  Future<void> _loadData() async {
    try {
      final dao = DatabaseHelper.instance;
      final results = await Future.wait([
        dao.getPatientById(widget.patientId),
        dao.getDocumentsByPatientId(widget.patientId),
      ]);

      if (!mounted) return;
      setState(() {
        _patient = results[0] as Patient?;
        _documents = results[1] as List<MedicalDocument>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Convertit YYYY-MM-DD (SQLite) en DD/MM/YYYY (affichage).
  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '—';
    final parts = isoDate.split('-');
    if (parts.length != 3) return isoDate;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'ordonnance':
        return Icons.medical_services_outlined;
      case 'bilan':
      case 'analyse':
        return Icons.science_outlined;
      case 'radio':
      case 'radiographie':
        return Icons.image_outlined;
      case 'compte rendu':
      case 'compte_rendu':
        return Icons.description_outlined;
      default:
        return Icons.folder_outlined;
    }
  }

  Color _colorForType(String type) {
    switch (type.toLowerCase()) {
      case 'ordonnance':
        return Colors.blue;
      case 'bilan':
      case 'analyse':
        return Colors.green;
      case 'radio':
      case 'radiographie':
        return Colors.purple;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          'Dossier patient',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(),
      floatingActionButton: _patient == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _openAddDocument,
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un document'),
            ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Text(
          'Erreur : $_error',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (_patient == null) {
      return const Center(child: Text('Patient introuvable.'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPatientCard(),
          const SizedBox(height: 20),
          _buildDocumentStats(),
          const SizedBox(height: 20),
          _buildDocumentList(),
        ],
      ),
    );
  }

  // ── Carte identité ──────────────────────────────────────────────────────

  Widget _buildPatientCard() {
    final p = _patient!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: _primary.withValues(alpha: 0.12),
            child: const Icon(Icons.person, color: _primary, size: 40),
          ),
          const SizedBox(height: 12),
          Text(
            '${p.nom} ${p.prenom}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'P-${p.id}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.calendar_today_outlined, 'Né(e) le', _formatDate(p.dateNaissance)),
          _buildInfoRow(Icons.folder_outlined, 'Documents', '${_documents.length}'),
          if (p.groupeSanguin != null && p.groupeSanguin!.isNotEmpty)
            _buildInfoRow(Icons.bloodtype_outlined, 'Groupe sanguin', p.groupeSanguin!),
          if (p.numeroCni != null && p.numeroCni!.isNotEmpty)
            _buildInfoRow(Icons.badge_outlined, 'N° CNI', p.numeroCni!),
          if (p.numeroSecuriteSociale != null && p.numeroSecuriteSociale!.isNotEmpty)
            _buildInfoRow(Icons.credit_card_outlined, 'N° Sécu', p.numeroSecuriteSociale!),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _primary),
          const SizedBox(width: 10),
          Text(
            '$label : ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Répartition des documents ───────────────────────────────────────────

  Widget _buildDocumentStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Répartition des documents',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        _documents.isEmpty
            ? _buildEmptyHint('Aucun document pour ce patient')
            : _buildStatsRow(),
      ],
    );
  }

  Widget _buildStatsRow() {
    final counts = <String, int>{};
    for (final doc in _documents) {
      counts[doc.typeDocument] = (counts[doc.typeDocument] ?? 0) + 1;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: counts.entries.map((e) {
          final color = _colorForType(e.key);
          return Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.30)),
            ),
            child: Column(
              children: [
                Text(
                  '${e.value}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _capitalize(e.key),
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Liste des documents ─────────────────────────────────────────────────

  Widget _buildDocumentList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Documents (${_documents.length})',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        _documents.isEmpty
            ? _buildEmptyHint('Aucun document')
            : Column(
                children: _documents
                    .map((doc) => _buildDocumentTile(doc))
                    .toList(),
              ),
      ],
    );
  }

  Widget _buildDocumentTile(MedicalDocument doc) {
    final color = _colorForType(doc.typeDocument);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_iconForType(doc.typeDocument), color: color, size: 22),
        ),
        title: Text(
          doc.titre,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          '${_capitalize(doc.typeDocument)}  ·  ${_formatDate(doc.documentDate)}',
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DocumentViewerScreen(document: doc),
            ),
          );
        },
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  Widget _buildEmptyHint(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey[500], fontSize: 14),
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
