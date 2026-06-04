// lib/widgets/app_drawer.dart
//
// Menu latéral (Drawer) partagé par les onglets principaux. Accès
// SECONDAIRE : la BottomNavigationBar reste la navigation principale.
//
// Contenu :
//   - En-tête Scanova (badge + nom + sous-titre)
//   - Accueil / Scanner / Patients  → basculent l'onglet actif (via MainNavScope)
//   - Recherche avancée             → ouvre AdvancedSearchScreen
//   - À propos                      → showAboutDialog
//
// Style cohérent avec AppTheme / AppColors.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../models/user.dart';
import '../screens/advanced_search_screen.dart';
import '../screens/audit_log_screen.dart';
import '../screens/login_screen.dart';
import '../screens/user_management_screen.dart';
import '../services/auth_service.dart';
import 'main_nav_scope.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _switchTab(BuildContext context, int index) {
    Navigator.pop(context); // ferme le Drawer
    MainNavScope.of(context).goToTab(index);
  }

  void _openAdvancedSearch(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdvancedSearchScreen()),
    );
  }

  void _openAuditLog(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AuditLogScreen()),
    );
  }

  void _openUserManagement(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserManagementScreen()),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.xxl)),
        title: const Text('Se déconnecter ?'),
        content: const Text('Vous devrez ressaisir votre mot de passe pour revenir.'),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger600),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await AuthService.instance.logout();
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _openAbout(BuildContext context) {
    Navigator.pop(context);
    showAboutDialog(
      context: context,
      applicationName: 'Scanova',
      applicationVersion: '1.0.0',
      applicationIcon: const _BrandBadge(size: 44),
      children: const [
        Text(
          'Numérisation intelligente des dossiers médicaux. '
          'OCR local, données stockées sur l\'appareil.',
          style: TextStyle(fontSize: 13, color: AppColors.ink700, height: 1.45),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = MainNavScope.maybeOf(context)?.currentIndex ?? 0;

    return Drawer(
      backgroundColor: AppColors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _DrawerHeader(),
            const SizedBox(height: 8),
            _DrawerItem(
              icon: Icons.home_outlined,
              label: 'Accueil',
              selected: current == 0,
              onTap: () => _switchTab(context, 0),
            ),
            _DrawerItem(
              icon: Icons.document_scanner_outlined,
              label: 'Scanner',
              selected: current == 1,
              onTap: () => _switchTab(context, 1),
            ),
            _DrawerItem(
              icon: Icons.people_outline,
              label: 'Patients',
              selected: current == 2,
              onTap: () => _switchTab(context, 2),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(height: 1, color: AppColors.ink200),
            ),
            _DrawerItem(
              icon: Icons.search,
              label: 'Recherche avancée',
              onTap: () => _openAdvancedSearch(context),
            ),
            // Réservés à l'administrateur (cf. UserRole.canManageUsers / canViewAudit).
            if (AuthService.instance.canManageUsers)
              _DrawerItem(
                icon: Icons.manage_accounts_outlined,
                label: 'Gestion des utilisateurs',
                onTap: () => _openUserManagement(context),
              ),
            if (AuthService.instance.canViewAudit)
              _DrawerItem(
                icon: Icons.fact_check_outlined,
                label: "Journal d'audit",
                onTap: () => _openAuditLog(context),
              ),
            _DrawerItem(
              icon: Icons.info_outline,
              label: 'À propos',
              onTap: () => _openAbout(context),
            ),
            _DrawerItem(
              icon: Icons.logout,
              label: 'Déconnexion',
              onTap: () => _logout(context),
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Scanova · version 1.0.0',
                style: TextStyle(fontSize: 12, color: AppColors.ink400),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final subtitle = user == null
        ? 'Numérisation médicale'
        : (user.nomComplet.isNotEmpty ? user.nomComplet : user.email);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: const BoxDecoration(
        color: AppColors.brand050,
        border: Border(bottom: BorderSide(color: AppColors.ink200)),
      ),
      child: Row(
        children: [
          const _BrandBadge(size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Scanova',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: AppColors.ink500),
                ),
                if (user != null) ...[
                  const SizedBox(height: 6),
                  _RolePill(role: user.role),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandBadge extends StatelessWidget {
  final double size;
  const _BrandBadge({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.brand600,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.brandGlow,
      ),
      child: Icon(
        Icons.document_scanner_outlined,
        color: AppColors.white,
        size: size * 0.5,
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        selected: selected,
        selectedColor: AppColors.brand700,
        selectedTileColor: AppColors.brand050,
        iconColor: selected ? AppColors.brand700 : AppColors.ink500,
        textColor: selected ? AppColors.brand700 : AppColors.ink900,
        leading: Icon(icon),
        title: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Pastille colorée indiquant le rôle du compte connecté (en-tête du Drawer).
class _RolePill extends StatelessWidget {
  final UserRole role;
  const _RolePill({required this.role});

  ({Color color, IconData icon}) get _style => switch (role) {
        UserRole.admin =>
          (color: const Color(0xFF7C3AED), icon: Icons.shield_outlined),
        UserRole.medecin =>
          (color: const Color(0xFF16A34A), icon: Icons.medical_services_outlined),
        UserRole.archiviste =>
          (color: const Color(0xFF64748B), icon: Icons.inventory_2_outlined),
      };

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: s.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 12, color: s.color),
          const SizedBox(width: 4),
          Text(
            role.label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: s.color),
          ),
        ],
      ),
    );
  }
}
