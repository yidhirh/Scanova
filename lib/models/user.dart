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
  final DateTime? createdAt;

  const User({
    this.id,
    required this.nomComplet,
    required this.email,
    required this.passwordHash,
    required this.salt,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nom_complet': nomComplet,
      'email': email,
      'password_hash': passwordHash,
      'salt': salt,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      nomComplet: (map['nom_complet'] as String?) ?? '',
      email: map['email'] as String,
      passwordHash: map['password_hash'] as String,
      salt: map['salt'] as String,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
    );
  }
}
