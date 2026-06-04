// lib/screens/audit_log_screen.dart
//
// AuditLogScreen — journal d'audit global (traçabilité des accès).
//
// Ouvert depuis le menu latéral (AppDrawer). Liste les entrées de la table
// `audit_logs` (modifications + exports), du plus récent au plus ancien, via
// [DatabaseHelper.getAuditLogs]. Filtres par catégorie d'action :
//   - Tout
//   - Modifications  (créations + suppressions)
//   - Exports        (impression / PDF)
//
// Écran en lecture seule : c'est un registre, les lignes ne sont pas tappables.

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/audit_log.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/history_tile.dart' show formatRelativeTime;

/// Catégorie de filtre exposée à l'UI. `actions` donne les valeurs persistées
/// correspondantes (`null` = aucun filtre).
enum _AuditFilter {
  tout('Tout', null),
  modifications('Modifications', ['creation', 'modification', 'suppression']),
  exports('Exports', ['export']);

  const _AuditFilter(this.label, this.actions);
  final String label;
  final List<String>? actions;
}

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _primary = Color(0xFF2563EB);
  static const Color _ink200 = Color(0xFFE2E8F0);

  _AuditFilter _filter = _AuditFilter.tout;
  late Future<List<AuditLog>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AuditLog>> _load() {
    return DatabaseHelper.instance.getAuditLogs(actions: _filter.actions);
  }

  Future<void> _refresh() async {
    final fresh = _load();
    setState(() => _future = fresh);
    await fresh;
  }

  void _selectFilter(_AuditFilter f) {
    if (f == _filter) return;
    setState(() {
      _filter = f;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text("Journal d'audit", style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          const Divider(height: 1, color: _ink200),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final f in _AuditFilter.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f.label),
                  selected: _filter == f,
                  showCheckmark: false,
                  selectedColor: _primary,
                  backgroundColor: const Color(0xFFF1F5F9),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _filter == f ? Colors.white : const Color(0xFF475569),
                  ),
                  side: BorderSide(
                    color: _filter == f ? _primary : _ink200,
                  ),
                  onSelected: (_) => _selectFilter(f),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return FutureBuilder<List<AuditLog>>(
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
            icon: Icons.fact_check_outlined,
            message: 'Aucune action enregistrée pour ce filtre.',
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: entries.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, indent: 66, color: _ink200),
            itemBuilder: (_, i) => _AuditTile(entry: entries[i]),
          ),
        );
      },
    );
  }
}

/// Ligne du journal : pastille colorée selon l'action, libellé + acteur + date.
class _AuditTile extends StatelessWidget {
  final AuditLog entry;
  const _AuditTile({required this.entry});

  static const Color _ink900 = Color(0xFF0F172A);
  static const Color _ink500 = Color(0xFF64748B);

  ({IconData icon, Color color}) get _style => switch (entry.action) {
        AuditAction.creation =>
          (icon: Icons.add_circle_outline, color: const Color(0xFF16A34A)),
        AuditAction.modification =>
          (icon: Icons.edit_outlined, color: const Color(0xFFF59E0B)),
        AuditAction.suppression =>
          (icon: Icons.delete_outline, color: const Color(0xFFDC2626)),
        AuditAction.exportation =>
          (icon: Icons.print_outlined, color: const Color(0xFF2563EB)),
      };

  @override
  Widget build(BuildContext context) {
    final s = _style;
    final roleLabel = entry.roleLabel;
    final actor =
        roleLabel == null ? entry.actorLabel : '${entry.actorLabel} ($roleLabel)';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: s.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(s.icon, color: s.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _ink900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$actor · ${formatRelativeTime(entry.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: _ink500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
