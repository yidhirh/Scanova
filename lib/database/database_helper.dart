import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/patient.dart';

class DatabaseHelper {
  static const _databaseName = 'scanova.db';
  static const _databaseVersion = 1;

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

    await db.execute('''
      CREATE TABLE medical_documents (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_id     INTEGER NOT NULL,
        type_document  TEXT NOT NULL,
        titre          TEXT NOT NULL,
        description    TEXT,
        file_path      TEXT NOT NULL,
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
}
