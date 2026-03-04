
import 'package:flutter/material.dart';
import 'home_screen.dart';

void main() {
  runApp(const VendorLinkApp());
}

class VendorLinkApp extends StatelessWidget {
  const VendorLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VendorLink',
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'roboto',
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFFEC4899),
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),

        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1E293B),
          selectedItemColor: Color(0xFF6366F1),
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
        ),


      ),
      home: const HomeScreen(),


    );

  }

}