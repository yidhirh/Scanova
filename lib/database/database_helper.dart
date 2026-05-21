import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
}
