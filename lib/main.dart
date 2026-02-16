import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'widgets/main_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // GitHub Actions'dan --dart-define orqali keladigan kalitlarni qabul qilish
  const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const String supabaseKey = String.fromEnvironment('SUPABASE_KEY');

  // Agar kalitlar kelsa, Supabase'ni ishga tushiramiz
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
    // Seansni xavfsiz tekshirish
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
      ),
      home: session != null ? const MainWrapper() : const LoginScreen(),
    );
  }
}
