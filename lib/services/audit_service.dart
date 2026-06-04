// lib/services/audit_service.dart
//
// AuditService — point d'entrée unique pour journaliser les actions sensibles
// (traçabilité / audit des accès). Couvre les MODIFICATIONS (créations,
// suppressions) et les EXPORTS (impression/PDF).
//
// L'acteur est l'utilisateur courant de [AuthService] ; son identité (email +
// nom) est SNAPSHOTÉE dans l'entrée pour rester lisible même si le compte est
// supprimé par la suite (cf. modèle [AuditLog]).
//
// **Fail-safe** : la journalisation ne doit JAMAIS faire échouer l'action
// métier de l'utilisateur. Toute erreur est avalée (debugPrint) et l'appelant
// peut donc « fire-and-forget » sans craindre une exception.

import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/audit_log.dart';
import 'auth_service.dart';

class AuditService {
  AuditService._();
  static final AuditService instance = AuditService._();

  /// Journalise une **création** (patient, document, bilan, scan…).
  Future<void> logCreation({
    required String entityType,
    int? entityId,
    int? patientId,
    required String description,
  }) {
    return _log(
      action: AuditAction.creation,
      entityType: entityType,
      entityId: entityId,
      patientId: patientId,
      description: description,
    );
  }

  /// Journalise une **suppression** (document, bilan…).
  Future<void> logSuppression({
    required String entityType,
    int? entityId,
    int? patientId,
    required String description,
  }) {
    return _log(
      action: AuditAction.suppression,
      entityType: entityType,
      entityId: entityId,
      patientId: patientId,
      description: description,
    );
  }

  /// Journalise un **export** (impression / génération de PDF).
  Future<void> logExport({
    required String entityType,
    int? entityId,
    int? patientId,
    required String description,
  }) {
    return _log(
      action: AuditAction.exportation,
      entityType: entityType,
      entityId: entityId,
      patientId: patientId,
      description: description,
    );
  }

  Future<void> _log({
    required AuditAction action,
    required String entityType,
    int? entityId,
    int? patientId,
    required String description,
  }) async {
    try {
      final user = AuthService.instance.currentUser;
      final log = AuditLog(
        userId: user?.id,
        userEmail: user?.email,
        userNom: user?.nomComplet,
        action: action,
        entityType: entityType,
        entityId: entityId,
        patientId: patientId,
        description: description,
      );
      await DatabaseHelper.instance.insertAuditLog(log);
      debugPrint('[Audit] ${action.value} · $entityType · $description');
    } catch (e) {
      // Ne jamais propager : l'audit est secondaire vis-à-vis de l'action métier.
      debugPrint('[Audit] échec de journalisation ($action / $entityType) : $e');
    }
  }
}
