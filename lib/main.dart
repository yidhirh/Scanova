import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'screens/login_screen.dart';
import 'database/database_helper.dart';
import 'models/patient.dart';

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
