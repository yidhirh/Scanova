import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'screens/login_screen.dart';
import 'database/database_helper.dart';
import 'models/patient.dart';
import 'models/card_scan.dart';
import 'models/medical_document.dart';

void main() async {
  // Nécessaire avant d'utiliser certains plugins natifs comme camera / ML Kit.
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation de la base de données avant le lancement de l'appli.
  final db = await DatabaseHelper.instance.database;
  final dbPath = await getDatabasesPath();
  print('✓ Base de données initialisée à : $dbPath/scanova.db');

  final tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
  );
  print('✓ Tables créées : ${tables.map((t) => t['name']).toList()}');

  await _runSmokeTest();

  runApp(const ScanovaApp());
}

Future<void> _runSmokeTest() async {
  final dao = DatabaseHelper.instance;

  const nom = 'Benali';
  const prenom = 'Ahmed';
  const dateNaissance = '1985-03-15';

  print('===== SMOKE TEST CRUD patients =====');

  // TEST 1 : findPatientByIdentity (cas "n'existe pas")
  final existing = await dao.findPatientByIdentity(
    nom: nom,
    prenom: prenom,
    dateNaissance: dateNaissance,
  );
  if (existing == null) {
    print('TEST 1: findPatient → null ✓');
  } else {
    print('TEST 1: findPatient → déjà présent (id=${existing.id}) — patient existant, on n\'insère pas');
  }

  print('=====');

  // TEST 2 : insertPatient (seulement si pas déjà présent)
  int patientId;
  if (existing == null) {
    patientId = await dao.insertPatient(Patient(
      nom: nom,
      prenom: prenom,
      dateNaissance: dateNaissance,
      groupeSanguin: 'O+',
    ));
    print('TEST 2: insertPatient → id=$patientId');
  } else {
    patientId = existing.id!;
    print('TEST 2: patient déjà présent (id=$patientId)');
  }

  print('=====');

  // TEST 3 : findPatientByIdentity (cas "existe")
  final found = await dao.findPatientByIdentity(
    nom: nom,
    prenom: prenom,
    dateNaissance: dateNaissance,
  );
  if (found != null) {
    print('TEST 3: findPatient → trouvé id=${found.id} ✓');
  } else {
    print('TEST 3: findPatient → null ✗ (inattendu après insertion)');
  }

  print('=====');

  // TEST 4 : searchPatients (recherche insensible à la casse)
  final searchResults = await dao.searchPatients('ben');
  print('TEST 4: searchPatients(\'ben\') → ${searchResults.length} résultat(s)');
  for (final p in searchResults) {
    print('   - ${p.nom} ${p.prenom} (id=${p.id})');
  }

  print('=====');

  // TEST 5 : getAllPatients
  final allPatients = await dao.getAllPatients();
  print('TEST 5: getAllPatients → ${allPatients.length} patient(s) au total');

  print('=====');

  // TEST 6 : getPatientById(1)
  final firstPatient = await dao.getPatientById(1);
  if (firstPatient != null) {
    print('TEST 6: getPatientById(1) → ${firstPatient.nom} ${firstPatient.prenom} ✓');
  } else {
    print('TEST 6: getPatientById(1) → null');
  }

  print('===== FIN SMOKE TEST patients =====');

  // ── Tests card_scans & medical_documents ──────────────────────────────────

  print('===== SMOKE TEST CRUD card_scans & medical_documents =====');

  // TEST 7 : insertCardScan (idempotent : skip si scan déjà présent)
  final existingScans = await dao.getScansByPatientId(patientId);
  if (existingScans.isEmpty) {
    final scanId = await dao.insertCardScan(CardScan(
      patientId: patientId,
      typeCarte: 'CNI',
      imagePath: '/fake/path/cni.jpg',
      ocrRawText: 'BENALI AHMED 15/03/1985',
    ));
    print('TEST 7: insertCardScan → id=$scanId ✓');
  } else {
    print('TEST 7: scan déjà présent, skip');
  }

  print('=====');

  // TEST 8 : getScansByPatientId(1)
  final scans = await dao.getScansByPatientId(patientId);
  print('TEST 8: getScansByPatientId($patientId) → ${scans.length} scan(s)');
  for (final s in scans) {
    print('   - [${s.typeCarte}] scanned_at=${s.scannedAt}');
  }

  print('=====');

  // TEST 9 : insertMedicalDocument (idempotent : skip si ordonnance déjà présente)
  final existingOrdonnances = await dao.getDocumentsByType(patientId, 'ordonnance');
  if (existingOrdonnances.isEmpty) {
    final docId = await dao.insertMedicalDocument(MedicalDocument(
      patientId: patientId,
      typeDocument: 'ordonnance',
      titre: 'Ordonnance test',
      filePath: '/fake/path/ord.pdf',
      documentDate: '2025-01-20',
    ));
    print('TEST 9: insertMedicalDocument → id=$docId ✓');
  } else {
    print('TEST 9: ordonnance déjà présente, skip');
  }

  print('=====');

  // TEST 10 : getDocumentsByPatientId(1)
  final docs = await dao.getDocumentsByPatientId(patientId);
  print('TEST 10: getDocumentsByPatientId($patientId) → ${docs.length} document(s)');
  for (final d in docs) {
    print('   - [${d.typeDocument}] ${d.titre}');
  }

  print('=====');

  // TEST 11 : getDocumentsByType(1, 'ordonnance')
  final ordonnances = await dao.getDocumentsByType(patientId, 'ordonnance');
  print('TEST 11: getDocumentsByType($patientId, \'ordonnance\') → ${ordonnances.length} résultat(s)');

  print('===== FIN SMOKE TEST =====');
}

class ScanovaApp extends StatelessWidget {
  const ScanovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scanova',
      debugShowCheckedModeBanner: false,
      home: const LoginScreen(),
    );
  }
}
