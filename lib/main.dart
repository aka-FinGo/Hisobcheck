import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import 'screens/login_screen.dart';
import 'widgets/main_wrapper.dart';
import 'theme/theme_provider.dart';
import 'theme/app_themes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Supabase kalitlari (GitHub Secrets orqali uzatiladi) ──
  const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const String supabaseKey = String.fromEnvironment('SUPABASE_KEY');

  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
      );
    } catch (e) {
      debugPrint("Supabase ulanish xatosi: $e");
    }
  }

  // ── ThemeProvider ni yuklash (SharedPreferences dan) ──
  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();

  runApp(
    ChangeNotifierProvider<ThemeProvider>.value(
      value: themeProvider,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ThemeProvider dan mavzuni kuzatamiz
    final themeProvider = context.watch<ThemeProvider>();

    // Foydalanuvchi tizimga kirganligini aniqlash
    bool isLoggedIn = false;
    try {
      final session = Supabase.instance.client.auth.currentSession;
      isLoggedIn = session != null;
    } catch (_) {
      isLoggedIn = false;
    }

    // Glass mavzu uchun MaterialApp transparency ni sozlash
    final isGlass = themeProvider.currentMode == AppThemeMode.glass;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aristokrat Mebel',

      // ── Aktiv mavzu (light / dark / glass) ──
      theme: themeProvider.themeData,

      // Glass mavzuda scaffold transparent bo'lishi uchun
      builder: isGlass
          ? (context, child) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF1A237E),
                      Color(0xFF4A148C),
                      Color(0xFF006064),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: child,
              )
          : null,

      // Agar kirgan bo'lsa → MainWrapper, bo'lmasa → LoginScreen
      home: isLoggedIn ? const MainWrapper() : const LoginScreen(),
    );
  }
}