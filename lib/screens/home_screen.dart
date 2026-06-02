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
//   3. Documents traités récemment : 4 dernières entrées (CNI, Chifa, bilan…)
//
// ⚠️ Les valeurs de "Documents traités récemment" sont simulées pour
// l'instant. Pour les brancher à SQLite, voir le commentaire TODO
// dans _RecentDocsCard plus bas.
//
// Aucune route métier modifiée. Aucun service OCR / parser / DAO touché.

import 'package:flutter/material.dart';

import '../widgets/app_drawer.dart';
import 'advanced_search_screen.dart';
import 'document_type_selection_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // ── Palette locale ──
  static const Color _bg          = Color(0xFFF8FAFC);
  static const Color _primary     = Color(0xFF2563EB);
  static const Color _primaryDark = Color(0xFF1B4FBF);
  static const Color _success     = Color(0xFF16A34A);
  static const Color _ink900      = Color(0xFF0F172A);
  static const Color _ink700      = Color(0xFF334155);
  static const Color _ink500      = Color(0xFF64748B);
  static const Color _ink400      = Color(0xFF94A3B8);
  static const Color _ink200      = Color(0xFFE2E8F0);

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text(
          'Scanova',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: _primary,
        foregroundColor: _ink900,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: _ink700),
            tooltip: 'Recherche avancée',
            onPressed: () => _open(context, const AdvancedSearchScreen()),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
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

                // 3 ── Documents traités récemment
                const _SectionLabel(title: 'Documents traités récemment'),
                _RecentDocsCard(
                  onSeeAll: () {
                    // TODO: ouvrir l'écran "historique" quand il existera
                  },
                ),
              ],
            ),
          ),
        ],
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
          colors: [Color(0xFFEAF2FE), _bg],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -90, right: -40,
            child: _RadialBlob(
              size: 180,
              color: _primary.withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            bottom: -60, left: -30,
            child: _RadialBlob(
              size: 120,
              color: _success.withValues(alpha: 0.12),
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
                  fontSize: 24, fontWeight: FontWeight.w700, color: _ink900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Centre de numérisation médicale',
                style: TextStyle(fontSize: 14, color: _ink500, height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.10),
                  border: Border.all(color: _primary.withValues(alpha: 0.22)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, size: 14, color: _primary),
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

/// Liste des derniers documents traités (CNI, Chifa, bilan, ordonnance…).
/// ⚠️ Données simulées. Pour brancher au DAO, requête type :
///   SELECT type_carte AS type, titre AS title, p.nom || ' ' || p.prenom AS patient,
///          created_at
///     FROM card_scans cs JOIN patients p ON p.id = cs.patient_id
///     UNION ALL
///   SELECT type_document, titre, p.nom || ' ' || p.prenom, created_at
///     FROM medical_documents md JOIN patients p ON p.id = md.patient_id
///     ORDER BY created_at DESC LIMIT 5;
class _RecentDocsCard extends StatelessWidget {
  final VoidCallback onSeeAll;
  const _RecentDocsCard({required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    const items = <_RecentDocItem>[
      _RecentDocItem(type: 'chifa',      title: 'Carte Chifa',
                     patient: 'Benali Salim',   time: 'il y a 4 min'),
      _RecentDocItem(type: 'bilan',      title: 'Bilan biologique · 8 valeurs',
                     patient: 'Djebbar Meriem', time: 'il y a 27 min'),
      _RecentDocItem(type: 'cni',        title: "Carte d'identité",
                     patient: 'Kaci Amine',     time: 'il y a 1 h'),
      _RecentDocItem(type: 'ordonnance', title: 'Ordonnance Dr. Saidi',
                     patient: 'Hadji Omar',     time: 'il y a 3 h'),
    ];

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
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: HomeScreen._ink200),
            _RecentDocRow(item: items[i]),
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
      ),
    );
  }
}

class _RecentDocItem {
  final String type;     // 'cni' | 'chifa' | 'bilan' | 'ordonnance' | 'radio'
  final String title;
  final String patient;
  final String time;
  const _RecentDocItem({
    required this.type,
    required this.title,
    required this.patient,
    required this.time,
  });
}

class _RecentDocRow extends StatelessWidget {
  final _RecentDocItem item;
  const _RecentDocRow({required this.item});

  /// Mapping type → (icône, couleur) — cohérent avec les autres écrans.
  ({IconData icon, Color color}) _style() {
    switch (item.type) {
      case 'cni':
        return (icon: Icons.credit_card, color: const Color(0xFF2563EB));
      case 'chifa':
        return (icon: Icons.health_and_safety_outlined, color: const Color(0xFF16A34A));
      case 'bilan':
        return (icon: Icons.science_outlined, color: const Color(0xFF16A34A));
      case 'ordonnance':
        return (icon: Icons.medical_services_outlined, color: const Color(0xFF2563EB));
      case 'radio':
        return (icon: Icons.image_outlined, color: const Color(0xFF9333EA));
      default:
        return (icon: Icons.description_outlined, color: const Color(0xFF64748B));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style();
    return InkWell(
      onTap: () {
        // TODO: ouvrir le document / le bilan / le scan original
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
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
                  Text(item.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: HomeScreen._ink900,
                      )),
                  const SizedBox(height: 1),
                  Text('${item.patient} · ${item.time}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: HomeScreen._ink500,
                      )),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: HomeScreen._ink400, size: 20),
          ],
        ),
      ),
    );
  }
}
