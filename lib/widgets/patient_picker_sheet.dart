// lib/widgets/patient_picker_sheet.dart
//
// Sélecteur de dossier patient — modal bottom sheet avec recherche.
//
// Utilisé quand on numérise un document SANS être déjà dans un dossier
// (ex: depuis la Home « Ajouter un document »). Le médecin scanne d'abord,
// puis choisit ici le patient auquel rattacher le document.
//
// Usage :
//   final patient = await PatientPickerSheet.show(context);
//   if (patient != null) { ... }
//
// Retourne le [Patient] choisi, ou `null` si l'utilisateur ferme la feuille.

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/patient.dart';

class PatientPickerSheet extends StatefulWidget {
  const PatientPickerSheet({super.key});

  /// Ouvre le sélecteur et retourne le patient choisi (ou `null` si annulé).
  static Future<Patient?> show(BuildContext context) {
    return showModalBottomSheet<Patient>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const PatientPickerSheet(),
    );
  }

  @override
  State<PatientPickerSheet> createState() => _PatientPickerSheetState();
}

class _PatientPickerSheetState extends State<PatientPickerSheet> {
  static const Color _primary = Color(0xFF2563EB);

  final TextEditingController _searchController = TextEditingController();

  List<Patient> _patients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final patients = await DatabaseHelper.instance.getAllPatients();
    if (!mounted) return;
    setState(() {
      _patients = patients;
      _isLoading = false;
    });
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    setState(() => _isLoading = true);
    final results = trimmed.isEmpty
        ? await DatabaseHelper.instance.getAllPatients()
        : await DatabaseHelper.instance.searchPatients(trimmed);
    if (!mounted) return;
    setState(() {
      _patients = results;
      _isLoading = false;
    });
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '—';
    final parts = isoDate.split('-');
    if (parts.length != 3) return isoDate;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  String _initials(Patient p) {
    final n = p.nom.isNotEmpty ? p.nom[0] : '';
    final pr = p.prenom.isNotEmpty ? p.prenom[0] : '';
    return '$n$pr'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    // La feuille occupe ~80% de la hauteur — assez pour parcourir la liste.
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choisir le dossier patient',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: _search,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'Rechercher un patient…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _search('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_patients.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              _searchController.text.isEmpty
                  ? 'Aucun patient enregistré'
                  : 'Aucun résultat pour "${_searchController.text}"',
              style: TextStyle(color: Colors.grey[500], fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _patients.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final patient = _patients[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: _primary.withValues(alpha: 0.12),
              child: Text(
                _initials(patient),
                style: const TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            title: Text(
              '${patient.nom} ${patient.prenom}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Color(0xFF0F172A),
              ),
            ),
            subtitle: Text(
              patient.age != null
                  ? 'Né(e) le ${_formatDate(patient.dateNaissance)}  ·  ${patient.age} ans'
                  : 'Né(e) le ${_formatDate(patient.dateNaissance)}',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
            onTap: () => Navigator.pop(context, patient),
          ),
        );
      },
    );
  }
}
