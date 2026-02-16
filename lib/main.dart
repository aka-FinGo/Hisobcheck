import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'widget/main_wrapper.dart'; // <-- DIQQAT: To'g'ri yo'l (screens ichida)

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase kalitlari (GitHub Secrets dan yoki shu yerdan o'qiladi)
  const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const String supabaseKey = String.fromEnvironment('SUPABASE_KEY');

  // Supabase'ni ishga tushirish
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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Foydalanuvchi tizimga kirganligini aniqlash
    bool isLoggedIn = false;
    try {
      final session = Supabase.instance.client.auth.currentSession;
      isLoggedIn = session != null;
    } catch (_) {
      isLoggedIn = false;
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aristokrat Mebel',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue.shade900,
        scaffoldBackgroundColor: Colors.grey.shade100,
      ),
      // 2. Agar kirgan bo'lsa MainWrapper (Menyu), bo'lmasa LoginScreen
      home: isLoggedIn ? const MainWrapper() : const LoginScreen(),
    );
  }
}