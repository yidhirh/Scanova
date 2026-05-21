import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'screens/login_screen.dart';
import 'database/database_helper.dart';

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

  runApp(const ScanovaApp());
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
