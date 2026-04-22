import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vendorlink/screens/auth/login_screen.dart';
import 'package:vendorlink/screens/retailer/retailer_dashboard.dart';
import 'package:vendorlink/screens/wholesaler/tabs/wholesaler_home.dart';
import 'package:vendorlink/services/auth/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://vmjojqhtvhwuqopdqgpa.supabase.co',
    anonKey: 'sb_publishable_5E-fjPw5BjyUX8EOOy26rQ_SU7AQ02M',
  );

  runApp(const VendorLinkApp());
}

class VendorLinkApp extends StatelessWidget {
  const VendorLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    const colorScheme = ColorScheme.dark(
      primary: Color(0xFF4F46E5),
      onPrimary: Colors.white,
      secondary: Color(0xFF14B8A6),
      onSecondary: Colors.white,
      surface: Color(0xFF1F2937),
      onSurface: Color(0xFFE5E7EB),
      error: Color(0xFFEF4444),
      onError: Colors.white,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VendorConnect',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF111827),
        colorScheme: colorScheme,
        dividerColor: const Color(0xFF374151),
        cardTheme: CardThemeData(
          color: const Color(0xFF1F2937),
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF374151)),
          ),
          margin: EdgeInsets.zero,
        ),
        drawerTheme: const DrawerThemeData(backgroundColor: Color(0xFF111827)),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF3F4F6),
          ),
          titleMedium: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: Color(0xFFE5E7EB),
          ),
          bodyMedium: TextStyle(fontSize: 14, color: Color(0xFFD1D5DB)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            minimumSize: const Size.fromHeight(42),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFE5E7EB),
            side: const BorderSide(color: Color(0xFF4B5563)),
            minimumSize: const Size.fromHeight(40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0F172A),
          selectedItemColor: Color(0xFF38BDF8),
          unselectedItemColor: Color(0xFF94A3B8),
          selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
          type: BottomNavigationBarType.fixed,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF111827),
          elevation: 0,
          centerTitle: true,
          foregroundColor: Color(0xFFE5E7EB),
        ),
      ),

      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<String?> _initialRoleFuture;

  @override
  void initState() {
    super.initState();
    _initialRoleFuture = _resolveInitialRole();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _initialRoleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == 'wholesaler') {
          return const WholesalerHome();
        }

        if (snapshot.data == 'retailer') {
          return const RetailerDashboard();
        }

        return const LoginScreen();
      },
    );
  }

  Future<String?> _resolveInitialRole() async {
    final authService = AuthService();
    if (authService.currentSession == null) {
      return null;
    }

    try {
      final role = await authService.getUserRole();
      if (role == null) {
        await authService.logout();
        return null;
      }
      return role.toLowerCase();
    } catch (_) {
      await authService.logout();
      return null;
    }
  }
}
