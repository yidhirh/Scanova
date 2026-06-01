import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'database/database_helper.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  runApp(const ScanovaApp());
}

class ScanovaApp extends StatelessWidget {
  const ScanovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scanova',
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: const LoginScreen(),
    );
  }
}
