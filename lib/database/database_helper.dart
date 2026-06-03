import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/patient.dart';
import '../models/card_scan.dart';
import '../models/medical_document.dart';
import '../models/document_page.dart';
import '../models/bilan.dart';
import '../models/bilan_page.dart';
import '../models/valeur_biologique.dart';
import '../models/user.dart';

class DatabaseHelper {
  static const _databaseName = 'scanova.db';
  // v2 : ajout des tables `bilans` et `valeurs_biologiques`.
  // v3 : multi-page. Ajout `document_pages` et `bilan_pages`.
  //      Retrait `medical_documents.file_path` et `bilans.image_path`
  //      (déplacés vers les tables pages).
  // v4 : OCR page par page. Ajout `ocr_text` sur `document_pages` et
  //      `bilan_pages` (texte OCR propre à chaque page).
  // v5 : authentification locale. Ajout de la table `users` (comptes médecin,
  //      mot de passe haché).
  static const _databaseVersion = 5;

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE patients (
        id                       INTEGER PRIMARY KEY AUTOINCREMENT,
        nom                      TEXT NOT NULL,
        prenom                   TEXT NOT NULL,
        date_naissance           TEXT NOT NULL,
        groupe_sanguin           TEXT,
        numero_cni               TEXT UNIQUE,
        numero_securite_sociale  TEXT UNIQUE,
        created_at               DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at               DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE card_scans (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_id    INTEGER NOT NULL,
        type_carte    TEXT NOT NULL CHECK(type_carte IN ('CNI', 'CHIFA')),
        image_path    TEXT NOT NULL,
        ocr_raw_text  TEXT,
        scanned_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE
      )
    ''');

    // v3 : plus de colonne `file_path` ici, les pages sont dans `document_pages`.
    await db.execute('''
      CREATE TABLE medical_documents (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_id     INTEGER NOT NULL,
        type_document  TEXT NOT NULL,
        titre          TEXT NOT NULL,
        description    TEXT,
        document_date  TEXT,
        created_at     DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_patients_nom_prenom ON patients(nom, prenom)');
    await db.execute('CREATE INDEX idx_patients_date_naiss ON patients(date_naissance)');
    await db.execute('CREATE INDEX idx_scans_patient ON card_scans(patient_id)');
    await db.execute('CREATE INDEX idx_documents_patient ON medical_documents(patient_id)');
    await db.execute('CREATE INDEX idx_documents_type ON medical_documents(type_document)');

    await db.execute('''
      CREATE TRIGGER patients_updated_at
      AFTER UPDATE ON patients
      BEGIN
        UPDATE patients SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
      END
    ''');

    await _createBilanTables(db);
    await _createPagesTables(db);
    await _createUsersTable(db);
  }

  /// Migration : appelée uniquement sur une DB existante quand
  /// [_databaseVersion] augmente. Préserve les données utilisateur.
  ///
  /// Chaque palier est idempotent côté schéma final :
  /// - v1 → v3 : crée bilans/valeurs (schéma propre, sans image_path) PUIS crée
  ///   les tables pages et migre les `file_path` existants.
  /// - v2 → v3 : crée seulement les tables pages, migre les `file_path` ET
  ///   recrée `bilans` pour retirer la colonne `image_path` (qui n'existait
  ///   qu'en v2, jamais peuplée en pratique mais on nettoie le schéma).
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Crée bilans/valeurs avec le schéma final v3 (sans image_path).
      await _createBilanTables(db);
    }

    if (oldVersion < 3) {
      // PRAGMA foreign_keys doit être OFF AVANT la transaction (sinon ignoré
      // par SQLite). Garantit que DROP/RENAME ne déclenche pas de cascade
      // imprévue sur les FK pendant le recreate-table.
      await db.execute('PRAGMA foreign_keys = OFF');
      try {
        await db.transaction((txn) async {
          // 1. Création des tables pages (FK vers medical_documents / bilans).
          await _createPagesTables(txn);

          // 2. Migration des `file_path` existants vers `document_pages`
          //    (chaque doc devient une page #1). Filtre défensif sur les
          //    chaînes vides au cas où.
          await txn.execute('''
            INSERT INTO document_pages (document_id, page_number, file_path)
            SELECT id, 1, file_path
            FROM medical_documents
            WHERE file_path IS NOT NULL AND file_path != ''
          ''');

          // 3. Recréation de medical_documents sans `file_path`.
          //    SQLite < 3.35 ne supporte pas DROP COLUMN → pattern recreate.
          await txn.execute('''
            CREATE TABLE medical_documents_new (
              id             INTEGER PRIMARY KEY AUTOINCREMENT,
              patient_id     INTEGER NOT NULL,
              type_document  TEXT NOT NULL,
              titre          TEXT NOT NULL,
              description    TEXT,
              document_date  TEXT,
              created_at     DATETIME DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE
            )
          ''');
          await txn.execute('''
            INSERT INTO medical_documents_new
              (id, patient_id, type_document, titre, description, document_date, created_at)
            SELECT
              id, patient_id, type_document, titre, description, document_date, created_at
            FROM medical_documents
          ''');
          await txn.execute('DROP TABLE medical_documents');
          await txn.execute('ALTER TABLE medical_documents_new RENAME TO medical_documents');
          await txn.execute('CREATE INDEX idx_documents_patient ON medical_documents(patient_id)');
          await txn.execute('CREATE INDEX idx_documents_type ON medical_documents(type_document)');

          // 4. Si on vient de v2, bilans a une colonne `image_path` obsolète.
          //    En v1→v3, bilans vient d'être créée par _createBilanTables avec
          //    le schéma propre : rien à faire.
          if (oldVersion >= 2) {
            await txn.execute('''
              CREATE TABLE bilans_new (
                id                    INTEGER PRIMARY KEY AUTOINCREMENT,
                patient_id            INTEGER NOT NULL,
                date_examen           TEXT,
                laboratoire           TEXT,
                medecin_prescripteur  TEXT,
                numero_dossier        TEXT,
                texte_ocr_brut        TEXT,
                created_at            DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE
              )
            ''');
            await txn.execute('''
              INSERT INTO bilans_new
                (id, patient_id, date_examen, laboratoire, medecin_prescripteur,
                 numero_dossier, texte_ocr_brut, created_at)
              SELECT
                id, patient_id, date_examen, laboratoire, medecin_prescripteur,
                numero_dossier, texte_ocr_brut, created_at
              FROM bilans
            ''');
            await txn.execute('DROP TABLE bilans');
            await txn.execute('ALTER TABLE bilans_new RENAME TO bilans');
            await txn.execute('CREATE INDEX idx_bilans_patient ON bilans(patient_id)');
          }

          // 5. Vérif intégrité FK : tout résultat non vide signale une
          //    violation → exception → rollback automatique de la transaction.
          final fkViolations = await txn.rawQuery('PRAGMA foreign_key_check');
          if (fkViolations.isNotEmpty) {
            throw StateError('Migration v3 : violations FK détectées : $fkViolations');
          }
        });
      } finally {
        // Restaure les FK quoi qu'il arrive (succès ou rollback).
        await db.execute('PRAGMA foreign_keys = ON');
      }
    }

    if (oldVersion < 4) {
      // Seules les DB déjà en v3 ont les tables pages SANS `ocr_text` : pour
      // oldVersion < 3, le palier v3 ci-dessus appelle _createPagesTables qui
      // les crée déjà avec `ocr_text` (forme finale). On évite ainsi un
      // "duplicate column" sur un upgrade direct v1/v2 → v4.
      if (oldVersion >= 3) {
        await db.execute('ALTER TABLE document_pages ADD COLUMN ocr_text TEXT');
        await db.execute('ALTER TABLE bilan_pages ADD COLUMN ocr_text TEXT');
      }
    }

    if (oldVersion < 5) {
      await _createUsersTable(db);
    }
  }

  /// Table des comptes médecin (authentification locale, v5).
  /// `email` est unique et insensible à la casse (COLLATE NOCASE) pour éviter
  /// les doublons "A@x.com" / "a@x.com". Le mot de passe n'est jamais stocké
  /// en clair : seuls `password_hash` (SHA-256 salé itéré) et `salt` le sont.
  Future<void> _createUsersTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE users (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        nom_complet   TEXT,
        email         TEXT NOT NULL UNIQUE COLLATE NOCASE,
        password_hash TEXT NOT NULL,
        salt          TEXT NOT NULL,
        created_at    DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  /// Création des tables `bilans` et `valeurs_biologiques` (schéma v3, sans
  /// `image_path` — les pages sont dans `bilan_pages`).
  /// Appelée à la fois par [_onCreate] (nouvelles installations) et par
  /// [_onUpgrade] sur le palier v1→v2 (préservé en v3 pour les upgrades v1→v3).
  Future<void> _createBilanTables(Database db) async {
    await db.execute('''
      CREATE TABLE bilans (
        id                    INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_id            INTEGER NOT NULL,
        date_examen           TEXT,
        laboratoire           TEXT,
        medecin_prescripteur  TEXT,
        numero_dossier        TEXT,
        texte_ocr_brut        TEXT,
        created_at            DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE valeurs_biologiques (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        bilan_id          INTEGER NOT NULL,
        nom               TEXT NOT NULL,
        methode           TEXT,
        valeur_numerique  REAL,
        valeur_texte      TEXT,
        unite             TEXT,
        norme_min         REAL,
        norme_max         REAL,
        norme_texte       TEXT,
        categorie         TEXT,
        ordre             INTEGER NOT NULL,
        FOREIGN KEY (bilan_id) REFERENCES bilans(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_bilans_patient ON bilans(patient_id)');
    await db.execute('CREATE INDEX idx_valeurs_bilan ON valeurs_biologiques(bilan_id)');
  }

  /// Création des tables `document_pages` et `bilan_pages` + leurs index.
  /// Typée [DatabaseExecutor] pour être appelable depuis [_onCreate] (Database)
  /// ET depuis l'intérieur d'une transaction dans [_onUpgrade] (Transaction).
  Future<void> _createPagesTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE document_pages (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id   INTEGER NOT NULL,
        page_number   INTEGER NOT NULL,
        file_path     TEXT NOT NULL,
        ocr_text      TEXT,
        FOREIGN KEY (document_id) REFERENCES medical_documents(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE bilan_pages (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        bilan_id      INTEGER NOT NULL,
        page_number   INTEGER NOT NULL,
        file_path     TEXT NOT NULL,
        ocr_text      TEXT,
        FOREIGN KEY (bilan_id) REFERENCES bilans(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_document_pages_doc ON document_pages(document_id)');
    await db.execute('CREATE INDEX idx_bilan_pages_bilan ON bilan_pages(bilan_id)');
  }

  /// Insère un nouveau patient dans la base et retourne l'id généré par SQLite.
  /// La détection de doublon doit être faite EN AMONT via [findPatientByIdentity].
  Future<int> insertPatient(Patient patient) async {
    final db = await database;
    final id = await db.insert('patients', patient.toMap());
    print('[DB] insertPatient → id=$id (${patient.nom} ${patient.prenom})');
    return id;
  }

  /// Recherche un patient par matching strict (nom + prénom + date de naissance).
  /// Retourne `null` si aucun patient ne correspond. Utilisé pour la détection
  /// de doublon avant un [insertPatient].
  Future<Patient?> findPatientByIdentity({
    required String nom,
    required String prenom,
    required String dateNaissance,
  }) async {
    final db = await database;
    final rows = await db.query(
      'patients',
      where: 'nom = ? AND prenom = ? AND date_naissance = ?',
      whereArgs: [nom, prenom, dateNaissance],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Patient.fromMap(rows.first);
  }

  /// Retourne tous les patients, triés par date de création décroissante
  /// (les plus récents en premier). Pour l'écran liste des patients.
  Future<List<Patient>> getAllPatients() async {
    final db = await database;
    final rows = await db.query(
      'patients',
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => Patient.fromMap(r)).toList();
  }

  /// Retourne le patient correspondant à [id], ou `null` s'il n'existe pas.
  /// Sert à ouvrir le dossier d'un patient.
  Future<Patient?> getPatientById(int id) async {
    final db = await database;
    final rows = await db.query(
      'patients',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Patient.fromMap(rows.first);
  }

  /// Recherche partielle insensible à la casse sur nom OU prénom (LIKE %query%).
  /// Résultats triés par nom alphabétique.
  Future<List<Patient>> searchPatients(String query) async {
    final db = await database;
    final pattern = '%$query%';
    final rows = await db.query(
      'patients',
      where: '(nom LIKE ? OR prenom LIKE ?) COLLATE NOCASE',
      whereArgs: [pattern, pattern],
      orderBy: 'nom COLLATE NOCASE ASC',
    );
    return rows.map((r) => Patient.fromMap(r)).toList();
  }

  // ── users (authentification locale) ─────────────────────────────────────────

  /// Nombre de comptes existants. Sert à distinguer le premier lancement
  /// (0 compte → écran d'inscription) d'un lancement normal (→ login).
  Future<int> countUsers() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM users');
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// Insère un compte médecin et retourne l'id généré.
  /// L'unicité de l'email est garantie par la contrainte UNIQUE (lève en cas
  /// de doublon) ; l'appelant ([AuthService.register]) vérifie en amont.
  Future<int> insertUser(User user) async {
    final db = await database;
    return db.insert('users', user.toMap());
  }

  /// Recherche un compte par email (insensible à la casse via COLLATE NOCASE).
  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    return rows.isEmpty ? null : User.fromMap(rows.first);
  }

  Future<User?> getUserById(int id) async {
    final db = await database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : User.fromMap(rows.first);
  }

  // ── card_scans ────────────────────────────────────────────────────────────

  /// Insère un nouveau scan de carte (CNI ou CHIFA) et retourne l'id généré.
  /// L'id du patient doit exister en base ; la FK est vérifiée par SQLite.
  Future<int> insertCardScan(CardScan scan) async {
    final db = await database;
    final id = await db.insert('card_scans', scan.toMap());
    print('[DB] insertCardScan → id=$id (patient_id=${scan.patientId}, type=${scan.typeCarte})');
    return id;
  }

  /// Retourne tous les scans d'un patient, triés du plus récent au plus ancien.
  Future<List<CardScan>> getScansByPatientId(int patientId) async {
    final db = await database;
    final rows = await db.query(
      'card_scans',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'scanned_at DESC',
    );
    return rows.map((r) => CardScan.fromMap(r)).toList();
  }

  // ── medical_documents + document_pages ────────────────────────────────────

  // TODO: updateMedicalDocument à l'étape suivante (édition + réorganisation pages).

  /// Insère un document médical **et ses pages** de façon atomique (transaction).
  /// Le `document_id` de chaque page est écrasé avec l'id généré pour le doc
  /// parent : côté appelant on peut donc passer un `documentId` placeholder (0).
  ///
  /// Si [MedicalDocument.pages] est `null`, seul le document est inséré (cas
  /// dégradé — en pratique un doc devrait toujours avoir au moins 1 page).
  /// Retourne l'id du document inséré.
  Future<int> insertMedicalDocument(MedicalDocument doc) async {
    final db = await database;
    late int docId;

    await db.transaction((txn) async {
      docId = await txn.insert('medical_documents', doc.toMap());

      if (doc.pages != null) {
        for (final page in doc.pages!) {
          final map = page.toMap()..['document_id'] = docId;
          await txn.insert('document_pages', map);
        }
      }
    });

    final nbPages = doc.pages?.length ?? 0;
    print('[DB] insertMedicalDocument → id=$docId (patient_id=${doc.patientId}, type=${doc.typeDocument}, $nbPages page(s))');
    return docId;
  }

  /// Retourne tous les documents d'un patient avec **leurs pages chargées
  /// eager** (champ [MedicalDocument.pages] peuplé).
  ///
  /// **Choix eager** : un document a typiquement 1-5 pages (peu cher), et la
  /// visionneuse ouverte depuis la liste a besoin immédiatement des pages.
  /// Coût : 1 query liste + N queries pages (N = nb docs). Acceptable pour
  /// les volumes typiques (< 50 docs / patient).
  ///
  /// Tri : `document_date` décroissant, les docs sans date en dernier.
  Future<List<MedicalDocument>> getDocumentsByPatientId(int patientId) async {
    final db = await database;
    final rows = await db.query(
      'medical_documents',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      // NULLS LAST n'est pas disponible avant SQLite 3.30 (Android < 12).
      // IS NULL retourne 0 pour non-null (en tête) et 1 pour null (en fin).
      orderBy: 'document_date IS NULL ASC, document_date DESC',
    );
    final docs = <MedicalDocument>[];
    for (final r in rows) {
      final id = r['id'] as int;
      final pages = await getDocumentPagesByDocumentId(id);
      docs.add(MedicalDocument.fromMap(r, pages: pages));
    }
    return docs;
  }

  /// Retourne les documents d'un patient filtrés par [typeDocument]
  /// (ex. 'ordonnance', 'bilan', 'radio'). Même eager-load que
  /// [getDocumentsByPatientId].
  Future<List<MedicalDocument>> getDocumentsByType(
    int patientId,
    String typeDocument,
  ) async {
    final db = await database;
    final rows = await db.query(
      'medical_documents',
      where: 'patient_id = ? AND type_document = ?',
      whereArgs: [patientId, typeDocument],
      orderBy: 'document_date IS NULL ASC, document_date DESC',
    );
    final docs = <MedicalDocument>[];
    for (final r in rows) {
      final id = r['id'] as int;
      final pages = await getDocumentPagesByDocumentId(id);
      docs.add(MedicalDocument.fromMap(r, pages: pages));
    }
    return docs;
  }

  /// Retourne les pages d'un document médical, triées par `page_number`
  /// croissant (préserve l'ordre de saisie).
  Future<List<DocumentPage>> getDocumentPagesByDocumentId(int documentId) async {
    final db = await database;
    final rows = await db.query(
      'document_pages',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'page_number ASC',
    );
    return rows.map((r) => DocumentPage.fromMap(r)).toList();
  }

  /// Supprime un document médical. Ses pages (`document_pages`) sont supprimées
  /// automatiquement par la contrainte FK `ON DELETE CASCADE`. Le patient n'est
  /// pas affecté. Retourne le nombre de lignes supprimées (0 si id inconnu).
  Future<int> deleteMedicalDocument(int id) async {
    final db = await database;
    final count = await db.delete('medical_documents', where: 'id = ?', whereArgs: [id]);
    print('[DB] deleteMedicalDocument → $count ligne(s) supprimée(s) (id=$id)');
    return count;
  }

  // ── bilans + valeurs_biologiques + bilan_pages ────────────────────────────

  // TODO: updateBilan + updateValeur à l'étape 5 (formulaire de correction).

  /// Insère un bilan **avec ses valeurs ET ses pages** de façon atomique
  /// (transaction). Le `bilan_id` des valeurs et pages est écrasé avec l'id
  /// généré pour le bilan parent : côté parser on peut passer des placeholders.
  ///
  /// `null` sur [Bilan.valeurs] ou [Bilan.pages] = on n'insère rien pour ce
  /// volet (cas d'un bilan créé sans parser ni scan).
  /// Retourne l'id du bilan inséré.
  Future<int> insertBilan(Bilan bilan) async {
    final db = await database;
    late int bilanId;

    await db.transaction((txn) async {
      bilanId = await txn.insert('bilans', bilan.toMap());

      if (bilan.valeurs != null) {
        for (final v in bilan.valeurs!) {
          final map = v.toMap()..['bilan_id'] = bilanId;
          await txn.insert('valeurs_biologiques', map);
        }
      }

      if (bilan.pages != null) {
        for (final p in bilan.pages!) {
          final map = p.toMap()..['bilan_id'] = bilanId;
          await txn.insert('bilan_pages', map);
        }
      }
    });

    final nbValeurs = bilan.valeurs?.length ?? 0;
    final nbPages = bilan.pages?.length ?? 0;
    print('[DB] insertBilan → id=$bilanId (patient_id=${bilan.patientId}, $nbValeurs valeur(s), $nbPages page(s))');
    return bilanId;
  }

  /// Retourne tous les bilans d'un patient, **sans charger les enfants**
  /// (ni `valeurs`, ni `pages`).
  ///
  /// **Choix lazy** : un bilan peut avoir 30+ valeurs (deux enfants à joindre
  /// par bilan). Charger N bilans × (30 valeurs + 3 pages) serait 100+ queries
  /// pour une liste qui n'affiche qu'un résumé (date, labo, médecin). Pour
  /// obtenir un bilan complet hydraté, utiliser [getBilanById].
  ///
  /// Tri : `date_examen` décroissant, sans date en dernier.
  Future<List<Bilan>> getBilansByPatientId(int patientId) async {
    final db = await database;
    final rows = await db.query(
      'bilans',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'date_examen IS NULL ASC, date_examen DESC',
    );
    return rows.map((r) => Bilan.fromMap(r)).toList();
  }

  /// Retourne le bilan [id] **complètement hydraté** : valeurs jointes
  /// (triées par `ordre` croissant) ET pages jointes (triées par
  /// `page_number` croissant). Retourne `null` si l'id n'existe pas.
  Future<Bilan?> getBilanById(int id) async {
    final db = await database;
    final rows = await db.query(
      'bilans',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final valeurs = await getValeursByBilanId(id);
    final pages = await getBilanPagesByBilanId(id);
    return Bilan.fromMap(rows.first, valeurs: valeurs, pages: pages);
  }

  /// Retourne les valeurs biologiques d'un bilan, triées par `ordre` croissant.
  Future<List<ValeurBiologique>> getValeursByBilanId(int bilanId) async {
    final db = await database;
    final rows = await db.query(
      'valeurs_biologiques',
      where: 'bilan_id = ?',
      whereArgs: [bilanId],
      orderBy: 'ordre ASC',
    );
    return rows.map((r) => ValeurBiologique.fromMap(r)).toList();
  }

  /// Retourne les pages d'un bilan, triées par `page_number` croissant.
  Future<List<BilanPage>> getBilanPagesByBilanId(int bilanId) async {
    final db = await database;
    final rows = await db.query(
      'bilan_pages',
      where: 'bilan_id = ?',
      whereArgs: [bilanId],
      orderBy: 'page_number ASC',
    );
    return rows.map((r) => BilanPage.fromMap(r)).toList();
  }

  /// Supprime un bilan. Les valeurs ET les pages sont supprimées
  /// automatiquement par les contraintes FK `ON DELETE CASCADE`.
  /// Retourne le nombre de lignes supprimées (0 si l'id n'existait pas).
  Future<int> deleteBilan(int id) async {
    final db = await database;
    final count = await db.delete('bilans', where: 'id = ?', whereArgs: [id]);
    print('[DB] deleteBilan → $count ligne(s) supprimée(s) (id=$id)');
    return count;
  }

  // ── historique global (toutes sources, tous patients) ─────────────────────

  /// Retourne les dernières numérisations **toutes sources confondues**
  /// (cartes scannées, documents médicaux, bilans), du plus récent au plus
  /// ancien, jointes au nom du patient.
  ///
  /// Alimente la section « Documents traités récemment » de la Home et
  /// l'écran d'historique complet. Une seule requête `UNION ALL` plutôt que
  /// trois requêtes + fusion en Dart : le tri et la limite sont délégués à
  /// SQLite (les colonnes `scanned_at` / `created_at` sont au même format
  /// texte ISO, donc comparables lexicographiquement).
  ///
  /// [limit] borne le nombre de lignes (défaut 50). `null` => sans limite.
  Future<List<Map<String, Object?>>> getRecentHistory({int? limit = 50}) async {
    final db = await database;
    final limitClause = limit != null ? 'LIMIT $limit' : '';
    final rows = await db.rawQuery('''
      SELECT 'scan' AS kind, cs.id AS id, cs.patient_id AS patient_id,
             cs.type_carte AS type, NULL AS titre, cs.scanned_at AS ts,
             p.nom AS nom, p.prenom AS prenom
        FROM card_scans cs
        JOIN patients p ON p.id = cs.patient_id
      UNION ALL
      SELECT 'document', md.id, md.patient_id,
             md.type_document, md.titre, md.created_at,
             p.nom, p.prenom
        FROM medical_documents md
        JOIN patients p ON p.id = md.patient_id
      UNION ALL
      SELECT 'bilan', b.id, b.patient_id,
             'bilan', NULL, b.created_at,
             p.nom, p.prenom
        FROM bilans b
        JOIN patients p ON p.id = b.patient_id
      ORDER BY ts DESC
      $limitClause
    ''');
    return rows;
  }
}
