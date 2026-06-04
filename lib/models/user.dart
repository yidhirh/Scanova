/// Rôle d'un compte, déterminant ses permissions dans l'app.
///
/// **Rappel** : l'app étant 100 % locale (mono-poste), ces permissions sont un
/// garde-fou d'usage (UX) et non une barrière de sécurité opposable — quiconque
/// a accès au fichier de base peut les contourner.
///
/// Matrice :
///   - admin      : tout + gestion des comptes + journal d'audit
///   - medecin    : métier complet (créer, supprimer, exporter), pas d'admin
///   - archiviste : créer + consulter + rechercher, mais NI suppression NI export
enum UserRole {
  admin('admin', 'Administrateur'),
  medecin('medecin', 'Médecin'),
  archiviste('archiviste', 'Archiviste');

  const UserRole(this.value, this.label);

  /// Valeur persistée en base (colonne `users.role`).
  final String value;

  /// Libellé affiché à l'utilisateur.
  final String label;

  /// Repli défensif sur [medecin] pour une valeur inconnue/absente.
  static UserRole fromString(String? s) => switch (s) {
        'admin' => UserRole.admin,
        'archiviste' => UserRole.archiviste,
        _ => UserRole.medecin,
      };

  // ── Permissions (cf. matrice ci-dessus) ───────────────────────────────────

  /// Gérer les comptes et leurs rôles. Réservé à l'administrateur.
  bool get canManageUsers => this == UserRole.admin;

  /// Consulter le journal d'audit. Réservé à l'administrateur.
  bool get canViewAudit => this == UserRole.admin;

  /// Supprimer un document / un bilan. Admin et médecin uniquement.
  bool get canDeleteRecords => this == UserRole.admin || this == UserRole.medecin;

  /// Exporter / imprimer un document ou un bilan (PDF). Admin et médecin.
  bool get canExportRecords => this == UserRole.admin || this == UserRole.medecin;
}

/// Compte médecin stocké localement (table `users`).
///
/// Le mot de passe n'est JAMAIS stocké en clair : on conserve uniquement
/// [passwordHash] (dérivé par SHA-256 salé et itéré) et [salt] (sel aléatoire
/// propre à chaque utilisateur). La vérification se fait en re-dérivant le
/// hash à partir du mot de passe saisi et du sel, puis en comparant.
class User {
  final int? id;
  final String nomComplet;
  final String email;
  final String passwordHash;
  final String salt;

  /// Rôle du compte (permissions). Par défaut [UserRole.medecin].
  final UserRole role;

  final DateTime? createdAt;

  const User({
    this.id,
    required this.nomComplet,
    required this.email,
    required this.passwordHash,
    required this.salt,
    this.role = UserRole.medecin,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nom_complet': nomComplet,
      'email': email,
      'password_hash': passwordHash,
      'salt': salt,
      'role': role.value,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      nomComplet: (map['nom_complet'] as String?) ?? '',
      email: map['email'] as String,
      passwordHash: map['password_hash'] as String,
      salt: map['salt'] as String,
      role: UserRole.fromString(map['role'] as String?),
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
    );
  }
}
