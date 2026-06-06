// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'screens/home/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';

class SpendingApp extends StatelessWidget {
  const SpendingApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2E7D32);      // xanh lá điểm nhấn
    const bgPink = Color(0xFFF7EEF2);    // nền hồng phấn

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Quản Lý Chi Tiêu',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        scaffoldBackgroundColor: bgPink,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          foregroundColor: Colors.black87,
          titleTextStyle: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87,
          ),
        ),
        // ✅ CardThemeData (đúng kiểu với SDK của bạn)
        cardTheme: const CardThemeData(
          surfaceTintColor: Colors.transparent,
          elevation: 1.2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          elevation: 6,
          shape: StadiumBorder(),
          backgroundColor: seed,
          foregroundColor: Colors.white,
        ),
        // Nếu bạn dùng NavigationBar:
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: seed.withValues(alpha: .12), // ✅ thay withOpacity
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final sel = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 11,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
            );
          }),
        ),
        chipTheme: const ChipThemeData(
          shape: StadiumBorder(),
          side: BorderSide.none,
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFFE7E2E6)),
      ),
      home: const _AuthGate(),
      routes: {
        LoginScreen.route: (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/home': (_) => const HomeScreen(),
      },
    );
  }
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authServiceProvider);
    final loggedIn = auth.currentUser != null;
    return loggedIn ? const HomeScreen() : const LoginScreen();
  }
}
