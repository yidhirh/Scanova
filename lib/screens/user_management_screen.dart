// lib/screens/user_management_screen.dart
//
// UserManagementScreen — gestion des comptes et des rôles.
//
// Réservé à l'administrateur (entrée affichée dans l'AppDrawer seulement si
// [AuthService.canManageUsers]). Permet de :
//   - lister les comptes avec leur rôle ;
//   - créer un nouveau compte en choisissant son rôle ;
//   - changer le rôle d'un compte (sauf le sien, pour éviter de se verrouiller
//     hors de l'administration).
//
// Chaque action (création, changement de rôle) est journalisée dans le journal
// d'audit via [AuditService].

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/user.dart';
import '../services/audit_service.dart';
import '../services/auth_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';

/// Couleur + icône associées à un rôle (cohérent avec la pastille du Drawer).
({Color color, IconData icon}) _roleStyle(UserRole role) => switch (role) {
      UserRole.admin =>
        (color: const Color(0xFF7C3AED), icon: Icons.shield_outlined),
      UserRole.medecin =>
        (color: const Color(0xFF16A34A), icon: Icons.medical_services_outlined),
      UserRole.archiviste =>
        (color: const Color(0xFF64748B), icon: Icons.inventory_2_outlined),
    };

String _roleDescription(UserRole role) => switch (role) {
      UserRole.admin => 'Tout + gestion des comptes + journal d\'audit',
      UserRole.medecin => 'Créer, supprimer, exporter',
      UserRole.archiviste => 'Créer et consulter (ni suppression ni export)',
    };

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _primary = Color(0xFF2563EB);

  late Future<List<User>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<User>> _load() => DatabaseHelper.instance.getAllUsers();

  Future<void> _reload() async {
    final fresh = _load();
    setState(() => _future = fresh);
    await fresh;
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openCreate() async {
    final created = await showModalBottomSheet<({String nom, UserRole role})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _UserFormSheet(),
    );
    if (created == null) return;
    await AuditService.instance.logCreation(
      entityType: 'user',
      description: 'Création du compte ${created.nom} (${created.role.label})',
    );
    _snack('Compte « ${created.nom} » créé.');
    await _reload();
  }

  Future<void> _changeRole(User user) async {
    final currentId = AuthService.instance.currentUser?.id;
    if (user.id == currentId) {
      _snack('Vous ne pouvez pas modifier votre propre rôle.', error: true);
      return;
    }

    final newRole = await showModalBottomSheet<UserRole>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RolePickerSheet(current: user.role),
    );
    if (newRole == null || newRole == user.role) return;

    await DatabaseHelper.instance.updateUserRole(user.id!, newRole.value);
    final label = user.nomComplet.isNotEmpty ? user.nomComplet : user.email;
    await AuditService.instance.logModification(
      entityType: 'user',
      entityId: user.id,
      description: 'Rôle de $label défini sur ${newRole.label}',
    );
    _snack('Rôle de « $label » mis à jour : ${newRole.label}.');
    await _reload();
  }

  /// Réinitialise le mot de passe d'un compte (action d'administration). L'app
  /// étant locale et sans e-mail, l'admin saisit directement le nouveau mot de
  /// passe, qu'il communiquera à l'utilisateur (à changer ensuite).
  Future<void> _resetPassword(User user) async {
    final label = user.nomComplet.isNotEmpty ? user.nomComplet : user.email;
    final newPassword = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ResetPasswordSheet(userName: label),
    );
    if (newPassword == null) return;

    final result = await AuthService.instance.resetUserPassword(
      userId: user.id!,
      newPassword: newPassword,
    );
    if (result != AuthResult.success) {
      _snack('Échec de la réinitialisation. Réessayez.', error: true);
      return;
    }
    // On journalise l'action SANS jamais consigner le mot de passe.
    await AuditService.instance.logModification(
      entityType: 'user',
      entityId: user.id,
      description: 'Réinitialisation du mot de passe de $label',
    );
    _snack('Mot de passe de « $label » réinitialisé.');
  }

  @override
  Widget build(BuildContext context) {
    final currentId = AuthService.instance.currentUser?.id;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Gestion des utilisateurs',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nouvel utilisateur'),
      ),
      body: FutureBuilder<List<User>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorState(message: snapshot.error.toString(), onRetry: _reload);
          }
          final users = snapshot.data ?? const [];
          if (users.isEmpty) {
            return const EmptyState(
              icon: Icons.group_outlined,
              message: 'Aucun compte enregistré.',
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: users.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _UserCard(
                user: users[i],
                isCurrent: users[i].id == currentId,
                onChangeRole: () => _changeRole(users[i]),
                onResetPassword: () => _resetPassword(users[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final User user;
  final bool isCurrent;
  final VoidCallback onChangeRole;
  final VoidCallback onResetPassword;

  const _UserCard({
    required this.user,
    required this.isCurrent,
    required this.onChangeRole,
    required this.onResetPassword,
  });

  @override
  Widget build(BuildContext context) {
    final s = _roleStyle(user.role);
    final name = user.nomComplet.isNotEmpty ? user.nomComplet : user.email;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: s.color.withValues(alpha: 0.12),
          child: Icon(s.icon, color: s.color, size: 20),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
            ),
            if (isCurrent) ...[
              const SizedBox(width: 6),
              const Text('(vous)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ],
        ),
        subtitle: Text(
          user.email,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RoleChip(role: user.role),
            PopupMenuButton<_UserAction>(
              icon: const Icon(Icons.more_vert, color: Color(0xFF64748B)),
              tooltip: 'Actions',
              onSelected: (action) => switch (action) {
                _UserAction.changeRole => onChangeRole(),
                _UserAction.resetPassword => onResetPassword(),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _UserAction.changeRole,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.badge_outlined),
                    title: Text('Changer le rôle'),
                  ),
                ),
                PopupMenuItem(
                  value: _UserAction.resetPassword,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.lock_reset_outlined),
                    title: Text('Réinitialiser le mot de passe'),
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: onChangeRole,
      ),
    );
  }
}

/// Actions disponibles sur une carte utilisateur (menu « ⋮ »).
enum _UserAction { changeRole, resetPassword }

class _RoleChip extends StatelessWidget {
  final UserRole role;
  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    final s = _roleStyle(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        role.label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: s.color),
      ),
    );
  }
}

/// Feuille de sélection d'un rôle (changement de rôle d'un compte existant).
class _RolePickerSheet extends StatelessWidget {
  final UserRole current;
  const _RolePickerSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'Choisir un rôle',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
          ),
          for (final role in UserRole.values)
            ListTile(
              leading: Icon(_roleStyle(role).icon, color: _roleStyle(role).color),
              title: Text(role.label, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(_roleDescription(role), style: const TextStyle(fontSize: 12)),
              trailing: role == current
                  ? const Icon(Icons.check, color: Color(0xFF2563EB))
                  : null,
              onTap: () => Navigator.pop(context, role),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Formulaire de création d'un compte (nom, email, mot de passe, rôle).
/// Renvoie via `Navigator.pop` un enregistrement `(nom, role)` en cas de succès.
class _UserFormSheet extends StatefulWidget {
  const _UserFormSheet();

  @override
  State<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<_UserFormSheet> {
  static const Color _primary = Color(0xFF2563EB);
  static const Color _border = Color(0xFFCBD5E1);
  static const Color _muted = Color(0xFF64748B);

  final _nom = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.archiviste;
  bool _obscure = true;
  bool _saving = false;

  @override
  void dispose() {
    _nom.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFDC2626)),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final nom = _nom.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    final emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');

    if (nom.isEmpty) {
      _error('Veuillez saisir un nom.');
      return;
    }
    if (!emailRegex.hasMatch(email)) {
      _error('Adresse email invalide.');
      return;
    }
    if (password.length < 6) {
      _error('Le mot de passe doit contenir au moins 6 caractères.');
      return;
    }

    setState(() => _saving = true);
    final result = await AuthService.instance.createUser(
      nomComplet: nom,
      email: email,
      password: password,
      role: _role,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (result == AuthResult.success) {
      Navigator.pop<({String nom, UserRole role})>(context, (nom: nom, role: _role));
    } else if (result == AuthResult.emailAlreadyUsed) {
      _error('Un compte existe déjà avec cet email.');
    } else {
      _error('Erreur lors de la création du compte. Réessayez.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Nouvel utilisateur',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 16),
          _field(controller: _nom, hint: 'Nom complet', icon: Icons.person_outline),
          const SizedBox(height: 12),
          _field(
            controller: _email,
            hint: 'Email',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _field(
            controller: _password,
            hint: 'Mot de passe (6 caractères min.)',
            icon: Icons.lock_outline,
            obscure: _obscure,
            onToggleObscure: () => setState(() => _obscure = !_obscure),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<UserRole>(
            initialValue: _role,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.badge_outlined, color: _muted),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
            ),
            items: [
              for (final role in UserRole.values)
                DropdownMenuItem(
                  value: role,
                  child: Text('${role.label} — ${_roleDescription(role)}',
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (r) => setState(() => _role = r ?? _role),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF93C5FD),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Créer le compte',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    VoidCallback? onToggleObscure,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: _muted),
        suffixIcon: onToggleObscure != null
            ? IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: _muted,
                ),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
      ),
    );
  }
}

/// Feuille de saisie d'un nouveau mot de passe (réinitialisation admin).
/// Renvoie via `Navigator.pop` le nouveau mot de passe en cas de validation.
class _ResetPasswordSheet extends StatefulWidget {
  final String userName;
  const _ResetPasswordSheet({required this.userName});

  @override
  State<_ResetPasswordSheet> createState() => _ResetPasswordSheetState();
}

class _ResetPasswordSheetState extends State<_ResetPasswordSheet> {
  static const Color _primary = Color(0xFF2563EB);
  static const Color _border = Color(0xFFCBD5E1);
  static const Color _muted = Color(0xFF64748B);

  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFDC2626)),
    );
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    final pwd = _password.text;
    if (pwd.length < 6) {
      _error('Le mot de passe doit contenir au moins 6 caractères.');
      return;
    }
    if (pwd != _confirm.text) {
      _error('Les deux mots de passe ne correspondent pas.');
      return;
    }
    Navigator.pop(context, pwd);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Réinitialiser le mot de passe',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          Text(
            'Définissez un nouveau mot de passe pour « ${widget.userName} », '
            'puis communiquez-le-lui. Il pourra le changer ensuite.',
            style: const TextStyle(fontSize: 13, color: _muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          _field(
            controller: _password,
            hint: 'Nouveau mot de passe (6 caractères min.)',
            obscure: _obscure,
            onToggleObscure: () => setState(() => _obscure = !_obscure),
          ),
          const SizedBox(height: 12),
          _field(
            controller: _confirm,
            hint: 'Confirmer le mot de passe',
            obscure: _obscure,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Réinitialiser',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.lock_outline, color: _muted),
        suffixIcon: onToggleObscure != null
            ? IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: _muted,
                ),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
      ),
    );
  }
}
