import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const VendorLinkApp());
}

class VendorLinkApp extends StatelessWidget {
  const VendorLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VendorConnect',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),

        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFFEC4899),
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
      ),

      home: const LoginScreen(),
    );
  }
}