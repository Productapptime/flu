// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PDFApp());
}

class PDFApp extends StatelessWidget {
  const PDFApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Manager + PDF.js (Flutter)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.light,
          background: Colors.white,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          toolbarHeight: 48,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedLabelStyle: TextStyle(fontSize: 12, color: Colors.red),
          unselectedLabelStyle: TextStyle(fontSize: 12, color: Colors.black),
          showSelectedLabels: true,
          showUnselectedLabels: true,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
          background: Colors.black,
          surface: Color(0xFF121212),
        ),
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.red,
          toolbarHeight: 48,
        ),
        iconTheme: IconThemeData(color: Colors.red),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedLabelStyle: const TextStyle(fontSize: 12, color: Colors.red),
          unselectedLabelStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
          showSelectedLabels: true,
          showUnselectedLabels: true,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const PDFHomePage(),
    );
  }
}
