import 'package:flutter/material.dart';
import 'screens/auth_gate.dart';

class CareCompanionApp extends StatelessWidget {
  const CareCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Care Companion',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
      ),
      home: const AuthGate(),
    );
  }
}