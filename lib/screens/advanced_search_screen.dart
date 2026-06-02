// lib/screens/advanced_search_screen.dart
//
// Écran de recherche Scanova — barre de recherche unique (nom de patient
// ou mot-clé) + filtres rapides en chips + liste de résultats.
//
// Recherche RÉELLE sur la base locale SQLite via les méthodes publiques du
// DatabaseHelper (lecture seule, aucune logique métier modifiée) :
//   - Patients  : nom / prénom contiennent la requête.
//   - Documents : titre / type contiennent la requête, ou le patient matche.
//   - Bilans    : laboratoire / médecin contiennent la requête, ou le patient.
//
// La recherche se lance en temps réel à chaque frappe (avec un léger debounce
// pour ne pas saturer la base), ainsi qu'au changement de filtre.

import 'dart:async';

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/bilan.dart';
import '../models/medical_document.dart';
import '../models/patient.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import 'bilan_viewer_screen.dart';
import 'document_viewer_screen.dart';
import 'patient_dossier_screen.dart';

class AdvancedSearchScreen extends StatefulWidget {
  const AdvancedSearchScreen({super.key});

  @override
  State<AdvancedSearchScreen> createState() => _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends State<AdvancedSearchScreen> {
  static const List<String> _filters = [
    'Tous',
    'Patients',
    'Bilans',
    'Ordonnances',
    'Radios',
    'Comptes rendus',
  ];

  final TextEditingController _controller = TextEditingController();
  String _filter = 'Tous';
  String _query = ''; // texte courant (pour le bouton effacer)

  bool _loading = false;
  bool _hasSearched = false;
  List<_Result> _results = const [];

  Timer? _debounce; // anti-rebond de la recherche temps réel

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ── Recherche ─────────────────────────────────────────────

  /// Appelé à chaque frappe : relance la recherche après un court délai
  /// afin de ne pas parcourir la base à chaque caractère.
  void _onQueryChanged(String value) {
    setState(() => _query = value.trim());
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _runSearch);
  }

  Future<void> _runSearch() async {
    final q = _controller.text.trim();
    if (q.isEmpty) {
      setState(() {
        _results = const [];
        _hasSearched = false;
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _hasSearched = true;
    });

    final ql = q.toLowerCase();
    final dao = DatabaseHelper.instance;
    final out = <_Result>[];

    try {
      final patients = await dao.getAllPatients();

      final wantPatients = _filter == 'Tous' || _filter == 'Patients';
      final wantDocs = _filter == 'Tous' ||
          _filter == 'Ordonnances' ||
          _filter == 'Radios' ||
          _filter == 'Comptes rendus';
      final wantBilans = _filter == 'Tous' || _filter == 'Bilans';

      for (final p in patients) {
        final fullName = '${p.nom} ${p.prenom}';
        final nameMatch = fullName.toLowerCase().contains(ql);

        if (wantPatients && nameMatch) {
          out.add(_Result(
            kind: _Kind.patient,
            patient: p,
            icon: Icons.person_outline,
            color: AppColors.brand600,
            title: fullName,
            subtitle: _patientSubtitle(p),
          ));
        }

        if (wantDocs && p.id != null) {
          final docs = await dao.getDocumentsByPatientId(p.id!);
          for (final d in docs) {
            if (!_docMatchesFilter(d.typeDocument, _filter)) continue;
            final ocrMatch = (d.pages ?? const [])
                .any((pg) => (pg.ocrText ?? '').toLowerCase().contains(ql));
            final match = nameMatch ||
                d.titre.toLowerCase().contains(ql) ||
                d.typeDocument.toLowerCase().contains(ql) ||
                ocrMatch;
            if (match) out.add(_docResult(p, d, ocrMatch: ocrMatch));
          }
        }

        if (wantBilans && p.id != null) {
          final bilans = await dao.getBilansByPatientId(p.id!);
          for (final b in bilans) {
            final ocrMatch = (b.texteOcrBrut ?? '').toLowerCase().contains(ql);
            final match = nameMatch ||
                (b.laboratoire ?? '').toLowerCase().contains(ql) ||
                (b.medecinPrescripteur ?? '').toLowerCase().contains(ql) ||
                'bilan biologique'.contains(ql) ||
                ocrMatch;
            if (match) out.add(_bilanResult(p, b, ocrMatch: ocrMatch));
          }
        }
      }
    } catch (_) {
      // Lecture seule : en cas d'erreur on retombe sur une liste vide.
    }

    if (!mounted) return;
    setState(() {
      _results = out;
      _loading = false;
    });
  }

  bool _docMatchesFilter(String type, String filter) {
    final t = type.toLowerCase();
    switch (filter) {
      case 'Ordonnances':
        return t.contains('ordonnance');
      case 'Radios':
        return t.contains('radio');
      case 'Comptes rendus':
        return t.contains('compte');
      default:
        return true; // Tous
    }
  }

  _Result _docResult(Patient p, MedicalDocument d, {bool ocrMatch = false}) {
    final date = _formatIso(d.documentDate);
    final parts = <String>[
      _capitalize(d.typeDocument),
      '${p.nom} ${p.prenom}',
      if (date != '—') date,
      if (ocrMatch) 'texte OCR',
    ];
    return _Result(
      kind: _Kind.document,
      patient: p,
      document: d,
      icon: _iconForType(d.typeDocument),
      color: _colorForType(d.typeDocument),
      title: d.titre,
      subtitle: parts.join(' · '),
    );
  }

  _Result _bilanResult(Patient p, Bilan b, {bool ocrMatch = false}) {
    final date = _formatDate(b.dateExamen);
    final parts = <String>[
      '${p.nom} ${p.prenom}',
      if (date != '—') date,
      if (ocrMatch) 'texte OCR',
    ];
    return _Result(
      kind: _Kind.bilan,
      patient: p,
      bilan: b,
      icon: Icons.science_outlined,
      color: AppColors.docBilan,
      title: 'Bilan biologique',
      subtitle: parts.join(' · '),
    );
  }

  Future<void> _open(_Result r) async {
    switch (r.kind) {
      case _Kind.patient:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PatientDossierScreen(patientId: r.patient!.id!),
          ),
        );
        break;
      case _Kind.document:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentViewerScreen(document: r.document!),
          ),
        );
        break;
      case _Kind.bilan:
        final full = await DatabaseHelper.instance.getBilanById(r.bilan!.id!);
        if (full == null || !mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BilanViewerScreen(bilan: full)),
        );
        break;
    }
  }

  // ── Helpers d'affichage ───────────────────────────────────

  String _patientSubtitle(Patient p) {
    final d = _formatIso(p.dateNaissance);
    return d == '—' ? 'Patient' : 'Patient · né(e) le $d';
  }

  String _formatIso(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '—';
    final parts = isoDate.split('-');
    if (parts.length != 3) return isoDate;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

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
        return AppColors.docOrdonnance;
      case 'bilan':
      case 'analyse':
        return AppColors.docBilan;
      case 'radio':
      case 'radiographie':
        return AppColors.docRadio;
      case 'compte rendu':
      case 'compte_rendu':
        return AppColors.docCr;
      default:
        return AppColors.docAutre;
    }
  }

  // ── UI ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink050,
      appBar: AppBar(
        title: const Text(
          'Rechercher',
          style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink900),
        ),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.ink900,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink900),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchField(),
                const SizedBox(height: 12),
                _buildFilterChips(),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.ink200),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _controller,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onChanged: _onQueryChanged,
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      decoration: InputDecoration(
        hintText: 'Nom du patient ou mot-clé…',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _query.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Effacer',
                onPressed: () {
                  _debounce?.cancel();
                  _controller.clear();
                  setState(() {
                    _query = '';
                    _results = const [];
                    _hasSearched = false;
                  });
                },
              )
            : null,
        filled: true,
        fillColor: AppColors.ink050,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.brand600, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = _filters[i];
          final selected = _filter == f;
          return ChoiceChip(
            label: Text(f),
            selected: selected,
            onSelected: (_) {
              setState(() => _filter = f);
              if (_controller.text.trim().isNotEmpty) _runSearch();
            },
            showCheckmark: false,
            backgroundColor: AppColors.white,
            selectedColor: AppColors.brand100,
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.brand700 : AppColors.ink500,
            ),
            side: BorderSide(color: selected ? AppColors.brand600 : AppColors.ink300),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          );
        },
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_hasSearched) {
      return const EmptyState(
        icon: Icons.search,
        message: 'Saisissez un nom de patient ou un mot-clé\npour lancer la recherche.',
      );
    }
    if (_results.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        message: 'Aucun résultat pour cette recherche.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _results.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '${_results.length} résultat${_results.length > 1 ? 's' : ''}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink500,
              ),
            ),
          );
        }
        return _buildResultTile(_results[index - 1]);
      },
    );
  }

  Widget _buildResultTile(_Result r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.card,
      ),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: r.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Icon(r.icon, color: r.color, size: 22),
        ),
        title: Text(
          r.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text(
          r.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: AppColors.ink500),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.ink400),
        onTap: () => _open(r),
      ),
    );
  }
}

enum _Kind { patient, document, bilan }

class _Result {
  final _Kind kind;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Patient? patient;
  final MedicalDocument? document;
  final Bilan? bilan;

  const _Result({
    required this.kind,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.patient,
    this.document,
    this.bilan,
  });
}
