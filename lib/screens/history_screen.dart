// lib/screens/history_screen.dart
//
// HistoryScreen — historique complet des numérisations (toutes sources).
//
// Ouvert depuis « Voir tout l'historique » sur la Home. Liste toutes les
// entrées (cartes, documents, bilans) du plus récent au plus ancien via
// [DatabaseHelper.getRecentHistory]. Un tap ouvre le dossier du patient
// concerné.

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/history_entry.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/history_tile.dart';
import 'patient_dossier_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _primary = Color(0xFF2563EB);
  static const Color _ink200 = Color(0xFFE2E8F0);

  late Future<List<HistoryEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<HistoryEntry>> _load() async {
    // null => sans limite : l'historique complet.
    final rows = await DatabaseHelper.instance.getRecentHistory(limit: null);
    return rows.map((r) => HistoryEntry.fromMap(r)).toList();
  }

  Future<void> _refresh() async {
    final fresh = _load();
    setState(() => _future = fresh);
    await fresh;
  }

  void _openEntry(HistoryEntry e) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PatientDossierScreen(patientId: e.patientId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Historique', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<List<HistoryEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorState(message: snapshot.error.toString(), onRetry: _refresh);
          }
          final entries = snapshot.data ?? const [];
          if (entries.isEmpty) {
            return const EmptyState(
              icon: Icons.history,
              message: 'Aucune numérisation pour le moment.',
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: entries.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 66, color: _ink200),
              itemBuilder: (_, i) => HistoryTile(
                entry: entries[i],
                onTap: () => _openEntry(entries[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}
