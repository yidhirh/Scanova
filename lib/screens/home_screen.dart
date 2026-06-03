// lib/screens/home_screen.dart
//
// HomeScreen — Centre de numérisation médicale Scanova
//
// Refonte mai 2026.
//
// Cette Home se concentre sur l'action principale : SCANNER.
// La consultation des dossiers patients est accessible depuis l'onglet
// "Patients" de la BottomNavigationBar (MainNavigationScreen).
//
// Sections :
//   1. Header : "Bonjour 👋" + accroche + badge "OCR local · Données sécurisées"
//   2. Action principale : "Nouvelle numérisation" → DocumentTypeSelectionScreen
//   3. Documents traités récemment : 4 dernières entrées (CNI, Chifa, bilan…),
//      chargées depuis SQLite via DatabaseHelper.getRecentHistory.
//
// L'historique est rechargé : au premier affichage, à chaque retour sur
// l'onglet Accueil (via MainNavScope), après le flux de numérisation, et par
// pull-to-refresh.

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/history_entry.dart';
import '../widgets/app_drawer.dart';
import '../widgets/history_tile.dart';
import '../widgets/main_nav_scope.dart';
import 'add_document_screen.dart';
import 'advanced_search_screen.dart';
import 'document_type_selection_screen.dart';
import 'history_screen.dart';
import 'patient_dossier_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  // ── Palette locale ──
  static const Color _bg          = Color(0xFFF8FAFC);
  static const Color _primary     = Color(0xFF2563EB);
  static const Color _primaryDark = Color(0xFF1B4FBF);
  static const Color _success     = Color(0xFF16A34A);
  static const Color _ink900      = Color(0xFF0F172A);
  static const Color _ink700      = Color(0xFF334155);
  static const Color _ink500      = Color(0xFF64748B);
  static const Color _ink200      = Color(0xFFE2E8F0);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Nombre d'entrées affichées dans l'aperçu de la Home.
  static const int _previewCount = 4;

  List<HistoryEntry> _recent = const [];
  bool _loading = true;
  String? _error;

  /// Dernier index d'onglet observé, pour ne recharger que lorsqu'on
  /// (re)devient l'onglet Accueil (index 0).
  int? _lastTabIndex;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MainNavScope notifie via updateShouldNotify quand l'onglet change.
    // On recharge dès qu'on revient sur l'Accueil (ex: après un scan fait
    // depuis l'onglet "Scanner"), pour refléter les nouvelles numérisations.
    final index = MainNavScope.maybeOf(context)?.currentIndex;
    if (index != null && index != _lastTabIndex) {
      if (index == 0 && _lastTabIndex != null) {
        _loadRecent();
      }
      _lastTabIndex = index;
    }
  }

  Future<void> _loadRecent() async {
    try {
      final rows = await DatabaseHelper.instance.getRecentHistory(limit: _previewCount);
      if (!mounted) return;
      setState(() {
        _recent = rows.map((r) => HistoryEntry.fromMap(r)).toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _open(BuildContext context, Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    // Au retour (un scan a pu ajouter une entrée), on rafraîchit l'historique.
    if (mounted) _loadRecent();
  }

  void _openEntry(HistoryEntry e) {
    _open(context, PatientDossierScreen(patientId: e.patientId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeScreen._bg,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text(
          'Scanova',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: HomeScreen._primary,
        foregroundColor: HomeScreen._ink900,
        // Hamburger (leading) en blanc.
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            tooltip: 'Recherche avancée',
            onPressed: () => _open(context, const AdvancedSearchScreen()),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRecent,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // 1 ── HEADER ─────────────────────────────────────
            _buildHeader(),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 2 ── Action principale
                  _PrimaryActionCard(
                    onTap: () => _open(context, const DocumentTypeSelectionScreen()),
                  ),

                  const SizedBox(height: 12),

                  // 2bis ── Ajouter un document à un dossier patient
                  // (scan d'une ordonnance / bilan / compte rendu… puis choix
                  // du dossier patient cible).
                  _SecondaryActionCard(
                    icon: Icons.note_add_outlined,
                    title: 'Ajouter un document',
                    subtitle: 'Scanner une ordonnance, un bilan ou un compte rendu et le classer dans un dossier',
                    onTap: () => _open(context, const AddDocumentScreen()),
                  ),

                  // 3 ── Documents traités récemment
                  const _SectionLabel(title: 'Documents traités récemment'),
                  _RecentDocsCard(
                    entries: _recent,
                    loading: _loading,
                    error: _error,
                    onTapEntry: _openEntry,
                    onSeeAll: () => _open(context, const HistoryScreen()),
                    onRetry: _loadRecent,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFFEAF2FE), HomeScreen._bg],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -90, right: -40,
            child: _RadialBlob(
              size: 180,
              color: HomeScreen._primary.withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            bottom: -60, left: -30,
            child: _RadialBlob(
              size: 120,
              color: HomeScreen._success.withValues(alpha: 0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text.rich(
                TextSpan(children: [
                  TextSpan(text: 'Bonjour '),
                  TextSpan(text: '👋'),
                ]),
                style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700, color: HomeScreen._ink900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Centre de numérisation médicale',
                style: TextStyle(fontSize: 14, color: HomeScreen._ink500, height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
                decoration: BoxDecoration(
                  color: HomeScreen._primary.withValues(alpha: 0.10),
                  border: Border.all(color: HomeScreen._primary.withValues(alpha: 0.22)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, size: 14, color: HomeScreen._primary),
                    SizedBox(width: 6),
                    Text(
                      'OCR local · Données sécurisées',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Sous-widgets ─────────────────────────────────────────

class _RadialBlob extends StatelessWidget {
  final double size;
  final Color color;
  const _RadialBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0, 0.7],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Text(title,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: HomeScreen._ink700)),
    );
  }
}

/// Grande carte CTA — gradient bleu, ombre marquée.
class _PrimaryActionCard extends StatelessWidget {
  final VoidCallback onTap;
  const _PrimaryActionCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [HomeScreen._primary, HomeScreen._primaryDark],
            ),
            boxShadow: [
              BoxShadow(
                color: HomeScreen._primary.withValues(alpha: 0.30),
                blurRadius: 28, offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                top: -50, right: -50,
                child: Container(
                  width: 180, height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.20),
                        Colors.white.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.7],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 54, height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.document_scanner_outlined,
                        color: Colors.white, size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nouvelle numérisation',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800)),
                          SizedBox(height: 2),
                          Text(
                            'Scanner une CNI, une carte Chifa ou un document médical',
                            style: TextStyle(
                                color: Color(0xE0FFFFFF),
                                fontSize: 13, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte d'action secondaire — fond blanc, icône en pastille bleue.
/// Utilisée pour « Ajouter un document » (scan + classement dans un dossier).
class _SecondaryActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SecondaryActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: HomeScreen._ink200),
            boxShadow: [
              BoxShadow(
                color: HomeScreen._ink900.withValues(alpha: 0.05),
                blurRadius: 10, offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: HomeScreen._primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: HomeScreen._primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: HomeScreen._ink900,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              color: HomeScreen._ink500,
                              fontSize: 12.5, height: 1.35)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward, color: HomeScreen._primary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Liste des derniers documents traités (CNI, Chifa, bilan, ordonnance…),
/// alimentée par [DatabaseHelper.getRecentHistory]. Gère les états
/// chargement / erreur / vide / liste.
class _RecentDocsCard extends StatelessWidget {
  final List<HistoryEntry> entries;
  final bool loading;
  final String? error;
  final void Function(HistoryEntry) onTapEntry;
  final VoidCallback onSeeAll;
  final VoidCallback onRetry;

  const _RecentDocsCard({
    required this.entries,
    required this.loading,
    required this.error,
    required this.onTapEntry,
    required this.onSeeAll,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: HomeScreen._ink900.withValues(alpha: 0.05),
            blurRadius: 10, offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            const Icon(Icons.cloud_off, color: HomeScreen._ink500, size: 32),
            const SizedBox(height: 10),
            const Text(
              "Impossible de charger l'historique.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: HomeScreen._ink500),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, color: HomeScreen._ink500, size: 32),
            SizedBox(height: 10),
            Text(
              'Aucune numérisation pour le moment.\nVotre historique apparaîtra ici.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: HomeScreen._ink500, height: 1.4),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < entries.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: HomeScreen._ink200),
          HistoryTile(entry: entries[i], onTap: () => onTapEntry(entries[i])),
        ],
        Material(
          color: HomeScreen._bg,
          child: InkWell(
            onTap: onSeeAll,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: HomeScreen._ink200)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Voir tout l'historique",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: HomeScreen._primary,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward, size: 16, color: HomeScreen._primary),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
