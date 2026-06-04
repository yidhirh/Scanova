// lib/services/auth_service.dart
//
// Authentification 100 % locale (aucun serveur). Les comptes médecin sont
// stockés dans la table `users` de la base SQLite, le mot de passe haché.
//
// Hachage : SHA-256 salé et itéré (sel aléatoire de 16 octets par utilisateur,
// [_iterations] passes). Ce n'est pas bcrypt/argon2, mais c'est largement
// suffisant pour protéger un fichier de base local d'un usage mono-poste :
// on ne stocke jamais le mot de passe en clair et un sel par compte empêche
// les rainbow tables. La comparaison se fait en re-dérivant le hash.
//
// Session : « rester connecté » → on mémorise l'id de l'utilisateur courant
// dans SharedPreferences. L'app reste ouverte jusqu'à un logout() explicite.

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../models/user.dart';

/// Résultat d'une tentative de login / inscription.
enum AuthResult {
  success,
  invalidCredentials, // login : email inconnu ou mot de passe faux
  emailAlreadyUsed,   // inscription : email déjà pris
  unknownError,
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const String _sessionKey = 'auth_user_id';
  static const int _iterations = 50000;

  User? _currentUser;
  User? get currentUser => _currentUser;

  /// Rôle du compte connecté, `null` si déconnecté.
  UserRole? get currentRole => _currentUser?.role;

  // Raccourcis de permission — `false` si déconnecté. Définitions dans [UserRole].
  bool get canManageUsers => _currentUser?.role.canManageUsers ?? false;
  bool get canViewAudit => _currentUser?.role.canViewAudit ?? false;
  bool get canDeleteRecords => _currentUser?.role.canDeleteRecords ?? false;
  bool get canExportRecords => _currentUser?.role.canExportRecords ?? false;

  // ── Hachage ────────────────────────────────────────────────────────────

  String _generateSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// SHA-256 salé puis itéré [_iterations] fois.
  String _hashPassword(String password, String salt) {
    var digest = sha256.convert(utf8.encode('$salt$password'));
    for (var i = 1; i < _iterations; i++) {
      digest = sha256.convert(digest.bytes);
    }
    return digest.toString();
  }

  /// Comparaison à temps ~constant (évite de fuiter par timing).
  bool _slowEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  // ── État de l'app ──────────────────────────────────────────────────────

  /// Y a-t-il au moins un compte ? Sert à décider, au démarrage, entre
  /// l'écran d'inscription (premier lancement) et l'écran de connexion.
  Future<bool> hasAnyUser() async {
    return (await DatabaseHelper.instance.countUsers()) > 0;
  }

  /// Restaure la session « rester connecté » au lancement. Retourne true si
  /// un utilisateur valide a été retrouvé.
  Future<bool> tryRestoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_sessionKey);
    if (id == null) return false;
    final user = await DatabaseHelper.instance.getUserById(id);
    if (user == null) {
      await prefs.remove(_sessionKey); // session orpheline → on nettoie
      return false;
    }
    _currentUser = user;
    return true;
  }

  // ── Inscription / Connexion / Déconnexion ──────────────────────────────

  /// Inscription en libre-service (écran d'inscription).
  ///
  /// Attribution du rôle : le **tout premier compte** de l'appareil devient
  /// [UserRole.admin] (il configure l'app et gère les autres comptes). Les
  /// inscriptions ultérieures (lien « Créer un compte » de la connexion)
  /// reçoivent le rôle le moins privilégié [UserRole.archiviste] — seul un
  /// admin peut ensuite élever un compte. Connecte l'utilisateur si succès.
  Future<AuthResult> register({
    required String nomComplet,
    required String email,
    required String password,
  }) async {
    try {
      final dao = DatabaseHelper.instance;
      final normalizedEmail = email.trim().toLowerCase();

      if (await dao.getUserByEmail(normalizedEmail) != null) {
        return AuthResult.emailAlreadyUsed;
      }

      final isFirstAccount = (await dao.countUsers()) == 0;
      final role = isFirstAccount ? UserRole.admin : UserRole.archiviste;

      final salt = _generateSalt();
      final hash = _hashPassword(password, salt);
      final id = await dao.insertUser(User(
        nomComplet: nomComplet.trim(),
        email: normalizedEmail,
        passwordHash: hash,
        salt: salt,
        role: role,
      ));

      _currentUser = await dao.getUserById(id);
      await _persistSession(id);
      return AuthResult.success;
    } catch (_) {
      return AuthResult.unknownError;
    }
  }

  /// Création d'un compte par un **administrateur**, avec un rôle explicite
  /// (écran de gestion des utilisateurs). Ne modifie PAS la session courante :
  /// l'admin reste connecté. L'appelant doit vérifier [canManageUsers] en amont.
  Future<AuthResult> createUser({
    required String nomComplet,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    try {
      final dao = DatabaseHelper.instance;
      final normalizedEmail = email.trim().toLowerCase();

      if (await dao.getUserByEmail(normalizedEmail) != null) {
        return AuthResult.emailAlreadyUsed;
      }

      final salt = _generateSalt();
      final hash = _hashPassword(password, salt);
      await dao.insertUser(User(
        nomComplet: nomComplet.trim(),
        email: normalizedEmail,
        passwordHash: hash,
        salt: salt,
        role: role,
      ));
      return AuthResult.success;
    } catch (_) {
      return AuthResult.unknownError;
    }
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final dao = DatabaseHelper.instance;
      final user = await dao.getUserByEmail(email.trim().toLowerCase());
      if (user == null) return AuthResult.invalidCredentials;

      final hash = _hashPassword(password, user.salt);
      if (!_slowEquals(hash, user.passwordHash)) {
        return AuthResult.invalidCredentials;
      }

      _currentUser = user;
      await _persistSession(user.id!);
      return AuthResult.success;
    } catch (_) {
      return AuthResult.unknownError;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  Future<void> _persistSession(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sessionKey, userId);
  }
}
