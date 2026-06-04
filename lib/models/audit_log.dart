// lib/models/audit_log.dart
//
// AuditLog — entrée du journal d'audit (table `audit_logs`).
//
// Trace QUI a fait QUOI et QUAND, pour la traçabilité et l'audit des accès aux
// données médicales. Couvre pour l'instant les MODIFICATIONS (créations +
// suppressions) et les EXPORTS (impression/PDF). Les consultations en lecture
// ne sont pas encore journalisées — l'enum [AuditAction.fromString] est conçue
// pour accueillir une valeur `consultation` sans migration le jour venu.
//
// Choix d'immutabilité : aucune clé étrangère vers `users`/`patients`. L'identité
// de l'acteur est DÉNORMALISÉE (snapshot email + nom au moment de l'action) et le
// nom du patient est figé dans [description]. Une entrée d'audit survit donc à la
// suppression de l'utilisateur ou du patient concerné.

import 'user.dart';

/// Nature de l'action journalisée. La chaîne stockée en base est donnée par
/// [value] ; [fromString] est défensif (valeur inconnue → repli sur création).
enum AuditAction {
  creation,
  modification,
  suppression,
  exportation;

  /// Valeur persistée en colonne `action`.
  String get value => switch (this) {
        AuditAction.creation => 'creation',
        AuditAction.modification => 'modification',
        AuditAction.suppression => 'suppression',
        AuditAction.exportation => 'export',
      };

  static AuditAction fromString(String? s) => switch (s) {
        'modification' => AuditAction.modification,
        'suppression' => AuditAction.suppression,
        'export' => AuditAction.exportation,
        _ => AuditAction.creation,
      };
}

class AuditLog {
  final int? id;

  /// Acteur : id du compte médecin au moment de l'action. Peut devenir orphelin
  /// (compte supprimé) — d'où le snapshot [userEmail] / [userNom].
  final int? userId;
  final String? userEmail;
  final String? userNom;

  final AuditAction action;

  /// Type d'entité concernée : 'patient' | 'document' | 'bilan' | 'scan'.
  final String entityType;

  /// id de l'entité concernée dans sa table source (nullable).
  final int? entityId;

  /// Patient rattaché (sans contrainte FK) — pour un futur filtre par dossier.
  final int? patientId;

  /// Libellé lisible et figé (inclut le nom du patient le cas échéant).
  final String description;

  /// Snapshot du rôle de l'acteur (valeur [UserRole.value]) au moment de
  /// l'action. `null` pour les entrées antérieures aux rôles.
  final String? userRole;

  final DateTime? createdAt;

  const AuditLog({
    this.id,
    this.userId,
    this.userEmail,
    this.userNom,
    required this.action,
    required this.entityType,
    this.entityId,
    this.patientId,
    required this.description,
    this.userRole,
    this.createdAt,
  });

  /// Libellé lisible du rôle de l'acteur, ou `null` si inconnu.
  String? get roleLabel =>
      userRole == null ? null : UserRole.fromString(userRole).label;

  /// Libellé de l'acteur : nom complet, sinon email, sinon repli explicite.
  String get actorLabel {
    if (userNom != null && userNom!.trim().isNotEmpty) return userNom!.trim();
    if (userEmail != null && userEmail!.trim().isNotEmpty) return userEmail!.trim();
    return 'Utilisateur inconnu';
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'user_email': userEmail,
      'user_nom': userNom,
      'action': action.value,
      'entity_type': entityType,
      'entity_id': entityId,
      'patient_id': patientId,
      'description': description,
      'user_role': userRole,
    };
  }

  factory AuditLog.fromMap(Map<String, dynamic> map) {
    return AuditLog(
      id: map['id'] as int?,
      userId: map['user_id'] as int?,
      userEmail: map['user_email'] as String?,
      userNom: map['user_nom'] as String?,
      action: AuditAction.fromString(map['action'] as String?),
      entityType: (map['entity_type'] as String?) ?? '',
      entityId: map['entity_id'] as int?,
      patientId: map['patient_id'] as int?,
      description: (map['description'] as String?) ?? '',
      userRole: map['user_role'] as String?,
      createdAt: _parseTimestamp(map['created_at'] as String?),
    );
  }

  /// Parse un horodatage SQLite. `CURRENT_TIMESTAMP` est stocké en **UTC** au
  /// format `YYYY-MM-DD HH:MM:SS` (sans marqueur de fuseau). On le marque donc
  /// comme UTC avant de le ramener en heure locale — même logique que
  /// [HistoryEntry._parseTimestamp], sinon « il y a X » serait décalé.
  static DateTime? _parseTimestamp(String? ts) {
    if (ts == null || ts.isEmpty) return null;
    final hasZone = ts.endsWith('Z') || ts.contains('+');
    final normalized = hasZone ? ts : '${ts.replaceFirst(' ', 'T')}Z';
    return DateTime.tryParse(normalized)?.toLocal();
  }
}
