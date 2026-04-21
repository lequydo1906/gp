import 'package:flutter/material.dart';
import 'screens/family_tree_screen.dart';

void main() {
  runApp(const GiaPhaApp());
}

class GiaPhaApp extends StatelessWidget {
  const GiaPhaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gia Phả Dòng Họ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B6F47),
          surface: const Color(0xFFF5F0E8),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F0E8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F0E8),
          foregroundColor: Color(0xFF4A3728),
          elevation: 0,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFFFAF6F0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B6F47),
            foregroundColor: Colors.white,
          ),
        ),
        useMaterial3: true,
      ),
      home: const FamilyTreeScreen(),
    );
  }
}
