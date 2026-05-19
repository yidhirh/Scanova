import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  // Nécessaire avant d'utiliser certains plugins natifs comme camera / ML Kit.
  WidgetsFlutterBinding.ensureInitialized();
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
