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
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F8CFF),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F7FB),
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: Color(0xFF1F2937),
          centerTitle: false,
        ),
      ),
      home: const AuthGate(),
    );
  }
}